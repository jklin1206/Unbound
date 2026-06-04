import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { computeIsoWeek } from "./iso_week.ts"

function referenceIsoWeek(d: Date): string {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()))
  const dayNum = (t.getUTCDay() + 6) % 7
  t.setUTCDate(t.getUTCDate() - dayNum + 3)
  const isoYear = t.getUTCFullYear()
  const firstThursday = new Date(Date.UTC(isoYear, 0, 4))
  const firstDayNum = (firstThursday.getUTCDay() + 6) % 7
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstDayNum + 3)
  const week = 1 + Math.round((t.valueOf() - firstThursday.valueOf()) / (7 * 86400000))
  return `${isoYear}-W${week.toString().padStart(2, "0")}`
}

Deno.test("assign_weekly_honors uses ISO year at Jan 1 boundary", () => {
  assertEquals(computeIsoWeek(new Date("2027-01-01T12:00:00Z")), "2026-W53")
})

Deno.test("assign_weekly_honors uses next ISO year at Dec 31 boundary", () => {
  assertEquals(computeIsoWeek(new Date("2024-12-31T12:00:00Z")), "2025-W01")
})

Deno.test("assign_weekly_honors ISO week matches reference across boundary years", () => {
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
