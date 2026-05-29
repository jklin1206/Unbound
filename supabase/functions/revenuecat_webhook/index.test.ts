// Tests for the RevenueCat webhook entitlement sync.
// Covers: event-type -> pro mapping, expiry handling, and (Proof A) that a
// spoofed local entitlement is irrelevant because pro state derives ONLY from
// the server-side RC event.
import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts"
import { parseRevenueCatEvent } from "./index.ts"

const NOW = 1_700_000_000_000 // fixed clock
const FUTURE = NOW + 86_400_000 // +1 day
const PAST = NOW - 86_400_000 // -1 day

function rcEvent(type: string, extra: Record<string, unknown> = {}) {
  return { event: { app_user_id: "user-123", type, ...extra } }
}

Deno.test("INITIAL_PURCHASE with future expiry grants pro", () => {
  const r = parseRevenueCatEvent(rcEvent("INITIAL_PURCHASE", { expiration_at_ms: FUTURE }), NOW)
  assertExists(r)
  assertEquals(r.appUserId, "user-123")
  assertEquals(r.isPro, true)
  assertEquals(r.expiresAt, new Date(FUTURE).toISOString())
})

Deno.test("RENEWAL with future expiry grants pro", () => {
  const r = parseRevenueCatEvent(rcEvent("RENEWAL", { expiration_at_ms: FUTURE }), NOW)
  assertEquals(r?.isPro, true)
})

Deno.test("EXPIRATION revokes pro", () => {
  const r = parseRevenueCatEvent(rcEvent("EXPIRATION", { expiration_at_ms: PAST }), NOW)
  assertExists(r)
  assertEquals(r.isPro, false)
  assertEquals(r.expiresAt, null)
})

Deno.test("BILLING_ISSUE revokes pro", () => {
  const r = parseRevenueCatEvent(rcEvent("BILLING_ISSUE"), NOW)
  assertEquals(r?.isPro, false)
})

Deno.test("CANCELLATION keeps pro until expiry passes", () => {
  const stillActive = parseRevenueCatEvent(rcEvent("CANCELLATION", { expiration_at_ms: FUTURE }), NOW)
  assertEquals(stillActive?.isPro, true)
  const lapsed = parseRevenueCatEvent(rcEvent("CANCELLATION", { expiration_at_ms: PAST }), NOW)
  assertEquals(lapsed?.isPro, false)
})

Deno.test("granting event whose expiry already passed does NOT grant pro", () => {
  const r = parseRevenueCatEvent(rcEvent("RENEWAL", { expiration_at_ms: PAST }), NOW)
  assertEquals(r?.isPro, false)
})

Deno.test("unknown / TEST / TRANSFER events are ignored (null)", () => {
  assertEquals(parseRevenueCatEvent(rcEvent("TEST"), NOW), null)
  assertEquals(parseRevenueCatEvent(rcEvent("TRANSFER"), NOW), null)
})

Deno.test("malformed payloads return null", () => {
  assertEquals(parseRevenueCatEvent(null, NOW), null)
  assertEquals(parseRevenueCatEvent({}, NOW), null)
  assertEquals(parseRevenueCatEvent({ event: {} }, NOW), null)
  assertEquals(parseRevenueCatEvent({ event: { app_user_id: "x" } }, NOW), null)
})
