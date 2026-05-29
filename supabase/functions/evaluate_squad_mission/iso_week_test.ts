// Run: deno test --allow-all supabase/functions/evaluate_squad_mission/iso_week_test.ts
//
// BLOCKER 1 proof: the cron's week string must use the ISO YEAR-OF-WEEK, the
// same value the Postgres RPC (to_char IYYY/IW) and Swift client
// (yearForWeekOfYear/weekOfYear) compute. The bug emitted the calendar year,
// which diverges from the ISO year-of-week ~1 week per year at the Dec/Jan
// boundary.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { computeIsoWeek } from "./iso_week.ts"

// Reference ISO-8601 year-of-week + week number, computed independently of the
// implementation under test (mirrors Postgres IYYY/IW and Swift
// yearForWeekOfYear). Used as the oracle the cron must agree with.
function referenceIsoWeek(d: Date): string {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()))
  // Shift to the Thursday of this week (ISO: Mon=0..Sun=6).
  const dayNum = (t.getUTCDay() + 6) % 7
  t.setUTCDate(t.getUTCDate() - dayNum + 3)
  const isoYear = t.getUTCFullYear()
  const firstThursday = new Date(Date.UTC(isoYear, 0, 4))
  const firstDayNum = (firstThursday.getUTCDay() + 6) % 7
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstDayNum + 3)
  const week = 1 + Math.round((t.valueOf() - firstThursday.valueOf()) / (7 * 86400000))
  return `${isoYear}-W${week.toString().padStart(2, "0")}`
}

Deno.test("Dec/Jan boundary: 2027-01-01 is ISO 2026-W53, not 2027-W53", () => {
  // 2027-01-01 is a Friday; ISO-8601 places it in week 53 of 2026.
  assertEquals(computeIsoWeek(new Date("2027-01-01T12:00:00Z")), "2026-W53")
})

Deno.test("Dec/Jan boundary: 2024-12-31 is ISO 2025-W01", () => {
  // 2024-12-31 is a Tuesday; ISO-8601 places it in week 1 of 2025.
  assertEquals(computeIsoWeek(new Date("2024-12-31T12:00:00Z")), "2025-W01")
})

Deno.test("cron agrees with reference ISO week across a multi-year span", () => {
  // Walk every day across the boundary-heavy span and assert lockstep.
  const start = Date.UTC(2024, 0, 1)
  const end = Date.UTC(2028, 11, 31)
  for (let t = start; t <= end; t += 86400000) {
    const d = new Date(t)
    assertEquals(
      computeIsoWeek(d),
      referenceIsoWeek(d),
      `mismatch on ${d.toISOString().slice(0, 10)}`,
    )
  }
})
