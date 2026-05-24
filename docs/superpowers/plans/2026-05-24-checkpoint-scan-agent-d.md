# Agent D — Checkpoint Scan + AI Summary Phase Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`2026-05-24-program-canvas-monthly-arc.md`](2026-05-24-program-canvas-monthly-arc.md). All 12 locked decisions there are binding.

**Goal:** Build the end-of-Arc Checkpoint (skippable but highly rewarded) with a strict AI boundary — AI may only summarize messy free-text and the end-of-Arc voice paragraph; deterministic rules decide every training adjustment. Scope nutrition to protein + hydration + optional fuel.

**Architecture:** `Checkpoint` is a flow state spanning prompts, photo/body capture, free-text fields, and a deterministic-validated outcome that hands off to Agent A's `ArcScheduler` for next-Arc generation. AI lives behind a single `CheckpointSummarizer` interface that takes structured input and returns structured signals + an opt-in narrative paragraph. Every signal passes through deterministic validation before reaching the engine.

**Tech stack:** SwiftUI, existing `AISession` infrastructure, XCTest. The AI call uses the existing Anthropic/OpenAI/whatever session pattern already in the codebase — see `UNBOUND/Models/AISession.swift`.

---

## Scope

In:
- Checkpoint flow (skippable + rewarded)
- Structured signal pipeline (`CheckpointSignals`)
- AI summary boundary (`CheckpointSummarizer`) with deterministic validation
- Next-Arc review UI (preview before commit)
- Nutrition scope: protein + hydration + optional training fuel
- Bodyweight capture fallback (generic range if user declines)

Out:
- Arc generation itself (Agent A consumes the signals)
- Editor (Agent B)
- Skill / proof / reward (Agent C)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/ScanCheckpoint.swift` | Modify | Add fields for new structured signals and skip-vs-complete state |
| `UNBOUND/Models/CheckpointSignals.swift` | Create | Deterministic signal payload that flows to Agent A |
| `UNBOUND/Models/CheckpointOutcome.swift` | Create | Result of the flow — `.completed(CheckpointSignals)` / `.skipped` |
| `UNBOUND/Models/NutritionContext.swift` | Create | protein target, hydration target, optional fuel guidance, bodyweight (optional) |
| `UNBOUND/Services/Scan/CheckpointFlow.swift` | Create | State machine for the multi-step Checkpoint |
| `UNBOUND/Services/Scan/CheckpointSummarizer.swift` | Create | Wraps the AI call — structured-in, structured-out + optional narrative |
| `UNBOUND/Services/Scan/CheckpointValidator.swift` | Create | Deterministic guardrails on any AI-derived signal |
| `UNBOUND/Services/Scan/NutritionTargetCalculator.swift` | Create | Bodyweight → protein/hydration targets; generic fallback when bodyweight absent |
| `UNBOUND/Views/Scan/CheckpointEntryCard.swift` | Create | Skippable entry point shown at end of Arc |
| `UNBOUND/Views/Scan/CheckpointFreeTextStep.swift` | Create | Messy free-text input (this is where AI helps interpret) |
| `UNBOUND/Views/Scan/CheckpointReviewView.swift` | Create | "Here's what changes next Arc" preview before commit |
| `UNBOUND/Views/Scan/NutritionCard.swift` | Create | Minimal protein / hydration / optional fuel card |
| `UNBOUND/UNBOUNDTests/CheckpointFlowTests.swift` | Create | Skip path, complete path, mid-flow cancel |
| `UNBOUND/UNBOUNDTests/CheckpointSummarizerTests.swift` | Create | AI output → structured signals; malformed AI output → safe fallback |
| `UNBOUND/UNBOUNDTests/CheckpointValidatorTests.swift` | Create | Signals outside bounds get clamped / rejected with reason |
| `UNBOUND/UNBOUNDTests/NutritionTargetCalculatorTests.swift` | Create | Bodyweight present + absent both produce sane targets |
| `UNBOUND/UNBOUNDUITests/CheckpointWalkthroughTests.swift` | Create | Simulator walkthrough — complete + skip |

---

## Tasks

### Task D1 — Domain models

**Files:** Modify `ScanCheckpoint.swift`. Create `CheckpointSignals.swift`, `CheckpointOutcome.swift`, `NutritionContext.swift`.

**Acceptance**
- `CheckpointSignals` is a Codable struct that the Arc engine knows how to consume. Fields (at minimum):
  - `loadAdjustmentBias: Double?` (`-1.0 ... 1.0`) — clamped
  - `recoveryStateHint: RecoveryState?` (enum: `wellRecovered`, `normal`, `accumulated`, `flagged`)
  - `weakRegions: [BodyRegion]` (from Agent A)
  - `skillFocusHints: [SkillID]`
  - `nutrition: NutritionContext?`
  - `freeTextSummary: String?` (the narrative paragraph — informational only, never affects engine)
- `CheckpointOutcome`: `.completed(CheckpointSignals)` or `.skipped` (Agent A maps these to its `generateNextArc(checkpoint:)` signature).

**Test:** Codable round-trip; clamping verified.

**Commit:** `feat(checkpoint): structured signal models`

### Task D2 — `CheckpointFlow` state machine

**File:** Create `CheckpointFlow.swift`.

**States**
1. `.entry` — user sees Checkpoint card with two options: **Begin** / **Skip** (skip is one tap, no friction)
2. `.bodyCapture` (optional sub-step)
3. `.standardsCheck` — quick yes/no on a small set of standards
4. `.freeText` — single text field: "How did this Arc feel?"
5. `.nutritionCheck` — bodyweight (optional) + a one-line protein/hydration confirmation
6. `.summarizing` — calls `CheckpointSummarizer`
7. `.review` — `CheckpointReviewView` previews next-Arc changes
8. `.commit` — emits `CheckpointOutcome.completed(signals)`

**Acceptance**
- Skip from `.entry` emits `.skipped` immediately and routes to Agent A's conservative continuation path.
- User can back-out at any step; partial state is discarded.
- Arc Day 28 → Day 29 grace window: if neither Begin nor Skip is tapped within 24h of Arc end, treat as `.skipped`.

**Test (`CheckpointFlowTests.swift`):** state transitions; skip on `.entry`; cancel mid-flow; grace-window expiry → skipped.

**Commit:** `feat(checkpoint): state machine with skip-as-default grace window`

### Task D3 — `CheckpointSummarizer` (AI boundary)

**File:** Create `CheckpointSummarizer.swift`.

**Contract**
- Input: structured Checkpoint inputs (standards-check results, free-text body) — never raw user text passed directly to engine downstream.
- Output: `(signals: CheckpointSignals, narrative: String)`.
- AI is allowed to:
  - parse the free-text into structured fields (`recoveryStateHint`, `weakRegions` candidates, `skillFocusHints` candidates)
  - write the `freeTextSummary` paragraph
- AI is **not** allowed to:
  - set numeric load adjustments (these come from deterministic rules over the structured signals — `loadAdjustmentBias` is computed by `CheckpointValidator`, not by AI)
  - override standards-check results
  - author reason-label copy on changes (those are templated by Agent A per Decision 6)
- On malformed AI output: drop the unparseable fields, keep the rest, log the failure, never propagate raw AI output into the engine.

**Test (`CheckpointSummarizerTests.swift`):**
- Well-formed free text → expected structured signals.
- Malformed / empty AI output → safe fallback (signals with only the deterministic fields filled).
- Injected AI response that tries to set `loadAdjustmentBias` directly is ignored.

**Commit:** `feat(checkpoint): AI summarizer with strict structured-output boundary`

### Task D4 — `CheckpointValidator`

**File:** Create `CheckpointValidator.swift`.

**Acceptance**
- Computes `loadAdjustmentBias` deterministically from `recoveryStateHint` + standards-check + missed-session metric (from Agent A).
- Clamps every numeric signal to safe ranges.
- Rejects any `weakRegion` not in `BodyRegion`'s enum (silent drop with log).
- Returns a `CheckpointSignals` value that is guaranteed safe for Agent A to consume.

**Test (`CheckpointValidatorTests.swift`):**
- Recovery `.accumulated` + missed-session `.softCheckIn` → expected negative bias.
- Out-of-bounds bias input → clamped.
- Unknown region string → dropped.

**Commit:** `feat(checkpoint): deterministic validator over structured signals`

### Task D5 — `NutritionTargetCalculator` + `NutritionCard`

**Files:** Create `NutritionTargetCalculator.swift`, `NutritionCard.swift`.

**Acceptance**
- Bodyweight present → protein target = `bodyweight_kg × proteinFactor` (factor matches existing UNBOUND convention; if none, use 1.6–2.2 g/kg range, defaulting to 1.8).
- Bodyweight absent → fall back to a generic range card ("aim 0.7–1.0 g per lb bodyweight; you can add bodyweight in Settings for personalized targets").
- Hydration target = bodyweight-based default; absent → generic range.
- Optional training fuel guidance shows up only when the user has logged a hard session in the last 24h.
- No BMI, no calorie totals, no meal plans.

**Test (`NutritionTargetCalculatorTests.swift`):**
- 80kg user → protein in 128–176g range with default factor.
- No bodyweight → fallback string surface; no numeric target.

**Commit:** `feat(nutrition): bodyweight-driven targets with generic fallback`

### Task D6 — Checkpoint UI (Entry / Free-text / Review / Nutrition card)

**Files:** Create `CheckpointEntryCard.swift`, `CheckpointFreeTextStep.swift`, `CheckpointReviewView.swift`. Also `NutritionCard.swift` (from D5) is rendered inside Checkpoint review and on the Program tab when relevant.

**Acceptance**
- `CheckpointEntryCard`:
  - shown when Arc Day 28 is complete
  - two actions: **Begin Checkpoint** / **Skip**
  - clearly communicates "Skip is fine; you'll keep training. Begin to unlock a sharper next Arc + rewards."
- `CheckpointReviewView`:
  - shows next-Arc deltas in templated copy (per Decision 6)
  - groups deltas by region
  - has a **Commit** and a **Back to Checkpoint** action
- No checkpoint-related modal blocks training. The user can return to Program tab at any moment.

**Test:** ViewModel tests + UI smoke (see D7).

**Commit:** `feat(checkpoint): entry card, free-text step, next-Arc review`

### Task D7 — Walkthrough simulator slice

**File:** Create `CheckpointWalkthroughTests.swift` (UITests).

**Scenarios**

**Complete path**
1. Reach Arc Day 29 in a seeded sim.
2. Tap **Begin Checkpoint**.
3. Capture body (or skip sub-step).
4. Tick a quick standards-check.
5. Type free text.
6. Confirm nutrition card.
7. Land on `CheckpointReviewView`; verify deltas are grouped by region with templated copy.
8. Commit; verify Agent A's next Arc is generated with the expected adjustments.

**Skip path**
1. Reach Arc Day 29.
2. Tap **Skip**.
3. Verify Agent A generates a conservative continuation Arc.
4. Verify no checkpoint reward is granted; training continues uninterrupted.

**Commit:** `test(checkpoint): complete + skip walkthrough UI tests`

### Task D8 — AI summary fallback hardening

**Acceptance**
- AI service unavailable / timeout → Checkpoint still completes; `freeTextSummary` becomes a templated "Your Arc summary will be ready next time you open the app" message.
- The deterministic signals path always succeeds (independent of AI availability).

**Test:** add to `CheckpointSummarizerTests` — simulated network error → graceful structured-only outcome.

**Commit:** `feat(checkpoint): graceful AI fallback`

---

## Verification (end of phase)

```
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/CheckpointFlowTests \
  -only-testing:UNBOUNDTests/CheckpointSummarizerTests \
  -only-testing:UNBOUNDTests/CheckpointValidatorTests \
  -only-testing:UNBOUNDTests/NutritionTargetCalculatorTests \
  -only-testing:UNBOUNDUITests/CheckpointWalkthroughTests
```

All green = phase done. Hand off to Agent A for full-engine sim suite.
