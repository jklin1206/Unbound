// supabase/functions/_shared/entitlement.ts
// Server-side premium entitlement check. The user row's `is_pro` column (set
// only by the revenuecat_webhook Edge Function) is the single source of truth.
// Premium Edge Functions MUST call assertServerPro() before doing premium work
// so a spoofed/asserted client entitlement cannot unlock paid features.
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

/** Minimal shape of the columns we read off public.users. */
export interface ProUserRow {
  is_pro: boolean | null
  is_pro_expires_at: string | null
}

/**
 * Decide whether a user row currently grants premium access.
 *
 * Pure function (no I/O) so it is trivially unit-testable. The decision is
 * derived ONLY from server-owned columns — the client cannot influence it.
 *
 * @param row    The user's is_pro / is_pro_expires_at columns, or null if no row.
 * @param now    Current time (injectable for tests). Defaults to Date.now().
 * @returns true only when the server flag is set AND not expired.
 */
export function evaluateProFromUserRow(
  row: ProUserRow | null,
  now: number = Date.now(),
): boolean {
  if (!row || row.is_pro !== true) return false
  // No expiry recorded => treat the active flag as authoritative.
  if (!row.is_pro_expires_at) return true
  const expiresAt = Date.parse(row.is_pro_expires_at)
  if (Number.isNaN(expiresAt)) return false
  return expiresAt > now
}

/**
 * Look up the caller's server-owned entitlement and return whether they are pro.
 *
 * @param admin  A Supabase client authenticated with the SERVICE ROLE key so the
 *               read bypasses RLS and reflects the true server state.
 * @param userId The authenticated user's id (from auth.getUser(), never the body).
 * @param now    Current time (injectable for tests).
 * @returns true only when the server row grants active premium access.
 */
export async function assertServerPro(
  admin: SupabaseClient,
  userId: string,
  now: number = Date.now(),
): Promise<boolean> {
  const { data, error } = await admin
    .from("users")
    .select("is_pro, is_pro_expires_at")
    .eq("id", userId)
    .maybeSingle()
  if (error) {
    // Fail CLOSED: if we cannot confirm entitlement, deny premium work.
    return false
  }
  return evaluateProFromUserRow(data as ProUserRow | null, now)
}
