// supabase/functions/anthropic_proxy/index.ts
// Transparent Anthropic Messages proxy. The app calls this with its
// Supabase user session JWT (supabase-swift functions.invoke attaches it).
// Verifies an AUTHENTICATED (non-anon) user, verifies SERVER-OWNED premium
// entitlement (is_pro) before doing any premium work, injects the server-side
// ANTHROPIC_API_KEY secret, allowlists the model, and passes the request
// through to api.anthropic.com verbatim. The key never ships in the app.
//
// This is a PREMIUM endpoint: a client that spoofs its local entitlement still
// gets a 403 here unless the server `is_pro` flag (written only by
// revenuecat_webhook) says otherwise.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"
import { assertServerPro } from "../_shared/entitlement.ts"

const ALLOWED_MODELS = new Set([
  "claude-sonnet-4-6",
  "claude-opus-4-7",
  "claude-haiku-4-5-20251001",
])

/**
 * Dependency seam so the handler is unit-testable without network/env.
 * Production wires these to real Supabase + Anthropic; tests stub them.
 */
export interface ProxyDeps {
  /** Resolve the authenticated user from the forwarded JWT, or null. */
  authenticate: (authHeader: string) => Promise<{ id: string; role: string } | null>
  /** True only when the server-owned entitlement grants premium access. */
  isPro: (userId: string) => Promise<boolean>
  /** Forward the validated body to Anthropic and return body+status. */
  forwardToAnthropic: (body: Record<string, unknown>) => Promise<{ text: string; status: number }>
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

/**
 * Core request handler. Order of checks: method -> auth (401) -> premium
 * entitlement (403) -> body/model validation (400) -> upstream forward.
 */
export async function handle(req: Request, deps: ProxyDeps): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const user = await deps.authenticate(authHeader)
  // getUser resolves the forwarded JWT. An anon/missing session has no user.
  if (!user || user.role !== "authenticated") {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    })
  }

  // Server-owned entitlement is the source of truth. A spoofed local
  // entitlement on the client cannot bypass this — deny with 403 when false.
  if (!(await deps.isPro(user.id))) {
    return new Response(JSON.stringify({ error: "premium_required" }), {
      status: 403,
      headers: { "content-type": "application/json" },
    })
  }

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), {
      status: 400,
      headers: { "content-type": "application/json" },
    })
  }

  if (typeof body.model !== "string" || !ALLOWED_MODELS.has(body.model)) {
    return new Response(JSON.stringify({ error: "model not allowed" }), {
      status: 400,
      headers: { "content-type": "application/json" },
    })
  }

  const { text, status } = await deps.forwardToAnthropic(body)
  // Pass Anthropic's body + status through verbatim.
  return new Response(text, {
    status,
    headers: { "content-type": "application/json" },
  })
}

/** Production dependency wiring (real Supabase + Anthropic). */
function productionDeps(): ProxyDeps {
  return {
    authenticate: async (authHeader) => {
      const userClient: SupabaseClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: authHeader } } },
      )
      const { data: { user }, error } = await userClient.auth.getUser()
      if (error || !user) return null
      return { id: user.id, role: user.role ?? "" }
    },
    isPro: async (userId) => {
      // Service-role read so the entitlement check bypasses RLS and reflects
      // true server state.
      const admin: SupabaseClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      )
      return assertServerPro(admin, userId)
    },
    forwardToAnthropic: async (body) => {
      const resp = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
      })
      return { text: await resp.text(), status: resp.status }
    },
  }
}

// Only bind a port when run as the entrypoint, so importing this module in a
// test does not start a server.
if (import.meta.main) {
  const deps = productionDeps()
  serve((req) => handle(req, deps))
}
