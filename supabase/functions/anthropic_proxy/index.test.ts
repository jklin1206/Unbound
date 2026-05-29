// Proof A (server denies spoof): the premium anthropic_proxy endpoint returns
// 403 when the server-owned is_pro flag is false, regardless of what the client
// asserts. With is_pro=true it forwards and succeeds.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { handle, type ProxyDeps } from "./index.ts"

// An authenticated caller (valid JWT). The "spoof" is implicit: a real client
// would only reach this endpoint because its LOCAL entitlement said it was
// premium. The server ignores that and consults isPro().
const authedUser = { id: "user-123", role: "authenticated" }

function deps(overrides: Partial<ProxyDeps> = {}): ProxyDeps {
  return {
    authenticate: () => Promise.resolve(authedUser),
    isPro: () => Promise.resolve(true),
    forwardToAnthropic: () => Promise.resolve({ text: '{"ok":true}', status: 200 }),
    ...overrides,
  }
}

function premiumRequest() {
  return new Request("https://edge/anthropic_proxy", {
    method: "POST",
    headers: { Authorization: "Bearer fake-jwt", "content-type": "application/json" },
    body: JSON.stringify({ model: "claude-haiku-4-5-20251001", messages: [] }),
  })
}

Deno.test("Proof A: server is_pro=false => 403 even with valid auth (spoofed local entitlement)", async () => {
  let forwarded = false
  const res = await handle(
    premiumRequest(),
    deps({
      isPro: () => Promise.resolve(false),
      forwardToAnthropic: () => {
        forwarded = true
        return Promise.resolve({ text: "{}", status: 200 })
      },
    }),
  )
  assertEquals(res.status, 403)
  assertEquals((await res.json()).error, "premium_required")
  // Premium work must NOT run when denied.
  assertEquals(forwarded, false)
})

Deno.test("Proof A: server is_pro=true => forwards and succeeds", async () => {
  const res = await handle(premiumRequest(), deps({ isPro: () => Promise.resolve(true) }))
  assertEquals(res.status, 200)
  assertEquals((await res.json()).ok, true)
})

Deno.test("unauthenticated caller => 401 (existing auth not weakened)", async () => {
  const res = await handle(premiumRequest(), deps({ authenticate: () => Promise.resolve(null) }))
  assertEquals(res.status, 401)
})

Deno.test("anon role => 401", async () => {
  const res = await handle(
    premiumRequest(),
    deps({ authenticate: () => Promise.resolve({ id: "x", role: "anon" }) }),
  )
  assertEquals(res.status, 401)
})

Deno.test("disallowed model => 400 (only reached after pro check passes)", async () => {
  const req = new Request("https://edge/anthropic_proxy", {
    method: "POST",
    headers: { Authorization: "Bearer fake-jwt", "content-type": "application/json" },
    body: JSON.stringify({ model: "gpt-4", messages: [] }),
  })
  const res = await handle(req, deps())
  assertEquals(res.status, 400)
})
