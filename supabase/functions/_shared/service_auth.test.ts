import {
  requireEmptyJsonObjectBody,
  requireJsonObjectBody,
  requirePost,
  requireServiceFunctionAuth,
} from "./service_auth.ts"

const SECRET = "test-service-secret"
const SECRET_ENVS = ["SUPABASE_SERVICE_FUNCTION_SECRET", "SQUAD_CRON_SECRET"]

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message)
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`)
  }
}

async function withSecret(fn: () => Promise<void>) {
  const previous = new Map(SECRET_ENVS.map((key) => [key, Deno.env.get(key)]))
  Deno.env.set(SECRET_ENVS[0], SECRET)
  Deno.env.delete(SECRET_ENVS[1])
  try {
    await fn()
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) {
        Deno.env.delete(key)
      } else {
        Deno.env.set(key, value)
      }
    }
  }
}

function signedRequest(init: RequestInit = {}): Request {
  return new Request("https://example.test/functions/v1/job", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      Authorization: `Bearer ${SECRET}`,
      ...(init.headers ?? {}),
    },
    body: "{}",
    ...init,
  })
}

Deno.test("requirePost rejects non-POST requests", () => {
  const error = requirePost(signedRequest({ method: "GET", body: undefined }))
  assert(error !== null, "expected GET to fail")
  assertEquals(error?.status, 405)
})

Deno.test("requireServiceFunctionAuth accepts the configured bearer secret", async () => {
  await withSecret(async () => {
    assertEquals(requireServiceFunctionAuth(signedRequest()), null)
  })
})

Deno.test("requireServiceFunctionAuth rejects missing and wrong secrets", async () => {
  await withSecret(async () => {
    const missing = requireServiceFunctionAuth(
      signedRequest({ headers: { "content-type": "application/json" } }),
    )
    assert(missing !== null, "expected missing auth to fail")
    assertEquals(missing?.status, 401)

    const wrong = requireServiceFunctionAuth(
      signedRequest({ headers: { "content-type": "application/json", Authorization: "Bearer wrong" } }),
    )
    assert(wrong !== null, "expected wrong auth to fail")
    assertEquals(wrong?.status, 401)
  })
})

Deno.test("requireServiceFunctionAuth fails closed without an env secret", () => {
  const previous = new Map(SECRET_ENVS.map((key) => [key, Deno.env.get(key)]))
  for (const key of SECRET_ENVS) {
    Deno.env.delete(key)
  }
  try {
    const error = requireServiceFunctionAuth(signedRequest())
    assert(error !== null, "expected missing env secret to fail")
    assertEquals(error?.status, 500)
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) {
        Deno.env.delete(key)
      } else {
        Deno.env.set(key, value)
      }
    }
  }
})

Deno.test("requireJsonObjectBody validates content type and object shape", async () => {
  const missingType = await requireJsonObjectBody(
    signedRequest({ headers: { Authorization: `Bearer ${SECRET}` } }),
  )
  assert(!missingType.ok, "expected missing content type to fail")
  if (!missingType.ok) assertEquals(missingType.response.status, 415)

  const badShape = await requireJsonObjectBody(signedRequest({ body: "[]" }))
  assert(!badShape.ok, "expected array body to fail")
  if (!badShape.ok) assertEquals(badShape.response.status, 400)
})

Deno.test("requireEmptyJsonObjectBody accepts only empty objects", async () => {
  assertEquals(await requireEmptyJsonObjectBody(signedRequest()), null)

  const error = await requireEmptyJsonObjectBody(signedRequest({ body: "{\"job\":\"daily\"}" }))
  assert(error !== null, "expected non-empty cron body to fail")
  assertEquals(error?.status, 400)
})
