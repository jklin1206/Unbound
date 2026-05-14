// supabase/functions/assign_weekly_honors/index.ts
//
// Sunday 11pm UTC cron: assigns up to 3 honor badges per squad for the past ISO week.
// Uses real metric computation per honor kind. No member gets 2 honors same week.
// Rotates away from last week's same-kind recipient when there's a tie.
//
// Cron schedule: 0 23 * * 0 (11 PM UTC every Sunday)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

const HONOR_KINDS = [
  "mostConsistent", "ironWill", "clutchPerformer", "mostImproved",
  "comebackArc", "earlyBird", "nightGrinder", "trialFinisher", "supportBuff"
]

serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  // Assign for the week that just ended (previous ISO week).
  // Sunday 11pm = end of the week, so we compute the week of today.
  const weekIso = computeIsoWeek(new Date())
  const lastWeekIso = computeIsoWeek(addDays(new Date(), -7))

  const { data: squads } = await supabase.from("squads").select("id")
  if (!squads) return new Response("no squads", { status: 200 })

  for (const squad of squads) {
    const { data: members } = await supabase
      .from("squad_members").select("user_id")
      .eq("squad_id", squad.id)
    if (!members || members.length < 2) continue

    const userIds: string[] = members.map((m: { user_id: string }) => m.user_id)
    const memberCount = userIds.length

    // How many honors to assign — fewer for small squads
    const honorCount = memberCount < 3 ? 1 : (memberCount < 5 ? 2 : 3)

    // Fetch last week's honors for rotation logic
    const { data: lastWeekHonors } = await supabase
      .from("squad_weekly_honors")
      .select("honor_kind, recipient_user_id")
      .eq("squad_id", squad.id)
      .eq("week_iso", lastWeekIso)
    const lastWeekByKind: Record<string, string> = {}
    for (const h of (lastWeekHonors ?? [])) {
      lastWeekByKind[h.honor_kind] = h.recipient_user_id
    }

    // Compute all metrics for this week's window
    const weekStart = getIsoWeekStart(new Date()).toISOString()
    const weekEnd = new Date().toISOString()

    const metrics = await computeMetrics(supabase, userIds, weekStart, weekEnd)

    const assigned = new Set<string>()  // user_ids already given an honor
    const honors: Array<{
      squad_id: string, week_iso: string, honor_kind: string, recipient_user_id: string
    }> = []

    // Rotate through honor kinds in a deterministic order seeded by squad id
    const shuffled = deterministicShuffle(HONOR_KINDS, squad.id + weekIso)

    for (const kind of shuffled) {
      if (honors.length >= honorCount) break

      const scores = metrics[kind]
      if (!scores || Object.keys(scores).length === 0) continue

      // Filter to unassigned members with a non-zero score
      const eligible = Object.entries(scores)
        .filter(([uid, score]) => !assigned.has(uid) && score > 0)
        .sort((a, b) => (b[1] as number) - (a[1] as number))
      if (eligible.length === 0) continue

      const topScore = eligible[0][1] as number
      const tied = eligible.filter(([, s]) => (s as number) === topScore)

      // Prefer someone other than last week's recipient if there's a tie
      const lastRecipient = lastWeekByKind[kind]
      let winner: string
      if (tied.length > 1 && lastRecipient) {
        const preferred = tied.find(([uid]) => uid !== lastRecipient)
        winner = preferred ? preferred[0] : tied[0][0]
      } else {
        winner = tied[0][0]
      }

      assigned.add(winner)
      honors.push({
        squad_id: squad.id,
        week_iso: weekIso,
        honor_kind: kind,
        recipient_user_id: winner
      })
    }

    if (honors.length > 0) {
      // Use upsert to avoid duplicate rows if the cron runs twice
      await supabase.from("squad_weekly_honors").upsert(honors, {
        onConflict: "squad_id,week_iso,honor_kind",
        ignoreDuplicates: true
      })
    }
  }

  return new Response("ok", { status: 200 })
})

// ---------------------------------------------------------------------------
// Metric computation
// Returns: { [honorKind]: { [userId]: score } }
// ---------------------------------------------------------------------------

async function computeMetrics(
  supabase: SupabaseClient,
  userIds: string[],
  weekStart: string,
  weekEnd: string
): Promise<Record<string, Record<string, number>>> {
  const result: Record<string, Record<string, number>> = {}

  // 1. mostConsistent — COUNT(DISTINCT date of log) per user
  {
    const { data: logs } = await supabase
      .from("workout_logs")
      .select("user_id, started_at")
      .in("user_id", userIds)
      .gte("started_at", weekStart)
      .lte("started_at", weekEnd)
    const scores: Record<string, Set<string>> = {}
    for (const log of (logs ?? [])) {
      const day = log.started_at.slice(0, 10)
      if (!scores[log.user_id]) scores[log.user_id] = new Set()
      scores[log.user_id].add(day)
    }
    result["mostConsistent"] = Object.fromEntries(
      Object.entries(scores).map(([uid, days]) => [uid, days.size])
    )
  }

  // 2. ironWill — AVG(rpe) across all set_logs this week via exercise_log_entries
  {
    const { data: sets } = await supabase
      .from("set_logs")
      .select("user_id, rpe")
      .in("user_id", userIds)
      .gte("created_at", weekStart)
      .lte("created_at", weekEnd)
      .not("rpe", "is", null)
    const totals: Record<string, { sum: number, count: number }> = {}
    for (const s of (sets ?? [])) {
      if (!totals[s.user_id]) totals[s.user_id] = { sum: 0, count: 0 }
      totals[s.user_id].sum += s.rpe ?? 0
      totals[s.user_id].count++
    }
    result["ironWill"] = Object.fromEntries(
      Object.entries(totals).map(([uid, t]) => [uid, t.count > 0 ? Math.round((t.sum / t.count) * 100) : 0])
    )
  }

  // 3. clutchPerformer — count of skill tier transitions in user_skill_tier_state (if table exists)
  //    Graceful fallback: skip (empty scores) if table doesn't exist or has no history column.
  {
    try {
      const { data: tierEvents } = await supabase
        .from("skill_tier_history")
        .select("user_id")
        .in("user_id", userIds)
        .gte("created_at", weekStart)
        .lte("created_at", weekEnd)
      const scores: Record<string, number> = {}
      for (const e of (tierEvents ?? [])) {
        scores[e.user_id] = (scores[e.user_id] ?? 0) + 1
      }
      result["clutchPerformer"] = scores
    } catch {
      result["clutchPerformer"] = {}
    }
  }

  // 4. mostImproved — attribute delta from attribute_profile_snapshots (skip if table absent)
  {
    try {
      const { data: snaps } = await supabase
        .from("attribute_profile_snapshots")
        .select("user_id, created_at, total_score")
        .in("user_id", userIds)
        .gte("created_at", addDays(new Date(), -14).toISOString())
      const byUser: Record<string, { oldest: number, newest: number }> = {}
      for (const s of (snaps ?? [])) {
        const prev = byUser[s.user_id]
        const ts = new Date(s.created_at).getTime()
        if (!prev) {
          byUser[s.user_id] = { oldest: s.total_score, newest: s.total_score }
        } else {
          // track the widest spread this fortnight
          byUser[s.user_id].newest = Math.max(prev.newest, s.total_score)
          byUser[s.user_id].oldest = Math.min(prev.oldest, s.total_score)
        }
      }
      result["mostImproved"] = Object.fromEntries(
        Object.entries(byUser).map(([uid, v]) => [uid, Math.max(0, v.newest - v.oldest)])
      )
    } catch {
      result["mostImproved"] = {}
    }
  }

  // 5. comebackArc — user with last log 7+ days before weekStart AND 3+ logs this week
  {
    const { data: allRecentLogs } = await supabase
      .from("workout_logs")
      .select("user_id, started_at")
      .in("user_id", userIds)
      .gte("started_at", addDays(new Date(), -14).toISOString())
    const logsThisWeek: Record<string, number> = {}
    const lastLogBefore: Record<string, number> = {}
    const cutoff = new Date(weekStart).getTime()
    for (const log of (allRecentLogs ?? [])) {
      const ts = new Date(log.started_at).getTime()
      if (ts >= cutoff) {
        logsThisWeek[log.user_id] = (logsThisWeek[log.user_id] ?? 0) + 1
      } else {
        // track latest pre-week log timestamp
        const prev = lastLogBefore[log.user_id]
        if (!prev || ts > prev) lastLogBefore[log.user_id] = ts
      }
    }
    const sevenDaysMs = 7 * 24 * 3600 * 1000
    const scores: Record<string, number> = {}
    for (const uid of userIds) {
      const prevTs = lastLogBefore[uid]
      const thisWeekCount = logsThisWeek[uid] ?? 0
      if (prevTs && (cutoff - prevTs) >= sevenDaysMs && thisWeekCount >= 3) {
        scores[uid] = thisWeekCount
      }
    }
    result["comebackArc"] = scores
  }

  // 6. earlyBird — COUNT workouts where UTC hour < 7
  {
    const { data: logs } = await supabase
      .from("workout_logs")
      .select("user_id, started_at")
      .in("user_id", userIds)
      .gte("started_at", weekStart)
      .lte("started_at", weekEnd)
    const scores: Record<string, number> = {}
    for (const log of (logs ?? [])) {
      const hour = new Date(log.started_at).getUTCHours()
      if (hour < 7) {
        scores[log.user_id] = (scores[log.user_id] ?? 0) + 1
      }
    }
    result["earlyBird"] = scores
  }

  // 7. nightGrinder — COUNT workouts where UTC hour >= 21
  {
    const { data: logs } = await supabase
      .from("workout_logs")
      .select("user_id, started_at")
      .in("user_id", userIds)
      .gte("started_at", weekStart)
      .lte("started_at", weekEnd)
    const scores: Record<string, number> = {}
    for (const log of (logs ?? [])) {
      const hour = new Date(log.started_at).getUTCHours()
      if (hour >= 21) {
        scores[log.user_id] = (scores[log.user_id] ?? 0) + 1
      }
    }
    result["nightGrinder"] = scores
  }

  // 8. trialFinisher — count of capstone-completion squad_activity entries
  {
    const { data: acts } = await supabase
      .from("squad_activity")
      .select("user_id")
      .in("user_id", userIds)
      .eq("kind", "trialCompleted")
      .gte("created_at", weekStart)
      .lte("created_at", weekEnd)
    const scores: Record<string, number> = {}
    for (const a of (acts ?? [])) {
      if (a.user_id) scores[a.user_id] = (scores[a.user_id] ?? 0) + 1
    }
    result["trialFinisher"] = scores
  }

  // 9. supportBuff — count of linked_sessions entries where user_id is in the user_ids array
  //    linked_sessions.user_ids is a uuid[]. We check containment via Postgres operator.
  {
    const scores: Record<string, number> = {}
    for (const uid of userIds) {
      const { count } = await supabase
        .from("linked_sessions")
        .select("*", { count: "exact", head: true })
        .gte("started_at", weekStart)
        .lte("started_at", weekEnd)
        .contains("user_ids", [uid])
      scores[uid] = count ?? 0
    }
    result["supportBuff"] = scores
  }

  return result
}

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

function getIsoWeekStart(d: Date): Date {
  const day = (d.getUTCDay() + 6) % 7  // Mon=0
  const start = new Date(d)
  start.setUTCDate(d.getUTCDate() - day)
  start.setUTCHours(0, 0, 0, 0)
  return start
}

function addDays(d: Date, days: number): Date {
  const result = new Date(d)
  result.setUTCDate(result.getUTCDate() + days)
  return result
}

// Deterministic shuffle using a string seed (squad.id + weekIso)
// so the honor priority order is stable for a given squad/week.
function deterministicShuffle<T>(arr: T[], seed: string): T[] {
  const hash = simpleHash(seed)
  const copy = [...arr]
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.abs(simpleHash(seed + i)) % (i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]]
  }
  return copy
}

function simpleHash(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0
  }
  return Math.abs(h)
}
