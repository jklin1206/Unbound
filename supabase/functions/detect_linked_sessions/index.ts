// supabase/functions/detect_linked_sessions/index.ts
// NOTE: assumes workout_logs table exists in Supabase. Confirmed in
// 20260418000001_initial_schema.sql with columns: started_at (timestamptz not null)
// and completed_at (timestamptz, nullable). Column names match spec exactly.
// Invoked via Supabase webhook on workout_logs INSERT. Configure via dashboard:
//   Webhook → POST to detect_linked_sessions on workout_logs INSERT
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const LINKED_SLACK_MINUTES = 5

interface WebhookPayload {
  record: {
    id: string
    user_id: string
    started_at: string
    completed_at?: string
  }
}

serve(async (req) => {
  const payload: WebhookPayload = await req.json()
  const log = payload.record
  if (!log.completed_at) return new Response("incomplete", { status: 200 })

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  // 1. Find user's squad
  const { data: member } = await supabase
    .from("squad_members")
    .select("squad_id")
    .eq("user_id", log.user_id)
    .maybeSingle()
  if (!member) return new Response("no squad", { status: 200 })

  const squadId = member.squad_id

  // 2. Find overlapping sessions in the same squad
  const startedAt = new Date(log.started_at)
  const endedAt = new Date(log.completed_at)
  const slackMs = LINKED_SLACK_MINUTES * 60 * 1000

  const { data: squadMembers } = await supabase
    .from("squad_members")
    .select("user_id")
    .eq("squad_id", squadId)
  const otherUserIds = (squadMembers ?? [])
    .map((m) => m.user_id)
    .filter((id) => id !== log.user_id)

  if (otherUserIds.length === 0) return new Response("solo squad", { status: 200 })

  const windowStart = new Date(startedAt.getTime() - slackMs).toISOString()
  const windowEnd = new Date(endedAt.getTime() + slackMs).toISOString()

  const { data: overlaps } = await supabase
    .from("workout_logs")
    .select("user_id, started_at, completed_at")
    .in("user_id", otherUserIds)
    .lte("started_at", windowEnd)
    .gte("completed_at", windowStart)
  if (!overlaps || overlaps.length === 0) return new Response("no overlap", { status: 200 })

  // 3. Compute the linked window
  const participants = [log.user_id, ...overlaps.map((o) => o.user_id)]
  const dedupedParticipants = Array.from(new Set(participants))

  // 4. Insert linked_sessions + activity
  await supabase.from("linked_sessions").insert({
    squad_id: squadId,
    user_ids: dedupedParticipants,
    started_at: startedAt.toISOString(),
    ended_at: endedAt.toISOString()
  })

  const durationMinutes = Math.round((endedAt.getTime() - startedAt.getTime()) / 60000)
  await supabase.from("squad_activity").insert({
    squad_id: squadId,
    user_id: log.user_id,
    kind: "linkedSession",
    payload: {
      participantUserIds: dedupedParticipants,
      durationMinutes
    }
  })

  // 5. Send APNs pushes to all participants (existing push infrastructure)
  // This step depends on the existing push setup. If there's a `send_push`
  // Edge Function already, call it here. Otherwise document as a follow-up.
  await sendLinkedSessionPushes(supabase, squadId, dedupedParticipants)

  return new Response("linked", { status: 200 })
})

async function sendLinkedSessionPushes(supabase: any, squadId: string, userIds: string[]) {
  // Look up device tokens for each user from `device_tokens` (or whatever
  // the existing push pipeline uses), then dispatch APNs/FCM payloads.
  // If push infra isn't ready, log + continue. Document the gap.
  // TODO(squads-impl, Phase 10): wire APNs/FCM dispatch via device_tokens table
  console.log("sendLinkedSessionPushes", squadId, userIds)
}
