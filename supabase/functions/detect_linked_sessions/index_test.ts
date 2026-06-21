// deno test --allow-env detect_linked_sessions/index_test.ts
//
// Tests for the train_together mission hook and ISO week helper.
// The hook is factored into pure functions to avoid needing a Supabase mock.
import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { trainTogetherUpdate, computeLinkedSessionWeekIso } from "./helpers.ts"

const MISSION_ID = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
const LINKED_ID  = "cccccccc-4444-5555-6666-dddddddddddd"

// ---------------------------------------------------------------------------
// trainTogetherUpdate — pure update-payload computation
// ---------------------------------------------------------------------------

Deno.test("trainTogetherUpdate: returns null for non-train_together missions", () => {
  const result = trainTogetherUpdate(
    { id: MISSION_ID, mission_kind: "total_sessions", current_progress: 2, target: 8 },
    LINKED_ID
  )
  assertEquals(result, null)
})

Deno.test("trainTogetherUpdate: returns payload with incremented progress", () => {
  const result = trainTogetherUpdate(
    { id: MISSION_ID, mission_kind: "train_together", current_progress: 1, target: 3 },
    LINKED_ID
  )
  assertEquals(result?.missionId, MISSION_ID)
  assertEquals(result?.sourceLogId, `linked:${LINKED_ID}`)
  assertEquals(result?.progress, 2)
  assertEquals(result?.completedAt, null)  // 2 < 3, not yet complete
})

Deno.test("trainTogetherUpdate: sets completedAt when progress reaches target", () => {
  const result = trainTogetherUpdate(
    { id: MISSION_ID, mission_kind: "train_together", current_progress: 2, target: 3 },
    LINKED_ID
  )
  assertEquals(result?.progress, 3)
  assertNotEquals(result?.completedAt, null)  // 3 >= 3 → complete
})

Deno.test("trainTogetherUpdate: sets completedAt when progress exceeds target", () => {
  // Guard against a race where progress is already at target-1 and two linked
  // sessions land simultaneously — both increment, both should complete.
  const result = trainTogetherUpdate(
    { id: MISSION_ID, mission_kind: "train_together", current_progress: 3, target: 3 },
    LINKED_ID
  )
  assertEquals(result?.progress, 4)
  assertNotEquals(result?.completedAt, null)
})

Deno.test("trainTogetherUpdate: sourceLogId uses 'linked:' prefix", () => {
  const result = trainTogetherUpdate(
    { id: MISSION_ID, mission_kind: "train_together", current_progress: 0, target: 3 },
    LINKED_ID
  )
  assertEquals(result?.sourceLogId.startsWith("linked:"), true)
  assertEquals(result?.sourceLogId, `linked:${LINKED_ID}`)
})

// ---------------------------------------------------------------------------
// computeLinkedSessionWeekIso — ISO week string (mirrors iso_week.ts)
// ---------------------------------------------------------------------------

Deno.test("computeLinkedSessionWeekIso: Dec/Jan boundary — 2027-01-01 is ISO 2026-W53", () => {
  assertEquals(computeLinkedSessionWeekIso(new Date("2027-01-01T12:00:00Z")), "2026-W53")
})

Deno.test("computeLinkedSessionWeekIso: Dec/Jan boundary — 2024-12-31 is ISO 2025-W01", () => {
  assertEquals(computeLinkedSessionWeekIso(new Date("2024-12-31T12:00:00Z")), "2025-W01")
})

Deno.test("computeLinkedSessionWeekIso: mid-week is formatted with zero-pad", () => {
  // 2026-06-11 is a Wednesday in ISO week 24 of 2026
  const w = computeLinkedSessionWeekIso(new Date("2026-06-11T12:00:00Z"))
  assertEquals(w, "2026-W24")
})
