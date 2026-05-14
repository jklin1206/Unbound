// supabase/functions/evaluate_squad_mission/index.ts
//
// Daily cron: iterates active squad missions, evaluates progress vs target,
// marks completed missions and posts a squad_activity row.
//
// Cron schedule: 0 2 * * * (2 AM UTC daily)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const { data: missions } = await supabase
    .from("squad_missions")
    .select("*")
    .is("completed_at", null)

  if (!missions) return new Response("no missions", { status: 200 })

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
        payload: { mission_id: mission.id, kind: mission.mission_kind, target: mission.target }
      })
    }
  }

  return new Response("ok", { status: 200 })
})
