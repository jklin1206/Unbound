// supabase/functions/evaluate_squad_streak/index.ts
// Cron: 03:00 UTC daily. Configure via Supabase dashboard or pg_cron after deploy.
// Nightly cron at 03:00 UTC. For each squad, check whether every member
// logged ≥1 session in the prior ISO week. Update squad_streak_weeks +
// post squadStreakExtended activity on increment.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  // Compute prior ISO week window (UTC Mon 00:00 → Sun 23:59:59)
  const now = new Date()
  const day = now.getUTCDay() || 7  // ISO day 1-7, Sunday = 7
  const thisMonday = new Date(now)
  thisMonday.setUTCDate(now.getUTCDate() - (day - 1))
  thisMonday.setUTCHours(0, 0, 0, 0)
  const lastMonday = new Date(thisMonday)
  lastMonday.setUTCDate(thisMonday.getUTCDate() - 7)
  const lastSunday = new Date(thisMonday)
  lastSunday.setUTCMilliseconds(-1)

  const { data: squads } = await supabase
    .from("squads")
    .select("id, squad_streak_weeks")
  if (!squads) return new Response("no squads", { status: 200 })

  for (const squad of squads) {
    const { data: members } = await supabase
      .from("squad_members")
      .select("user_id")
      .eq("squad_id", squad.id)
    if (!members || members.length === 0) continue

    let allActive = true
    for (const member of members) {
      const { count } = await supabase
        .from("workout_logs")
        .select("id", { count: "exact", head: true })
        .eq("user_id", member.user_id)
        .gte("started_at", lastMonday.toISOString())
        .lte("started_at", lastSunday.toISOString())
      if ((count ?? 0) === 0) {
        allActive = false
        break
      }
    }

    if (allActive) {
      const newWeeks = squad.squad_streak_weeks + 1
      await supabase.from("squads").update({ squad_streak_weeks: newWeeks }).eq("id", squad.id)
      await supabase.from("squad_activity").insert({
        squad_id: squad.id,
        user_id: null,  // System event — no human actor; column is nullable per 20260513130000 migration.
        kind: "squadStreakExtended",
        payload: { weeks: newWeeks }
      })
    } else if (squad.squad_streak_weeks > 0) {
      await supabase.from("squads").update({ squad_streak_weeks: 0 }).eq("id", squad.id)
      // No activity entry on reset — quiet break per spec.
    }
  }

  return new Response("ok", { status: 200 })
})
