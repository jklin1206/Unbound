import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const jsonHeaders = {
  "content-type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: jsonHeaders })
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: jsonHeaders,
    })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  )
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  const { data: { user }, error: userError } = await userClient.auth.getUser()
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: jsonHeaders,
    })
  }

  const { error: profileError } = await adminClient
    .from("users")
    .delete()
    .eq("id", user.id)

  if (profileError) {
    return new Response(JSON.stringify({ error: "profile_delete_failed" }), {
      status: 500,
      headers: jsonHeaders,
    })
  }

  const { error: authError } = await adminClient.auth.admin.deleteUser(user.id, false)
  if (authError) {
    return new Response(JSON.stringify({ error: "auth_delete_failed" }), {
      status: 500,
      headers: jsonHeaders,
    })
  }

  return new Response(JSON.stringify({ deleted: true }), {
    status: 200,
    headers: jsonHeaders,
  })
})
