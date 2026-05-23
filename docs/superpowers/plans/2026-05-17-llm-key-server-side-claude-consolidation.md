# LLM Key Server-Side + Claude Consolidation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the live Anthropic + Gemini API keys from the iOS binary by consolidating all LLM use onto Claude and proxying Claude through a JWT-gated Supabase Edge Function.

**Architecture:** Phase A ports the 3 Gemini call sites to the existing `ClaudeClient` (forced-tool structured output; each site's existing JSON schema reused verbatim as the tool `input_schema`) and deletes Gemini. Phase B introduces a transparent `anthropic_proxy` Edge Function and a `ClaudeTransport` seam in `ClaudeClient` that routes through it, then deletes `Secrets`. Each phase ends green.

**Tech Stack:** Swift 5.9 / SwiftUI / XCTest; xcodegen (run `xcodegen generate` before `xcodebuild` after adding a file); Supabase Edge Functions (Deno) via supabase-swift `functions.invoke`. Authoritative test: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test`.

**Commit discipline (project rule):** NEVER `git add <files>` then a bare `git commit` — that commits the whole index and has twice swept unrelated staged work into a commit. For every commit: (1) `git diff --cached --name-only` must be empty; (2) `git add <explicit file(s)>`; (3) `git commit -m "<msg>" -- <same explicit paths>` (pathspec-limited). Sonnet-minimum subagents. Co-authored trailer.

---

## File Structure

| File | Change | Task |
|---|---|---|
| `UNBOUND/Services/Claude/ClaudeClient.swift` | + optional `temperature`; later + `ClaudeTransport` seam, drop `Secrets`/host | A1, B2 |
| `UNBOUND/Services/Scan/ScanComparisonService.swift` | Gemini→Claude (Sonnet, images) | A2 |
| `UNBOUND/Services/Coach/CoachNotesService.swift` | Gemini→Claude (Haiku) | A3 |
| `UNBOUND/Views/Program/CoachActionsRow.swift` | Gemini→Claude (Haiku) | A4 |
| `UNBOUND/Services/Gemini/GeminiClient.swift` | **deleted** | A5 |
| `UNBOUND/Services/Secrets/Secrets.swift` (untracked) + `Secrets.swift.template` | **deleted** | B3 |
| `.gitignore` | drop dead Secrets lines | B3 |
| `supabase/functions/anthropic_proxy/index.ts` | **new** Deno proxy | B1 |
| `UNBOUNDTests/Services/Claude/ClaudeClientTests.swift` | **new** mock-transport unit tests | A1, B2 |

`JSONValue`, all `ClaudeClient` model types, `sendWithRetry`/backoff, structured-tool decode, `UnboundSupabase.client` — unchanged. No DB/RLS/UI change.

---

# PHASE A — Port to Claude, delete Gemini

## Task A1: Add optional `temperature` to ClaudeClient

**Files:**
- Modify: `UNBOUND/Services/Claude/ClaudeClient.swift`
- Test: `UNBOUNDTests/Services/Claude/ClaudeClientTests.swift` (new)

Swift's synthesized `Encodable` uses `encodeIfPresent` for `Optional` properties, so a nil `temperature` is omitted from JSON automatically — no custom encoder needed.

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Services/Claude/ClaudeClientTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class ClaudeClientTests: XCTestCase {

    private func encodedKeys(_ body: ClaudeClient.RequestBody) throws -> [String: Any] {
        let data = try JSONEncoder().encode(body)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func testTemperatureOmittedWhenNil() throws {
        let body = ClaudeClient.RequestBody(
            model: "claude-haiku-4-5-20251001",
            maxTokens: 128,
            system: "sys",
            messages: [ClaudeClient.Message(role: "user", content: [.text("hi")])],
            tools: nil,
            toolChoice: nil,
            temperature: nil
        )
        let json = try encodedKeys(body)
        XCTAssertNil(json["temperature"], "nil temperature must be omitted")
        XCTAssertEqual(json["max_tokens"] as? Int, 128)
    }

    func testTemperatureEncodedWhenSet() throws {
        let body = ClaudeClient.RequestBody(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            system: "sys",
            messages: [ClaudeClient.Message(role: "user", content: [.text("hi")])],
            tools: nil,
            toolChoice: nil,
            temperature: 0.45
        )
        let json = try encodedKeys(body)
        XCTAssertEqual(json["temperature"] as? Double, 0.45)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ClaudeClientTests 2>&1 | tail -15`
Expected: FAIL — `RequestBody` init has no `temperature:` argument (compile error).

- [ ] **Step 3: Implement**

In `UNBOUND/Services/Claude/ClaudeClient.swift`, in `struct RequestBody`:
- add `let temperature: Double?` as the last stored property
- add `case temperature` to its `CodingKeys`

Current:
```swift
    struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]
        let tools: [Tool]?
        let toolChoice: ToolChoice?

        enum CodingKeys: String, CodingKey {
            case model, system, messages, tools
            case maxTokens = "max_tokens"
            case toolChoice = "tool_choice"
        }
    }
```
Replace with:
```swift
    struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]
        let tools: [Tool]?
        let toolChoice: ToolChoice?
        let temperature: Double?

        enum CodingKeys: String, CodingKey {
            case model, system, messages, tools, temperature
            case maxTokens = "max_tokens"
            case toolChoice = "tool_choice"
        }
    }
```

Thread `temperature` through every `RequestBody(...)` construction and the public methods. In `sendText`, pass `temperature: nil`:
```swift
        let body = RequestBody(
            model: model.rawValue,
            maxTokens: maxTokens,
            system: system,
            messages: [Message(role: "user", content: [.text(userText)])],
            tools: nil,
            toolChoice: nil,
            temperature: nil
        )
```
Add `temperature: Double? = nil` to `sendStructured` and `sendStructuredWithImages` signatures and pass it into `sendStructuredInternal`. Change `sendStructuredInternal`:
```swift
    private func sendStructuredInternal<T: Decodable>(
        model: Model,
        system: String,
        userBlocks: [ContentBlock],
        tool: Tool,
        maxTokens: Int,
        temperature: Double?
    ) async throws -> T {
        let body = RequestBody(
            model: model.rawValue,
            maxTokens: maxTokens,
            system: system,
            messages: [Message(role: "user", content: userBlocks)],
            tools: [tool],
            toolChoice: ToolChoice(type: "tool", name: tool.name),
            temperature: temperature
        )
        // ... rest unchanged
```
`sendStructured`:
```swift
    func sendStructured<T: Decodable>(
        _ type: T.Type = T.self,
        model: Model = .sonnet46,
        system: String,
        userText: String,
        tool: Tool,
        maxTokens: Int = 4096,
        temperature: Double? = nil
    ) async throws -> T {
        try await sendStructuredInternal(
            model: model, system: system,
            userBlocks: [.text(userText)],
            tool: tool, maxTokens: maxTokens, temperature: temperature
        )
    }
```
`sendStructuredWithImages` (same addition; pass `temperature` into `sendStructuredInternal`):
```swift
    func sendStructuredWithImages<T: Decodable>(
        _ type: T.Type = T.self,
        model: Model = .sonnet46,
        system: String,
        userText: String,
        jpegImages: [Data],
        tool: Tool,
        maxTokens: Int = 4096,
        temperature: Double? = nil
    ) async throws -> T {
        var blocks: [ContentBlock] = jpegImages.map {
            .image(base64: $0.base64EncodedString(), mediaType: "image/jpeg")
        }
        blocks.append(.text(userText))
        return try await sendStructuredInternal(
            model: model, system: system,
            userBlocks: blocks, tool: tool,
            maxTokens: maxTokens, temperature: temperature
        )
    }
```

- [ ] **Step 4: Run to verify it passes**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ClaudeClientTests 2>&1 | tail -15`
Expected: PASS (`Executed 2 tests`). SourceKit cross-file/XCTest "Cannot find"/"No such module" diagnostics are project noise — ignore; the `xcodebuild` line is authoritative.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only
# must print nothing; if it lists files, STOP and report.
git add UNBOUND/Services/Claude/ClaudeClient.swift UNBOUNDTests/Services/Claude/ClaudeClientTests.swift project.yml
git commit -m "feat(claude): optional temperature param (Anthropic Messages)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- UNBOUND/Services/Claude/ClaudeClient.swift UNBOUNDTests/Services/Claude/ClaudeClientTests.swift project.yml
```
Include `project.yml` in BOTH the `add` and the `commit -- ` pathspec ONLY if `git status` shows xcodegen modified it; else drop it from both.

---

## Task A2: Port ScanComparisonService → Claude (Sonnet, images)

**Files:**
- Modify: `UNBOUND/Services/Scan/ScanComparisonService.swift`

No unit test (this service has none; parity is build-green + identical return type `ScanDeltaReport?` + jlin on-device in B5). This is a behavior-preserving backend swap.

- [ ] **Step 1: Remove the Gemini property**

In `ScanComparisonService.swift` delete line:
```swift
    private let gemini = GeminiClient.shared
```

- [ ] **Step 2: Replace the Gemini call with Claude forced-tool**

Replace this exact block:
```swift
        let llm: ScanComparisonLLMOutput
        do {
            llm = try await gemini.generateStructured(
                ScanComparisonLLMOutput.self,
                systemInstruction: Self.systemPrompt,
                userText: Self.userPrompt,
                jpegImages: [baselineJPEG, comparisonJPEG],
                responseSchema: schema,
                maxOutputTokens: 1024,
                temperature: 0.3
            )
        } catch {
            logger.log("ScanComparison: Gemini failed: \(error)", level: .warning,
                       context: ["userId": userId])
            return nil
        }
```
with:
```swift
        let llm: ScanComparisonLLMOutput
        do {
            llm = try await ClaudeClient.shared.sendStructuredWithImages(
                ScanComparisonLLMOutput.self,
                model: .sonnet46,
                system: Self.systemPrompt,
                userText: Self.userPrompt,
                jpegImages: [baselineJPEG, comparisonJPEG],
                tool: ClaudeClient.Tool(
                    name: "scan_comparison",
                    description: "Return the structured scan comparison delta.",
                    inputSchema: schema
                ),
                maxTokens: 1024,
                temperature: 0.3
            )
        } catch {
            logger.log("ScanComparison: Claude failed: \(error)", level: .warning,
                       context: ["userId": userId])
            return nil
        }
```
`schema` is the existing `JSONValue` from `JSONValue.fromJSONString(Self.responseSchemaJSON)` directly above — reuse it as-is; do NOT retype the schema string.

- [ ] **Step 3: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only   # must be empty
git add UNBOUND/Services/Scan/ScanComparisonService.swift
git commit -m "refactor(scan): ScanComparison uses Claude (Sonnet) not Gemini

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- UNBOUND/Services/Scan/ScanComparisonService.swift
```

---

## Task A3: Port CoachNotesService → Claude (Haiku)

**Files:**
- Modify: `UNBOUND/Services/Coach/CoachNotesService.swift`

- [ ] **Step 1: Remove the Gemini property + DI param**

In `CoachNotesService.swift`:
- delete the stored property line `private let gemini: GeminiClient`
- delete the init parameter line `gemini: GeminiClient = GeminiClient.shared,`
- delete the assignment line `self.gemini = gemini`

(Leave the other DI params/assignments — `database`, `user`, `workoutLog`, `sessionXP` — untouched.)

- [ ] **Step 2: Replace the Gemini call with Claude forced-tool**

Replace this exact block:
```swift
            let schema = try JSONValue.fromJSONString(schemaJSON)
            let out: CoachNoteLLM = try await gemini.generateStructured(
                CoachNoteLLM.self,
                systemInstruction: systemPrompt,
                userText: userPrompt,
                jpegImages: [],
                responseSchema: schema,
                maxOutputTokens: 128,
                temperature: 0.55
            )
```
with:
```swift
            let schema = try JSONValue.fromJSONString(schemaJSON)
            let out: CoachNoteLLM = try await ClaudeClient.shared.sendStructured(
                CoachNoteLLM.self,
                model: .haiku45,
                system: systemPrompt,
                userText: userPrompt,
                tool: ClaudeClient.Tool(
                    name: "coach_note",
                    description: "Return today's one-sentence coach note.",
                    inputSchema: schema
                ),
                maxTokens: 128,
                temperature: 0.55
            )
```

- [ ] **Step 3: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`. (If another file constructs `CoachNotesService(gemini:)` explicitly, grep `CoachNotesService(` and remove the now-deleted `gemini:` argument there too — report if found.)

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only   # empty
git add UNBOUND/Services/Coach/CoachNotesService.swift
git commit -m "refactor(coach): CoachNotes uses Claude (Haiku) not Gemini

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- UNBOUND/Services/Coach/CoachNotesService.swift
```

---

## Task A4: Port CoachActionsRow travel-plan → Claude (Haiku)

**Files:**
- Modify: `UNBOUND/Views/Program/CoachActionsRow.swift`

- [ ] **Step 1: Replace the Gemini call with Claude forced-tool**

Replace this exact block:
```swift
            let schema = try JSONValue.fromJSONString(schemaJSON)
            let result: TravelPlanLLM = try await GeminiClient.shared.generateStructured(
                TravelPlanLLM.self,
                systemInstruction: systemPrompt,
                userText: userPrompt,
                jpegImages: [],
                responseSchema: schema,
                maxOutputTokens: 1024,
                temperature: 0.45
            )
```
with:
```swift
            let schema = try JSONValue.fromJSONString(schemaJSON)
            let result: TravelPlanLLM = try await ClaudeClient.shared.sendStructured(
                TravelPlanLLM.self,
                model: .haiku45,
                system: systemPrompt,
                userText: userPrompt,
                tool: ClaudeClient.Tool(
                    name: "travel_plan",
                    description: "Return the structured equipment-constrained travel plan.",
                    inputSchema: schema
                ),
                maxTokens: 1024,
                temperature: 0.45
            )
```

- [ ] **Step 2: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only   # empty
git add UNBOUND/Views/Program/CoachActionsRow.swift
git commit -m "refactor(coach): travel-plan uses Claude (Haiku) not Gemini

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- UNBOUND/Views/Program/CoachActionsRow.swift
```

---

## Task A5: Delete Gemini entirely

**Files:**
- Delete: `UNBOUND/Services/Gemini/GeminiClient.swift`
- Modify: `UNBOUND/Services/Secrets/Secrets.swift` (untracked local file) + `UNBOUND/Services/Secrets/Secrets.swift.template`

- [ ] **Step 1: Co-located-type grep guard**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
grep -n "^enum \|^struct \|^final class \|^class \|^protocol " UNBOUND/Services/Gemini/GeminiClient.swift
grep -rn "GeminiClient\|geminiAPIKey\|\.flash25\|\.pro25" UNBOUND --include="*.swift" | grep -v "UNBOUND/Services/Gemini/GeminiClient.swift"
```
Expected: the first prints only `final class GeminiClient` + `extension GeminiClient` (no co-located unrelated types — safe whole-file delete). The second prints ONLY `Secrets.geminiAPIKey` lines (`Secrets.swift`/`Secrets.swift.template`) — i.e. A2–A4 removed every call site. If any OTHER Swift file still references Gemini, STOP and report (a port was missed).

- [ ] **Step 2: Delete the client + the Gemini key**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git rm UNBOUND/Services/Gemini/GeminiClient.swift
```
In `UNBOUND/Services/Secrets/Secrets.swift` (untracked — edit in place) delete the line:
```swift
    static let geminiAPIKey = "AIzaSy..."
```
In `UNBOUND/Services/Secrets/Secrets.swift.template` delete the line:
```swift
    static let geminiAPIKey = "REPLACE_ME"
```
(Leave `claudeAPIKey` in both for now — removed in B3 after the proxy lands.)

- [ ] **Step 3: Regenerate + build + full test (Phase A green gate)**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **` (or build succeeded) with the ONLY failure being the known pre-existing `FriendChallengeServiceTests.testCreateChallengeThrowsWhenBackendUnavailable` / `SquadMissionServiceTests` RLS flap (PostgrestError 42501). `ClaudeClientTests` passes. Zero NEW failures. Capture the exact `Executed N tests, with M failures` line + failing test names.

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only
# git rm already staged GeminiClient.swift deletion + the template (tracked).
# Secrets.swift is untracked/gitignored — it will NOT appear and must NOT be added.
# Confirm staged set is exactly: GeminiClient.swift (deleted), Secrets.swift.template, maybe project.yml
git add UNBOUND/Services/Secrets/Secrets.swift.template project.yml
git commit -m "chore(gemini): delete GeminiClient + Gemini key — Claude is the only LLM

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- UNBOUND/Services/Gemini/GeminiClient.swift UNBOUND/Services/Secrets/Secrets.swift.template project.yml
```
Drop `project.yml` from add+pathspec if `git status` shows it unmodified. `Secrets.swift` (real, gitignored) is intentionally NOT committed — its `geminiAPIKey` line was edited only so the local build is clean.

---

# PHASE B — Edge-function proxy + rewire + delete Secrets

## Task B1: anthropic_proxy Edge Function

**Files:**
- Create: `supabase/functions/anthropic_proxy/index.ts`

No automated test (matches the repo's existing untested-function pattern; verified by jlin's curl checks in B5). Match the import/`serve` style of `supabase/functions/evaluate_squad_streak/index.ts`.

- [ ] **Step 1: Write the function**

`supabase/functions/anthropic_proxy/index.ts`:

```typescript
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
```

- [ ] **Step 2: Syntax sanity (no deploy here — deploy is the human gate B5)**

If `deno` is available locally: `deno check supabase/functions/anthropic_proxy/index.ts` → no errors. If `deno` is not installed, skip (the repo's other functions have no local check step); do NOT attempt to install Deno.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only   # empty
git add supabase/functions/anthropic_proxy/index.ts
git commit -m "feat(edge): anthropic_proxy — JWT-gated, model-allowlisted passthrough

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- supabase/functions/anthropic_proxy/index.ts
```

---

## Task B2: ClaudeClient transport seam → functions.invoke

**Files:**
- Modify: `UNBOUND/Services/Claude/ClaudeClient.swift`
- Test: `UNBOUNDTests/Services/Claude/ClaudeClientTests.swift` (extend)

Goal: route the single network call through `anthropic_proxy` via supabase-swift, behind a `ClaudeTransport` protocol so it is unit-testable. `RequestBody`/`ResponseBody`/`ContentBlock`/`sendWithRetry`/structured-tool decode stay byte-identical.

- [ ] **Step 1: Write the failing tests (extend ClaudeClientTests)**

Append to `UNBOUNDTests/Services/Claude/ClaudeClientTests.swift` (inside the class):

```swift
    // A canned transport so no network is touched.
    final class MockClaudeTransport: ClaudeTransport, @unchecked Sendable {
        var responses: [(data: Data, status: Int)]
        private(set) var sentBodies: [ClaudeClient.RequestBody] = []
        init(_ responses: [(data: Data, status: Int)]) { self.responses = responses }
        func send(_ body: ClaudeClient.RequestBody) async throws -> (data: Data, status: Int) {
            sentBodies.append(body)
            return responses.isEmpty
                ? (Data("{}".utf8), 500)
                : responses.removeFirst()
        }
    }

    private func toolUseJSON(_ obj: String) -> Data {
        Data("""
        {"id":"m","model":"claude-haiku-4-5-20251001","stop_reason":"tool_use",
         "content":[{"type":"tool_use","id":"t","name":"echo","input":\(obj)}]}
        """.utf8)
    }

    struct Echo: Decodable, Equatable { let v: Int }

    func testStructuredDecodesToolUseAndSendsModelAndToolChoice() async throws {
        let mock = MockClaudeTransport([(toolUseJSON(#"{"v":7}"#), 200)])
        let client = ClaudeClient(transport: mock)
        let tool = ClaudeClient.Tool(name: "echo", description: "d",
                                     inputSchema: .object(["v": .string("integer")]))
        let out: Echo = try await client.sendStructured(
            Echo.self, model: .haiku45, system: "s", userText: "u",
            tool: tool, maxTokens: 64, temperature: 0.5)
        XCTAssertEqual(out, Echo(v: 7))
        let body = try XCTUnwrap(mock.sentBodies.first)
        XCTAssertEqual(body.model, "claude-haiku-4-5-20251001")
        XCTAssertEqual(body.toolChoice?.name, "echo")
        XCTAssertEqual(body.temperature, 0.5)
    }

    func testDoesNotRetryOn400ButRetriesOn429() async throws {
        let bad = Data(#"{"error":"bad"}"#.utf8)
        let mock400 = MockClaudeTransport([(bad, 400), (toolUseJSON(#"{"v":1}"#), 200)])
        let c1 = ClaudeClient(transport: mock400)
        let tool = ClaudeClient.Tool(name: "echo", description: "d",
                                     inputSchema: .object([:]))
        do {
            let _: Echo = try await c1.sendStructured(Echo.self, system: "s",
                                                      userText: "u", tool: tool)
            XCTFail("400 must not be retried/succeed")
        } catch {}
        XCTAssertEqual(mock400.sentBodies.count, 1, "400 must NOT retry")

        let mock429 = MockClaudeTransport([(bad, 429), (toolUseJSON(#"{"v":2}"#), 200)])
        let c2 = ClaudeClient(transport: mock429)
        let ok: Echo = try await c2.sendStructured(Echo.self, system: "s",
                                                   userText: "u", tool: tool)
        XCTAssertEqual(ok, Echo(v: 2))
        XCTAssertEqual(mock429.sentBodies.count, 2, "429 must retry once then succeed")
    }
```

(`JSONValue` case names — `.object`, `.string` — are this codebase's existing `JSONValue` API; if the actual case labels differ, the implementer adjusts the two `inputSchema:` literals to valid `JSONValue` per the real enum. The behavior under test does not depend on the schema content.)

- [ ] **Step 2: Run to verify it fails**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ClaudeClientTests 2>&1 | tail -15`
Expected: FAIL — no `ClaudeTransport`, no `ClaudeClient(transport:)`.

- [ ] **Step 3: Implement the seam in `ClaudeClient.swift`**

Add at file scope (top, after imports):
```swift
protocol ClaudeTransport: Sendable {
    func send(_ body: ClaudeClient.RequestBody) async throws -> (data: Data, status: Int)
}
```

Add the production transport at the bottom of `ClaudeClient.swift`:
```swift
// Routes the one Anthropic call through the anthropic_proxy Edge Function.
// supabase-swift attaches the user session JWT + apikey automatically.
struct EdgeFunctionTransport: ClaudeTransport {
    func send(_ body: ClaudeClient.RequestBody) async throws -> (data: Data, status: Int) {
        do {
            return try await UnboundSupabase.client.functions.invoke(
                "anthropic_proxy",
                options: FunctionInvokeOptions(body: body)
            ) { data, response in (data, response.statusCode) }
        } catch let FunctionsError.httpError(code, data) {
            // Surface as a normal HTTP result so ClaudeClient's existing
            // status handling + sendWithRetry policy applies (e.g. 429).
            return (data, code)
        }
    }
}
```
Note: `FunctionInvokeOptions(body:)` accepts an `Encodable`; `RequestBody` is `Encodable`. The third trailing closure form `invoke(_:options:) { data, response in T }` returns the closure's value and gives the raw `Data` + `HTTPURLResponse`. **Adapt to the exact supabase-swift version vendored in this project** — the invariant contract is: send the `Encodable` `RequestBody`, get back raw response `Data` + the HTTP status `Int`. Add `import Functions` or `import Supabase` if `FunctionInvokeOptions`/`FunctionsError` are not already in scope (check the SDK module the project links).

Replace `ClaudeClient`'s stored config + `init` + `send`:

Current:
```swift
    private let session: URLSession
    private let logger = LoggingService.shared
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"
    private let maxRetries = 3

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }
```
Replace with:
```swift
    private let logger = LoggingService.shared
    private let maxRetries = 3
    private let transport: ClaudeTransport

    init(transport: ClaudeTransport = EdgeFunctionTransport()) {
        self.transport = transport
    }
```
(`static let shared = ClaudeClient()` stays — now uses the default `EdgeFunctionTransport`.)

Current `send`:
```swift
    private func send(body: RequestBody) async throws -> ResponseBody {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(Secrets.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeError.apiError(status: http.statusCode, message: message)
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
```
Replace with:
```swift
    private func send(body: RequestBody) async throws -> ResponseBody {
        let (data, status) = try await transport.send(body)
        guard (200...299).contains(status) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeError.apiError(status: status, message: message)
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
```
Delete the `import Foundation`-adjacent comment line `// ... keys will move server-side before App Store submission.` (now done). `sendWithRetry`, all model types, structured logic — unchanged. No `Secrets`, no `endpoint`, no `URLSession`, no `x-api-key` remain in this file.

- [ ] **Step 4: Run to verify it passes**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ClaudeClientTests 2>&1 | tail -15`
Expected: PASS (`Executed 4 tests`). If `FunctionInvokeOptions`/`FunctionsError`/the `invoke` closure signature mismatch the vendored supabase-swift, fix `EdgeFunctionTransport` to the SDK's real API preserving the `(Data, Int)` contract — the mock-based tests don't touch the SDK and must stay green.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only   # empty
git add UNBOUND/Services/Claude/ClaudeClient.swift UNBOUNDTests/Services/Claude/ClaudeClientTests.swift
git commit -m "feat(claude): route via anthropic_proxy through ClaudeTransport seam

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- UNBOUND/Services/Claude/ClaudeClient.swift UNBOUNDTests/Services/Claude/ClaudeClientTests.swift
```

---

## Task B3: Delete Secrets

**Files:**
- Delete: `UNBOUND/Services/Secrets/Secrets.swift` (untracked) + `UNBOUND/Services/Secrets/Secrets.swift.template` (tracked)
- Modify: `.gitignore`

- [ ] **Step 1: Grep guard — nothing references Secrets anymore**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
grep -rn "Secrets\." UNBOUND --include="*.swift" | grep -v "Services/Secrets/"
grep -n "^enum \|^struct \|^class " UNBOUND/Services/Secrets/Secrets.swift
```
Expected: first prints NOTHING (no `Secrets.` referencer left after B2 removed `Secrets.claudeAPIKey`). Second prints only `enum Secrets`. If anything still references `Secrets.`, STOP and report.

- [ ] **Step 2: Delete the files + clean .gitignore**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
rm -f UNBOUND/Services/Secrets/Secrets.swift          # untracked local file
git rm UNBOUND/Services/Secrets/Secrets.swift.template
```
In `.gitignore` remove the now-dead block (the comment + the ignore line):
```
# Secrets — never commit
UNBOUND/Services/Secrets/Secrets.swift
```
(Leave `*.env` / `.env.local` — unrelated.)

- [ ] **Step 3: Regenerate + build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **` (Secrets had no remaining referencer).

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git diff --cached --name-only
# staged should be: Secrets.swift.template (deleted via git rm). Add .gitignore + project.yml.
git add .gitignore project.yml
git commit -m "chore(secrets): delete Secrets — no LLM key in the binary

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" -- UNBOUND/Services/Secrets/Secrets.swift.template .gitignore project.yml
```
Drop `project.yml` if unmodified.

---

## Task B4: Full green gate + exposure assertions

**Files:** none (verification).

- [ ] **Step 1: Full suite**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -20`
Expected: green except the known `FriendChallengeServiceTests`/`SquadMissionServiceTests` RLS flap. `ClaudeClientTests` (4) pass. Zero NEW failures. Capture the exact `Executed N tests, with M failures` line + failing names.

- [ ] **Step 2: Exposure greps (must all be empty)**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
grep -rn "GeminiClient\|geminiAPIKey" UNBOUND --include="*.swift"
grep -rn "Secrets\." UNBOUND --include="*.swift" | grep -v "Services/Secrets/"
grep -rn "api.anthropic.com\|x-api-key\|generativelanguage.googleapis" UNBOUND --include="*.swift"
git ls-files | grep -i "Secrets/Secrets.swift$"
```
Expected: ALL empty. (No Gemini symbol; no `Secrets.` reference; no direct LLM host / key header in the app; `Secrets.swift` not tracked and now gone.) If any line prints, report it as a blocker — Phase B is not complete.

- [ ] **Step 3: Commit (only if a verification note file is produced — otherwise skip; no code changed)**

No commit (verification-only task).

---

## Task B5: HUMAN GATE — deploy + on-device + security checks (jlin)

**Files:** none. This task is NOT executed by a subagent. It is the explicit human gate; the controller stops here and hands off.

- [ ] **Step 1 (jlin runs locally):**
```bash
cd /Users/jlin/Documents/toji/UNBOUND
supabase functions deploy anthropic_proxy
supabase secrets set ANTHROPIC_API_KEY=<the existing Anthropic key>
```
(`SUPABASE_URL` / `SUPABASE_ANON_KEY` are auto-injected into Edge Functions by the platform — only `ANTHROPIC_API_KEY` must be set.)

- [ ] **Step 2 (jlin) — on-device through the proxy, signed in:** build/install/launch on iPhone 17 sim, sign in, then exercise: a **scan comparison**, a **coach note**, a **travel-plan** — each must still produce its result (now via Claude through the proxy).

- [ ] **Step 3 (jlin) — security assertions** (replace `<PROJECT>` = `xwoemvkzrnnsvtupxctu`, `<PUBLISHABLE>` = the app's `sb_publishable_…`):
```bash
# (a) publishable key only, no user JWT → 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "https://<PROJECT>.supabase.co/functions/v1/anthropic_proxy" \
  -H "Authorization: Bearer <PUBLISHABLE>" -H "content-type: application/json" \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":8,"system":"x","messages":[{"role":"user","content":[{"type":"text","text":"hi"}]}]}'
# expect: 401

# (b) (with a real signed-in user access_token) disallowed model → 400
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "https://<PROJECT>.supabase.co/functions/v1/anthropic_proxy" \
  -H "Authorization: Bearer <USER_ACCESS_TOKEN>" -H "content-type: application/json" \
  -d '{"model":"gpt-4","max_tokens":8,"system":"x","messages":[]}'
# expect: 400
```
Expected: (a) → `401`, (b) → `400`. A real signed-in app call → `200`. These prove the proxy is not an open relay and the key is server-side only.

- [ ] **Step 4:** jlin signs off or files diffs. Done.

---

## Self-Review

**1. Spec coverage:**
- Add optional `temperature` (spec §Locked 4) → A1 ✓
- 1:1 schema→tool mapping, system/userText/images preserved, model split Sonnet-scan/Haiku-coach/Haiku-travel (spec §Locked 2,3; Architecture Phase A table) → A2/A3/A4 ✓
- Delete GeminiClient + key + refs, co-located grep guard (spec Architecture Phase A) → A5 ✓
- `anthropic_proxy` JWT non-anon gate + ANTHROPIC_API_KEY secret + model allowlist + verbatim passthrough (spec §Locked 5,6; Architecture Phase B) → B1 ✓
- `ClaudeTransport` seam → `functions.invoke`, retry/types byte-identical, mock unit tests (spec Architecture Phase B; Testing) → B2 ✓
- Delete Secrets.swift/template + .gitignore (spec Architecture Phase B Cleanup) → B3 ✓
- Build/test green + exposure greps (spec Testing) → B4 ✓
- Human deploy gate + on-device + 401/400 security curls (spec Testing "human step" + security assertions) → B5 ✓
- Non-streaming passthrough, no rotation, no extra rate-limit (spec Out of scope) → respected (no streaming/rotation/limit tasks) ✓

**2. Placeholder scan:** No TBD/TODO. All edits show exact before/after blocks. The two `inputSchema:` literals in B2's test carry an explicit "adjust to the real `JSONValue` case labels" instruction (the behavior under test is schema-independent) — a bounded, specified adaptation, not a placeholder. The `EdgeFunctionTransport` "adapt to the vendored supabase-swift API" note states a precise invariant contract (send Encodable body → get `(Data, Int)`) for an external SDK whose exact signature varies by version — legitimate, not vague.

**3. Type consistency:** `ClaudeClient.RequestBody(model:maxTokens:system:messages:tools:toolChoice:temperature:)` is defined in A1 and used identically in B2's tests/`send`. `ClaudeClient.Tool(name:description:inputSchema:)` matches the existing struct used in A2/A3/A4. `ClaudeTransport.send(_:) -> (data: Data, status: Int)` defined B2, implemented by `EdgeFunctionTransport` + `MockClaudeTransport`, consumed by `ClaudeClient.send`. `.sonnet46`/`.haiku45` are the real `ClaudeClient.Model` cases. `Model` allowlist raw values in B1 match the enum raw values. Consistent across A1→B5.
