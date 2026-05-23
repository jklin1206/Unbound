// supabase/functions/evaluate_squad_mission/index.ts
//
// Daily cron: iterates active squad missions, evaluates progress vs target,
// marks completed missions and posts a squad_activity row.
// ALSO: for each squad, generates a mission for the current ISO week if none exists.
//
// Cron schedule: 0 2 * * * (2 AM UTC daily)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ---------------------------------------------------------------------------
// Mission catalog — mirrors SquadMissionCatalog.swift
// ---------------------------------------------------------------------------

const MISSION_TEMPLATES: Array<{ kind: string; targetMultiplier: number }> = [
  { kind: "alignedSessions",   targetMultiplier: 4 },
  { kind: "capstonesTogether", targetMultiplier: 1 },
  { kind: "focusSessions",     targetMultiplier: 6 },
  { kind: "tierCrossings",     targetMultiplier: 1 },
  { kind: "linkedSessions",    targetMultiplier: 1 },  // fixed at 3
  { kind: "perfectAttendance", targetMultiplier: 1 },  // 1 per member
]

function generateMission(squadId: string, weekIso: string, memberCount: number): {
  kind: string, target: number
} {
  const hash = simpleHash(squadId + weekIso)
  const idx = hash % MISSION_TEMPLATES.length
  const t = MISSION_TEMPLATES[idx]
  let target: number
  switch (t.kind) {
    case "linkedSessions":
      target = 3
      break
    case "perfectAttendance":
      target = memberCount
      break
    default:
      target = t.targetMultiplier * memberCount
  }
  return { kind: t.kind, target }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const weekIso = computeIsoWeek(new Date())

  // ---- Phase 1: Evaluate completion on existing missions ----
  const { data: missions } = await supabase
    .from("squad_missions")
    .select("*")
    .is("completed_at", null)

  if (missions) {
    for (const mission of missions) {
      if (mission.current_progress >= mission.target) {
        await supabase
          .from("squad_missions")
          .update({ completed_at: new Date().toISOString() })
          .eq("id", mission.id)

        await supabase.from("squad_activity").insert({
          squad_id: mission.squad_id,
          user_id: null,  // system event
          kind: "squadMissionCompleted",
          payload: {
            mission_id: mission.id,
            kind: mission.mission_kind,
            target: mission.target
          }
        })
      }
    }
  }

  // ---- Phase 2: Generate missions for squads that have none for this ISO week ----
  const { data: squads } = await supabase.from("squads").select("id")
  if (!squads) return new Response("ok", { status: 200 })

  for (const squad of squads) {
    // Check if a mission already exists for this squad + week
    const { data: existing } = await supabase
      .from("squad_missions")
      .select("id")
      .eq("squad_id", squad.id)
      .eq("week_iso", weekIso)
      .limit(1)

    if (existing && existing.length > 0) continue  // already has one

    // Count members to compute target
    const { count: memberCount } = await supabase
      .from("squad_members")
      .select("*", { count: "exact", head: true })
      .eq("squad_id", squad.id)

    const mc = memberCount ?? 4  // safe fallback
    if (mc < 2) continue  // solo squads don't get missions

    const { kind, target } = generateMission(squad.id, weekIso, mc)

    await supabase.from("squad_missions").insert({
      squad_id: squad.id,
      week_iso: weekIso,
      mission_kind: kind,
      target,
      current_progress: 0,
      created_at: new Date().toISOString()
    })
  }

  return new Response("ok", { status: 200 })
})

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

function computeIsoWeek(d: Date): string {
  const target = new Date(d.valueOf())
  const dayNumber = (d.getUTCDay() + 6) % 7
  target.setUTCDate(target.getUTCDate() - dayNumber + 3)
  const firstThursday = target.valueOf()
  target.setUTCMonth(0, 1)
  if (target.getUTCDay() !== 4) {
    target.setUTCMonth(0, 1 + ((4 - target.getUTCDay()) + 7) % 7)
  }
  const week = 1 + Math.ceil((firstThursday - target.valueOf()) / 604800000)
  return `${d.getUTCFullYear()}-W${week.toString().padStart(2, '0')}`
}

function simpleHash(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0
  }
  return Math.abs(h)
}
