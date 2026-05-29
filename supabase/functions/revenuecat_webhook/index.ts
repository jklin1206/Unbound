// supabase/functions/revenuecat_webhook/index.ts
// RevenueCat -> Supabase entitlement sync. RevenueCat POSTs subscription
// lifecycle events here; we verify the shared webhook secret, parse the event,
// and write the server-owned `is_pro` (+ expiry) onto the user row. This is the
// SINGLE writer of premium truth — premium Edge Functions read it via
// assertServerPro() and never trust a client-asserted entitlement.
//
// Configure in the RevenueCat dashboard:
//   - Webhook URL: https://<project>.supabase.co/functions/v1/revenuecat_webhook
//   - Authorization header: Bearer <REVENUECAT_WEBHOOK_SECRET>
// Deploy with --no-verify-jwt (RC is not a Supabase user); the shared-secret
// header is the auth.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/** Result of mapping a RevenueCat event to server entitlement state. */
export interface ProUpdate {
  appUserId: string
  isPro: boolean
  /** ISO-8601 expiry, or null when not pro / no expiry supplied. */
  expiresAt: string | null
}

// Event types that, on their own, indicate an active/granted entitlement.
const GRANTING_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
])
// Event types that revoke entitlement immediately.
const REVOKING_TYPES = new Set([
  "EXPIRATION",
  "SUBSCRIPTION_PAUSED",
  "BILLING_ISSUE",
])
// CANCELLATION means auto-renew was turned off; access remains until expiry.
// We keep is_pro true until expiration_at_ms passes (handled below + by the
// expiry check in _shared/entitlement.ts).

/**
 * Map a RevenueCat webhook payload to the entitlement update to apply.
 *
 * Pure function (no I/O) so it is unit-testable. Returns null when the payload
 * is malformed or carries an event type we intentionally ignore.
 *
 * @param payload Parsed JSON body from RevenueCat.
 * @param now     Current time in ms (injectable for tests).
 */
export function parseRevenueCatEvent(
  payload: unknown,
  now: number = Date.now(),
): ProUpdate | null {
  if (typeof payload !== "object" || payload === null) return null
  const event = (payload as Record<string, unknown>).event
  if (typeof event !== "object" || event === null) return null
  const e = event as Record<string, unknown>

  const appUserId = typeof e.app_user_id === "string" ? e.app_user_id : null
  const type = typeof e.type === "string" ? e.type : null
  if (!appUserId || !type) return null

  const expirationMs = typeof e.expiration_at_ms === "number"
    ? e.expiration_at_ms
    : null
  const expiresAt = expirationMs ? new Date(expirationMs).toISOString() : null
  const notYetExpired = expirationMs ? expirationMs > now : true

  if (REVOKING_TYPES.has(type)) {
    return { appUserId, isPro: false, expiresAt: null }
  }
  if (type === "CANCELLATION") {
    // Auto-renew off; remain pro until the paid period actually ends.
    return { appUserId, isPro: notYetExpired, expiresAt }
  }
  if (GRANTING_TYPES.has(type)) {
    return { appUserId, isPro: notYetExpired, expiresAt }
  }
  // TRANSFER, TEST, and any unknown types: ignore (no entitlement change).
  return null
}

/**
 * Core request handler. Exported so tests can exercise it without binding a
 * port. Production wires it through serve() under import.meta.main below.
 */
export async function handle(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: { "content-type": "application/json" },
    })
  }

  // --- Auth: shared secret in the Authorization header (RC dashboard config) ---
  const expectedSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")
  if (!expectedSecret) {
    // Misconfiguration: never accept unauthenticated writes to entitlement.
    return new Response(JSON.stringify({ error: "server_misconfigured" }), {
      status: 500,
      headers: { "content-type": "application/json" },
    })
  }
  const authHeader = req.headers.get("Authorization") ?? ""
  const presented = authHeader.replace(/^Bearer\s+/i, "").trim()
  if (presented !== expectedSecret) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    })
  }

  let payload: unknown
  try {
    payload = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: "invalid_json" }), {
      status: 400,
      headers: { "content-type": "application/json" },
    })
  }

  const update = parseRevenueCatEvent(payload)
  if (!update) {
    // Acknowledge ignored/irrelevant events so RC does not retry forever.
    return new Response(JSON.stringify({ ok: true, applied: false }), {
      status: 200,
      headers: { "content-type": "application/json" },
    })
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  const { error } = await admin
    .from("users")
    .update({
      is_pro: update.isPro,
      is_pro_expires_at: update.isPro ? update.expiresAt : null,
    })
    .eq("id", update.appUserId)

  if (error) {
    return new Response(JSON.stringify({ error: "update_failed" }), {
      status: 500,
      headers: { "content-type": "application/json" },
    })
  }

  return new Response(JSON.stringify({ ok: true, applied: true }), {
    status: 200,
    headers: { "content-type": "application/json" },
  })
}

// Only bind a port when run as the entrypoint, so importing this module in a
// test does not start a server.
if (import.meta.main) {
  serve(handle)
}
