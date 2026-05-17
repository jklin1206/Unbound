# LLM Key Server-Side + Claude Consolidation — Design Spec

**Date:** 2026-05-17
**Branch:** `program-redesign` · UNBOUND iOS
**Type:** Security remediation + dependency consolidation
**Severity driver:** Live Anthropic + Gemini API keys are compiled into the
shipped app binary (`Secrets.claudeAPIKey`/`Secrets.geminiAPIKey`),
extractable from any `.ipa`. No users exist yet, so this is fixed *before*
exposure, not after — keys are NOT rotated (jlin decision).

## Context

`ClaudeClient.swift:164` sends `Secrets.claudeAPIKey` as `x-api-key` directly
to `api.anthropic.com`. `GeminiClient.swift:110` puts `Secrets.geminiAPIKey`
in the URL to `generativelanguage.googleapis.com`. `Secrets.swift` is correctly
gitignored (not in repo or history) but is **compiled into the binary** —
gitignore protects the repo, not the shipped app.

`ClaudeClient` is **non-streaming** (single POST → single decoded JSON
response), so a transparent request/response proxy suffices — no SSE.

Gemini is still live in **3 call sites**: `ScanComparisonService` (scan
comparison, 2 JPEGs), `CoachNotesService` (coach notes), `CoachActionsRow`
(travel-plan). jlin decision: **port all 3 to Claude, then delete Gemini
entirely** — one LLM, one proxy. `Secrets.*` is used nowhere except the two
keys, so `Secrets.swift` + template are deleted at the end.

The existing `supabase/functions/*` are all cron/service-role jobs; there is
**no precedent** for a user-invoked, JWT-verified edge function — that part is
designed fresh. The shared `JSONValue` type (used by both LLM clients) stays.

## Locked decisions

1. **One sub-project, two phases.** Phase A: port the 3 Gemini sites to Claude
   + delete Gemini. Phase B: Anthropic edge-function proxy + `ClaudeClient`
   rewire + delete `Secrets`. Each phase ends green and is independently
   shippable.
2. **Schema mapping is 1:1.** Each site's existing JSON schema
   (`JSONValue.fromJSONString(...)`) becomes the Claude forced-tool
   `input_schema` verbatim. Gemini `systemInstruction`→Claude `system`,
   `userText`→`userText`, `jpegImages`→`jpegImages`.
3. **Model mapping (jlin — Haiku split):**
   - `ScanComparisonService` → `ClaudeClient.Model.sonnet46` (vision + judgment)
   - `CoachNotesService` → `.haiku45`
   - `CoachActionsRow` travel-plan → `.haiku45`
4. **`ClaudeClient` gains an optional `temperature`.** The sites pass
   `temperature` (0.45 etc.); add an optional `temperature: Double?` to
   `RequestBody` (encoded only when non-nil) + the two structured methods so
   behavior is preserved. Anthropic Messages API supports `temperature`.
5. **The edge function verifies an authenticated, non-anon user JWT.**
   Supabase's gateway `verify_jwt` accepts the *publishable* key (which the
   app ships) — insufficient alone. The function must additionally confirm
   `supabase.auth.getUser()` returns a real user whose JWT role is
   `authenticated` (not `anon`); otherwise it's an open proxy with the same
   exposure relocated. Reject with 401 otherwise.
6. **Transparent passthrough + model allowlist.** The function forwards the
   exact Messages body the app builds, injecting `x-api-key`
   (`ANTHROPIC_API_KEY` function secret) + `anthropic-version: 2023-06-01`,
   returning Anthropic's body + status verbatim. It rejects any `model` not in
   the 3-model allowlist (cheap abuse cap on a stolen JWT). Client-side
   retry/backoff stays in `ClaudeClient` (the function does exactly one call).
7. **No key rotation** (jlin: no users, key leaves the binary now). **Not**
   streaming, **not** per-user rate limiting beyond the allowlist (deferred).

## Architecture

### Phase A — Gemini → Claude

`ClaudeClient` change (additive, behavior-preserving):
- `RequestBody` gains `let temperature: Double?` → CodingKey `temperature`,
  omitted from JSON when nil (use `encodeIfPresent`).
- `sendStructured` / `sendStructuredWithImages` gain `temperature: Double? = nil`,
  threaded into `sendStructuredInternal` → `RequestBody`.

Per-site port (each: build a `ClaudeClient.Tool` from the site's existing
schema `JSONValue`, call the matching structured method, decode the same
result type — **no change to the site's public behavior or return types**):

| Site | New call |
|---|---|
| `ScanComparisonService` | `ClaudeClient.shared.sendStructuredWithImages(<LLMType>.self, model: .sonnet46, system: Self.systemPrompt, userText: <existing>, jpegImages: [baselineJPEG, comparisonJPEG], tool: Tool(name: "scan_comparison", description: "Return the structured scan comparison", inputSchema: <existing schema JSONValue>), maxTokens: <existing>, temperature: <existing>)` |
| `CoachNotesService` | `sendStructured(CoachNoteLLM.self, model: .haiku45, system: systemPrompt, userText: <existing>, tool: Tool(name: "coach_note", description: "Return the structured coach note", inputSchema: <schema>), maxTokens: <existing>, temperature: <existing>)` |
| `CoachActionsRow` travel | `sendStructured(TravelPlanLLM.self, model: .haiku45, system: systemPrompt, userText: userPrompt, tool: Tool(name: "travel_plan", description: "Return the structured travel plan", inputSchema: <schema>), maxTokens: 1024, temperature: 0.45)` |

The `gemini` stored properties / params in `ScanComparisonService` /
`CoachNotesService` and the `GeminiClient.shared` call in `CoachActionsRow`
are removed. Then **delete**: `UNBOUND/Services/Gemini/GeminiClient.swift`,
any `UNBOUNDTests/**/Gemini*` test, `Secrets.geminiAPIKey`, and any remaining
Gemini symbol. Co-located-type grep guard before deleting the file (per
project rule). Build green; the 3 features still produce identical structured
types.

### Phase B — Anthropic edge-function proxy + rewire

**`supabase/functions/anthropic_proxy/index.ts`** (Deno, matches existing
functions' import/`serve` style):
- CORS/OPTIONS handled; only `POST` accepted.
- Read `Authorization` header. `createClient(SUPABASE_URL, SUPABASE_ANON_KEY,
  { global: { headers: { Authorization } } })`; `const { data: { user } } =
  await supabase.auth.getUser()`. If no `user` OR the JWT role is not
  `authenticated` (anon) → `401`.
- Parse JSON body; if `body.model` ∉ {`claude-sonnet-4-6`,
  `claude-opus-4-7`, `claude-haiku-4-5-20251001`} → `400`.
- `fetch("https://api.anthropic.com/v1/messages", { method:"POST", headers:{
  "x-api-key": Deno.env.get("ANTHROPIC_API_KEY"), "anthropic-version":
  "2023-06-01", "content-type":"application/json" }, body: <verbatim> })`.
- Return Anthropic's response body + status code verbatim (passthrough).
- Function secret: `ANTHROPIC_API_KEY` (set via `supabase secrets set`).

**`ClaudeClient` rewire** — introduce a tiny transport seam so it is unit
testable and the network path is swappable:
- `protocol ClaudeTransport { func send(_ body: RequestBody) async throws ->
  (data: Data, status: Int) }`.
- `EdgeFunctionTransport: ClaudeTransport` — calls
  `UnboundSupabase.client.functions.invoke("anthropic_proxy",
  options: FunctionInvokeOptions(body: body))` (the supabase-swift SDK
  auto-attaches the user session JWT + `apikey`); maps the SDK
  result/`FunctionsError` into `(data, status)` so the existing
  `ClaudeError.apiError(status:message:)` path and `sendWithRetry`
  (4xx-no-retry except 429, exponential backoff) are unchanged.
- `ClaudeClient.shared` uses `EdgeFunctionTransport` by default; `init(transport:)`
  allows a `MockClaudeTransport` in tests.
- `send(body:)` becomes `transport.send`; the `x-api-key` / `anthropic-version`
  / `Secrets` lines are deleted; `RequestBody`/`ResponseBody`/`ContentBlock`/
  retry/structured-tool logic stay **byte-identical**.

**Cleanup:** delete `UNBOUND/Services/Secrets/Secrets.swift`,
`Secrets.swift.template`, and the now-dead `Secrets`-related `.gitignore`
lines (confirm no other `Secrets.*` referencer first — grep showed none).

### Reused / unchanged
`JSONValue`, all `ClaudeClient` request/response model types, the structured-
tool decode path, `sendWithRetry`/backoff, the existing edge-function code
style, `UnboundSupabase.client`. No DB/schema/RLS change. No UI change.

## Testing / verification

- **Unit (new):** `ClaudeClientTests` with `MockClaudeTransport` — asserts
  `sendStructured`/`sendStructuredWithImages` build the correct `RequestBody`
  (model, tool/tool_choice, temperature encoded only when set, images block
  order), decode tool-use output into the target type, and that
  `sendWithRetry` does NOT retry a 400 but DOES retry 429/5xx.
- **Parity:** `ScanComparisonService`/`CoachNotesService`/`CoachActionsRow`
  still return the same `LLMType`/`CoachNoteLLM`/`TravelPlanLLM` shapes; no
  call-site signature change visible to their callers.
- `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test`
  → green except the known pre-existing `FriendChallengeServiceTests`/
  `SquadMissionServiceTests` RLS flap; zero NEW failures. SourceKit
  cross-file noise ignored per project rule.
- `grep -rn "Gemini\|Secrets\.\|api.anthropic.com\|x-api-key" UNBOUND --include="*.swift"`
  → zero matches after Phase B (no Gemini symbol, no `Secrets.` reference, no
  direct Anthropic host, no embedded key).
- **The one human step (gate before on-device):** jlin runs
  `supabase functions deploy anthropic_proxy` and
  `supabase secrets set ANTHROPIC_API_KEY=<key>`. The plan flags this
  explicitly; on-device verification cannot pass until it's done.
- **On-device (jlin), signed in:** scan comparison, a coach note, and a
  travel-plan all still work end-to-end through the proxy.
- **Security assertions (jlin, post-deploy):** a call to the function URL
  with only the publishable/anon key (no user session) returns **401**; a
  call with an unsupported `model` returns **400**; a normal signed-in app
  call succeeds. These prove the proxy is not an open relay.

## Out of scope
Streaming (client is non-streaming), per-user rate limiting beyond the model
allowlist, key rotation, migrating the cron/service-role functions, any
product/feature change to scan/coach/travel beyond swapping the LLM backend,
RLS/schema changes.

## Execution
Subagent-driven (fresh subagent per task, spec-then-quality review at the
seam), Sonnet minimum, scoped pathspec-limited commits (`git commit --
<paths>`, never `git add` + bare commit — per project rule), co-authored
trailer. Co-located-type grep guard before deleting `GeminiClient.swift` /
`Secrets.swift`. On-device + security sign-off by jlin after the manual
deploy step.
