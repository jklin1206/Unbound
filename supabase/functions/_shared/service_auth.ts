const SERVICE_SECRET_ENV_KEYS = [
  "SUPABASE_SERVICE_FUNCTION_SECRET",
  "SQUAD_CRON_SECRET",
]

export type JsonObjectBodyResult =
  | { ok: true; body: Record<string, unknown> }
  | { ok: false; response: Response }

function configuredSecret(): string | null {
  for (const key of SERVICE_SECRET_ENV_KEYS) {
    const value = Deno.env.get(key)?.trim()
    if (value) return value
  }
  return null
}

export async function requireJsonObjectBody(req: Request): Promise<JsonObjectBodyResult> {
  const contentType = req.headers.get("content-type") ?? ""
  if (!contentType.toLowerCase().includes("application/json")) {
    return { ok: false, response: new Response("unsupported media type", { status: 415 }) }
  }

  let body: unknown
  try {
    body = await req.json()
  } catch {
    return { ok: false, response: new Response("invalid json", { status: 400 }) }
  }

  if (!isJsonObject(body)) {
    return { ok: false, response: new Response("invalid json body", { status: 400 }) }
  }

  return { ok: true, body }
}

export async function requireEmptyJsonObjectBody(req: Request): Promise<Response | null> {
  const result = await requireJsonObjectBody(req)
  if (!result.ok) return result.response
  if (Object.keys(result.body).length > 0) {
    return new Response("unexpected body", { status: 400 })
  }
  return null
}

export function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function timingSafeEqual(a: string, b: string): boolean {
  let mismatch = a.length ^ b.length
  const length = Math.max(a.length, b.length)
  for (let i = 0; i < length; i++) {
    mismatch |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0)
  }
  return mismatch === 0
}

export function requirePost(req: Request): Response | null {
  if (req.method === "POST") return null
  return new Response("method not allowed", {
    status: 405,
    headers: { Allow: "POST" },
  })
}

export function requireServiceFunctionAuth(req: Request): Response | null {
  const expected = configuredSecret()
  if (!expected) {
    return new Response("service function secret is not configured", { status: 500 })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const bearer = authHeader.match(/^Bearer\s+(.+)$/i)?.[1]?.trim()
  const serviceHeader = req.headers.get("x-unbound-service-secret")?.trim()
  const provided = bearer || serviceHeader || ""

  if (!timingSafeEqual(provided, expected)) {
    return new Response("unauthorized", { status: 401 })
  }

  return null
}
