// supabase/functions/assign_weekly_honors/index.ts
//
// Sunday 11pm UTC cron: assigns 3 honor badges per squad for the past ISO week.
// v1 rotation: picks first unhonored member per honor kind.
// Real metric ranking (log counts, RPE, tier crossings) is a follow-up.
//
// Cron schedule: 0 23 * * 0 (11 PM UTC every Sunday)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const HONOR_KINDS = [
  "mostConsistent", "ironWill", "clutchPerformer", "mostImproved",
  "comebackArc", "earlyBird", "nightGrinder", "trialFinisher", "supportBuff"
]

serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const weekIso = computeIsoWeek(new Date())
  const { data: squads } = await supabase.from("squads").select("id")
  if (!squads) return new Response("no squads", { status: 200 })

  for (const squad of squads) {
    const { data: members } = await supabase
      .from("squad_members").select("user_id")
      .eq("squad_id", squad.id)
    if (!members || members.length < 2) continue

    // For each honor kind, compute the winner. v1 just rotates kinds and
    // picks first member as winner (real metrics in follow-up).
    const assigned = new Set()
    const honors = []
    for (const kind of HONOR_KINDS.slice(0, 3)) {
      // pick a member not yet honored this week
      const unhonored = members.filter(m => !assigned.has(m.user_id))
      if (unhonored.length === 0) break
      const winner = unhonored[0]
      assigned.add(winner.user_id)
      honors.push({ squad_id: squad.id, week_iso: weekIso, honor_kind: kind, recipient_user_id: winner.user_id })
    }
    if (honors.length > 0) {
      await supabase.from("squad_weekly_honors").insert(honors)
    }
  }

  return new Response("ok", { status: 200 })
})

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
