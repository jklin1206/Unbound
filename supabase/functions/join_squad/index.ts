// supabase/functions/join_squad/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface JoinRequest {
  invite_code: string
}

serve(async (req) => {
  const body: JoinRequest = await req.json()
  const inviteCode = body.invite_code?.toUpperCase().trim()
  if (!inviteCode || inviteCode.length !== 6) {
    return new Response(JSON.stringify({ error: "invalid_invite_code" }), {
      status: 400,
      headers: { "Content-Type": "application/json" }
    })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error: userErr } = await userClient.auth.getUser()
  if (userErr || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 })
  }

  // Already in a squad?
  const { data: existing } = await supabase
    .from("squad_members")
    .select("squad_id")
    .eq("user_id", user.id)
    .maybeSingle()
  if (existing) {
    return new Response(JSON.stringify({ error: "already_in_squad" }), { status: 409 })
  }

  // Look up squad by invite code
  const { data: squad, error: sqErr } = await supabase
    .from("squads")
    .select("*")
    .eq("invite_code", inviteCode)
    .maybeSingle()
  if (sqErr || !squad) {
    return new Response(JSON.stringify({ error: "invalid_invite_code" }), { status: 404 })
  }

  // Check capacity
  const { count } = await supabase
    .from("squad_members")
    .select("*", { count: "exact", head: true })
    .eq("squad_id", squad.id)
  if ((count ?? 0) >= squad.max_size) {
    return new Response(JSON.stringify({ error: "squad_full" }), { status: 409 })
  }

  // Fetch user's display name from `users` table
  // Column confirmed in initial_schema.sql: public.users has both display_name (text)
  // and display_handle (text). Using display_handle per plan spec.
  const { data: profile } = await supabase
    .from("users")
    .select("display_handle")
    .eq("id", user.id)
    .single()
  const displayName = profile?.display_handle ?? "Someone"

  // Insert member + activity entry atomically (use a transaction wrapper or
  // sequential inserts with cleanup on failure)
  await supabase
    .from("squad_members")
    .insert({ squad_id: squad.id, user_id: user.id })

  await supabase
    .from("squad_activity")
    .insert({
      squad_id: squad.id,
      user_id: user.id,
      kind: "memberJoined",
      payload: { memberDisplayName: displayName }
    })

  return new Response(JSON.stringify({ squad }), {
    status: 200,
    headers: { "Content-Type": "application/json" }
  })
})
