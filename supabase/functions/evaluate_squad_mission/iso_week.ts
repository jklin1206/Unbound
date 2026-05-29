// ISO-8601 week string "YYYY-Wnn" where YYYY is the ISO YEAR-OF-WEEK (not the
// calendar year of the date). MUST agree with the two other producers:
//   • Postgres RPC increment_squad_mission_progress: to_char(IYYY)||'-W'||to_char(IW)
//   • Swift client SquadMissionService.currentWeekIso(): yearForWeekOfYear + weekOfYear
// At the Dec/Jan boundary the calendar year and the ISO year-of-week diverge
// (e.g. 2027-01-01 belongs to ISO week 2026-W53). Reading the year from the
// Thursday of the target week keeps all three producers in lockstep.
export function computeIsoWeek(d: Date): string {
  const target = new Date(d.valueOf())
  const dayNumber = (d.getUTCDay() + 6) % 7
  target.setUTCDate(target.getUTCDate() - dayNumber + 3)
  const firstThursday = target.valueOf()
  target.setUTCMonth(0, 1)
  if (target.getUTCDay() !== 4) {
    target.setUTCMonth(0, 1 + ((4 - target.getUTCDay()) + 7) % 7)
  }
  const week = 1 + Math.ceil((firstThursday - target.valueOf()) / 604800000)
  const isoYear = new Date(firstThursday).getUTCFullYear()
  return `${isoYear}-W${week.toString().padStart(2, '0')}`
}
