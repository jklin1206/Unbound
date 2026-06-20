// detect_linked_sessions/helpers.ts
// Pure functions factored out for unit testing — no Deno.serve() side effects.

/** Compute the squad_missions update payload for a train_together receipt.
 *  Returns null if the mission is not train_together.
 *  The caller inserts the receipt first; this computes the update payload
 *  assuming the insert succeeded (i.e. no unique-constraint conflict).
 */
export function trainTogetherUpdate(
  mission: { id: string; mission_kind: string; current_progress: number; target: number },
  linkedSessionId: string
): { missionId: string; sourceLogId: string; progress: number; completedAt: string | null } | null {
  if (mission.mission_kind !== "train_together") return null
  const progress = mission.current_progress + 1
  return {
    missionId: mission.id,
    sourceLogId: `linked:${linkedSessionId}`,
    progress,
    completedAt: progress >= mission.target ? new Date().toISOString() : null,
  }
}

// Compute ISO-8601 week string "YYYY-Wnn" (ISO year-of-week, not calendar year).
// Mirrors computeIsoWeek in evaluate_squad_mission/iso_week.ts, Postgres IYYY/IW,
// and Swift SquadMissionService.currentWeekIso().
export function computeLinkedSessionWeekIso(d: Date): string {
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
  return `${isoYear}-W${week.toString().padStart(2, "0")}`
}
