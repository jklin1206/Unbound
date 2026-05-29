// Tests for server-side entitlement evaluation.
//
// Proof A (server denies spoof): assertServerPro returns false when the user
// row has is_pro=false, even though a real request would carry a client that
// asserts entitlement. The decision uses ONLY the server row.
//
// Proof B (no local backdoor): there is no input by which a client flag /
// onboarding reset can flip the result to true — the only true-producing path
// is a server row with is_pro=true and an unexpired (or absent) expiry.
import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts"
import {
  assertServerPro,
  evaluateProFromUserRow,
} from "./entitlement.ts"
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

const NOW = 1_700_000_000_000
const FUTURE = new Date(NOW + 86_400_000).toISOString()
const PAST = new Date(NOW - 86_400_000).toISOString()

Deno.test("evaluateProFromUserRow: is_pro=true + no expiry => pro", () => {
  assertEquals(evaluateProFromUserRow({ is_pro: true, is_pro_expires_at: null }, NOW), true)
})

Deno.test("evaluateProFromUserRow: is_pro=true + future expiry => pro", () => {
  assertEquals(evaluateProFromUserRow({ is_pro: true, is_pro_expires_at: FUTURE }, NOW), true)
})

Deno.test("evaluateProFromUserRow: is_pro=true but expired => NOT pro", () => {
  assertEquals(evaluateProFromUserRow({ is_pro: true, is_pro_expires_at: PAST }, NOW), false)
})

Deno.test("evaluateProFromUserRow: is_pro=false => NOT pro (Proof B core)", () => {
  assertEquals(evaluateProFromUserRow({ is_pro: false, is_pro_expires_at: FUTURE }, NOW), false)
})

Deno.test("evaluateProFromUserRow: missing row => NOT pro", () => {
  assertEquals(evaluateProFromUserRow(null, NOW), false)
})

// --- assertServerPro against a fake admin client (no network) ---

/** Builds a stub Supabase client whose users-row read returns `row`/`error`. */
function fakeAdmin(row: unknown, error: unknown = null): SupabaseClient {
  const builder = {
    select() { return this },
    eq() { return this },
    maybeSingle() { return Promise.resolve({ data: row, error }) },
  }
  return { from() { return builder } } as unknown as SupabaseClient
}

Deno.test("Proof A: assertServerPro denies when server is_pro=false", async () => {
  const admin = fakeAdmin({ is_pro: false, is_pro_expires_at: null })
  assertEquals(await assertServerPro(admin, "user-123", NOW), false)
})

Deno.test("assertServerPro grants when server is_pro=true + unexpired", async () => {
  const admin = fakeAdmin({ is_pro: true, is_pro_expires_at: FUTURE })
  assertEquals(await assertServerPro(admin, "user-123", NOW), true)
})

Deno.test("assertServerPro fails CLOSED on query error", async () => {
  const admin = fakeAdmin(null, { message: "boom" })
  assertEquals(await assertServerPro(admin, "user-123", NOW), false)
})

Deno.test("assertServerPro denies a missing user row", async () => {
  const admin = fakeAdmin(null)
  assertEquals(await assertServerPro(admin, "ghost", NOW), false)
})
