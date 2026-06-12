// supabase/functions/evaluate_squad_mission/index.ts
//
// Daily cron: iterates active squad missions, evaluates progress vs target,
// marks completed missions and posts a squad_activity row.
// ALSO: for each squad, generates a mission for the current ISO week if none exists.
//
// Cron schedule: 0 2 * * * (2 AM UTC daily)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { computeIsoWeek } from "./iso_week.ts"
import { requireEmptyJsonObjectBody, requirePost, requireServiceFunctionAuth } from "../_shared/service_auth.ts"

// ---------------------------------------------------------------------------
// Mission catalog — ORDER IS THE HASH CONTRACT.
// Must stay in sync with three sites:
//   • SquadMissionCatalog.swift (iOS client)
//   • this file
//   • the SQL fallback `case v_template_idx` block in
//     20260611120000_squad_mission_kinds_v2.sql
//
// idx 0 total_weight   8000 × memberCount
// idx 1 total_sessions 4 × memberCount
// idx 2 total_reps     600 × memberCount
// idx 3 crew_coverage  memberCount
// idx 4 train_together 3 (fixed)
// ---------------------------------------------------------------------------

const MISSION_TEMPLATES: Array<{ kind: string }> = [
  { kind: "total_weight" },
  { kind: "total_sessions" },
  { kind: "total_reps" },
  { kind: "crew_coverage" },
  { kind: "train_together" },
]

function generateMission(squadId: string, weekIso: string, memberCount: number): {
  kind: string, target: number
} {
  const hash = simpleHash(squadId + weekIso)
  const idx = hash % MISSION_TEMPLATES.length
  const kind = MISSION_TEMPLATES[idx].kind
  let target: number
  switch (kind) {
    case "total_weight":    target = 8000 * memberCount; break
    case "total_sessions":  target = 4 * memberCount;    break
    case "total_reps":      target = 600 * memberCount;  break
    case "crew_coverage":   target = memberCount;         break
    default:                target = 3;                   break  // train_together
  }
  return { kind, target }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  const methodError = requirePost(req)
  if (methodError) return methodError
  const authError = requireServiceFunctionAuth(req)
  if (authError) return authError
  const bodyError = await requireEmptyJsonObjectBody(req)
  if (bodyError) return bodyError

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

function simpleHash(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0
  }
  return Math.abs(h)
}
