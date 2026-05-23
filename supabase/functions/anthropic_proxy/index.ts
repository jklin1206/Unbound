// supabase/functions/anthropic_proxy/index.ts
// Transparent Anthropic Messages proxy. The app calls this with its
// Supabase user session JWT (supabase-swift functions.invoke attaches it).
// Verifies an AUTHENTICATED (non-anon) user, injects the server-side
// ANTHROPIC_API_KEY secret, allowlists the model, and passes the request
// through to api.anthropic.com verbatim. The key never ships in the app.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const ALLOWED_MODELS = new Set([
  "claude-sonnet-4-6",
  "claude-opus-4-7",
  "claude-haiku-4-5-20251001",
])

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    })
  }
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: { user }, error: authError } = await supabase.auth.getUser()
  // getUser resolves the forwarded JWT. An anon/missing session has no user.
  if (authError || !user || user.role !== "authenticated") {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    })
  }

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), {
      status: 400,
      headers: { "content-type": "application/json" },
    })
  }

  if (typeof body.model !== "string" || !ALLOWED_MODELS.has(body.model)) {
    return new Response(JSON.stringify({ error: "model not allowed" }), {
      status: 400,
      headers: { "content-type": "application/json" },
    })
  }

  const anthropicResp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  })

  // Pass Anthropic's body + status through verbatim.
  const respText = await anthropicResp.text()
  return new Response(respText, {
    status: anthropicResp.status,
    headers: { "content-type": "application/json" },
  })
})
