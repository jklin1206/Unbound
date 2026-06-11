// supabase/functions/join_squad/index.ts
//
// Thin HTTP shell over the join_squad_atomic RPC (migration
// 20260611093000): the RPC owns the per-user throttle, the FOR UPDATE
// capacity check, and the member+activity transaction. This function owns
// JWT resolution and the HTTP contract.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface JoinRequest {
  invite_code: string
}

const ERROR_STATUS: Record<string, number> = {
  unauthorized: 401,
  rate_limited: 429,
  already_in_squad: 409,
  invalid_invite_code: 404,
  squad_full: 409,
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" }
  })
}

serve(async (req) => {
  const body: JoinRequest = await req.json()
  const inviteCode = body.invite_code?.toUpperCase().trim()
  if (!inviteCode || inviteCode.length !== 6) {
    return jsonResponse({ error: "invalid_invite_code" }, 400)
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
    return jsonResponse({ error: "unauthorized" }, 401)
  }

  const { data, error } = await supabase.rpc("join_squad_atomic", {
    p_user_id: user.id,
    p_invite_code: inviteCode
  })
  if (error) {
    console.error("join_squad_atomic failed:", error.message)
    return jsonResponse({ error: "join_failed" }, 500)
  }

  const rpcError = data?.error as string | undefined
  if (rpcError) {
    return jsonResponse({ error: rpcError }, ERROR_STATUS[rpcError] ?? 500)
  }

  return jsonResponse({ squad: data.squad }, 200)
})
