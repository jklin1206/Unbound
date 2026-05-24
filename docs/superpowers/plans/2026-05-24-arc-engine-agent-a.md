# Agent A — Arc Engine Phase Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`2026-05-24-program-canvas-monthly-arc.md`](2026-05-24-program-canvas-monthly-arc.md). All 12 locked decisions there are binding.

**Goal:** Promote UNBOUND's program cycle to a first-class 28-day Arc with two internal waves, region-aware fatigue, session-role tagging, and a clean signal-in / signal-out boundary with the Checkpoint Scan. Calibration Week stays as the pre-Arc proof-gathering period.

**Architecture:** Introduce an explicit `Arc` model wrapping 28 days of generation, with Wave 1 (Day 1–14, stable) and Wave 2 (Day 15–28, adjusting) phases inside it. Region-aware fatigue replaces the single accessory-trim rule. Session roles annotate every scheduled day. Wave 2 changes always carry a structured `ProgramRationale` payload (templated copy, no AI).

**Tech stack:** Swift / SwiftUI (existing UNBOUND iOS app). XCTest. No new dependencies.

---

## Scope

In:
- Program / Arc / Wave models + transitions
- 28-day Arc generation from Calibration output
- Wave 2 adjustment rules (Day 15 trigger, snooze-to-undo metadata)
- Region-aware fatigue budgeting
- Session-role tagging on every scheduled day
- Missing-session rolling-7d metric
- Scheduler updates
- Reason payloads for every adjustment

Out (other agents):
- Editor UX, Saved Workouts persistence (Agent B)
- Skill block routing into workouts, proof engine, reward UX (Agent C)
- Checkpoint Scan UI, AI summary plumbing (Agent D)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/Program.swift` | Modify | Add `Arc` association; `Wave` enum; `currentWave(asOf:)` helper |
| `UNBOUND/Models/ProgramBlock.swift` | Modify | Add `sessionRole: SessionRole` |
| `UNBOUND/Models/ProgramRationale.swift` | Modify | Extend reason enum with Wave 2 cases; add `regionScope: BodyRegion?`; add `revertible: Bool` |
| `UNBOUND/Models/Arc.swift` | Create | `id`, `startDate`, `endDate (start+28d)`, `wave1Range`, `wave2Range`, `state`, `sourceArcID` (chain) |
| `UNBOUND/Models/BodyRegion.swift` | Create | enum: `pull`, `push`, `legs`, `core`, `posterior`, `shoulders` |
| `UNBOUND/Models/RegionLoad.swift` | Create | `[BodyRegion: Double]` budget + helpers |
| `UNBOUND/Models/SessionRole.swift` | Create | enum: `pull`, `push`, `legs`, `upper`, `lower`, `fullBody`, `squatFocus`, `pullFocus`, `pushVertical`, `pushHorizontal`, `broChest`, `broBack`, `broShoulders`, `broArms`, `cardio`, `skillOnly`, `custom(String)` |
| `UNBOUND/Services/ProgramGeneration/ArcGenerator.swift` | Create | Calibration → Arc 1; Arc N → Arc N+1 (post-Checkpoint or skip-conservative) |
| `UNBOUND/Services/ProgramGeneration/WaveAdjuster.swift` | Create | Wave 2 adjustment rules (Day 15 trigger); emits rationales |
| `UNBOUND/Services/ProgramGeneration/RegionFatigueBudget.swift` | Create | Per-region weekly budget; trim logic |
| `UNBOUND/Services/ProgramGeneration/SessionRoleTagger.swift` | Create | Tags each scheduled day given user split + workout content |
| `UNBOUND/Services/Program/ArcScheduler.swift` | Create or extend | Rolls Calibration → Arc 1; chains Arc N→N+1; surfaces "Arc complete" event |
| `UNBOUND/Services/Program/MissedSessionMetric.swift` | Create | Rolling-7d % computation; emits `MissedSessionState` (normal / soft-checkin / ramp-week-offered / stale) |
| `UNBOUND/Services/Calibration/*` | Touch lightly | Calibration Summary now hands a `CalibrationOutput` payload to `ArcGenerator` |
| `UNBOUND/Models/CalibrationBaseline.swift` | Modify | Ensure outputs include enough signal for Arc generation (loads, session-roles inferred, region history) |
| `UNBOUND/UNBOUNDTests/ArcGeneratorTests.swift` | Create | Deterministic generator tests |
| `UNBOUND/UNBOUNDTests/WaveAdjusterTests.swift` | Create | Day 15 trigger, no-Day-14, no-Day-16-double-trigger |
| `UNBOUND/UNBOUNDTests/RegionFatigueBudgetTests.swift` | Create | Cross-region adds don't conflict; same-region trims |
| `UNBOUND/UNBOUNDTests/SessionRoleTaggerTests.swift` | Create | PPL, U/L, FB, Bro, custom — each maps correctly |
| `UNBOUND/UNBOUNDTests/MissedSessionMetricTests.swift` | Create | 3×/wk vs 6×/wk schedules produce correct % at boundaries |
| `UNBOUND/UNBOUNDTests/ArcSchedulerTests.swift` | Create | Calibration → Arc, Arc N → Arc N+1, Checkpoint skip path |

---

## Tasks

### Task A1 — Domain models (Arc, Wave, BodyRegion, SessionRole, RegionLoad)

**Files:** Create `Arc.swift`, `BodyRegion.swift`, `RegionLoad.swift`, `SessionRole.swift`. Modify `Program.swift`, `ProgramBlock.swift`.

**Acceptance**
- `Arc` has `id`, `startDate`, `endDate (start + 28 days)`, computed `wave1Range`, `wave2Range`, `state`, `sourceArcID?`.
- `Wave` enum: `wave1`, `wave2`. `Arc.currentWave(asOf: Date)` returns the right wave for any date inside the Arc.
- `BodyRegion` is exhaustive enough to cover the 6 named regions and `case other(String)` escape hatch.
- `SessionRole` includes every canonical split's roles + `.custom(String)` fallback.
- `Program` references `Arc` (one-to-many over time; current Arc is the live one).
- `ProgramBlock` carries `sessionRole`.

**Test (`ArcModelTests.swift`):** date math at start/end boundary, Wave 1/2 boundary at Day 14→15.

**Commit:** `feat(program): Arc / Wave / BodyRegion / SessionRole domain models`

### Task A2 — ProgramRationale extension

**File:** Modify `ProgramRationale.swift`.

**Acceptance**
- Reason enum cases for every adjustment type: `loadLowered(BodyRegion?)`, `loadRaised(BodyRegion?)`, `repsChanged`, `setCountChanged`, `exerciseSwapped`, `accessoryRemoved(BodyRegion)`, `vowReplacingAccessory(BodyRegion)`, `skillBlockInserted(BodyRegion)`, `deloadApplied`, `missedPressureReduced`, `checkpointRecommendation`.
- Each carries `revertible: Bool` (Wave 2 changes = true; Checkpoint commits = false).
- Templated localized copy lives in a single `ProgramRationaleCopy.strings`-style table, not interleaved with logic.

**Test:** every enum case must map to a non-empty localized string; missing-case build error if a future case is added without copy.

**Commit:** `feat(program): rationale enum + per-region scope + revertible flag`

### Task A3 — SessionRoleTagger

**File:** Create `SessionRoleTagger.swift`.

**Acceptance**
- Input: a planned day (split type + planned exercises). Output: `SessionRole`.
- PPL day with bench/dips/triceps → `.push`. Replacing one exercise within the day must not change the role.
- A/B variants must share the role (verified in tests).

**Test (`SessionRoleTaggerTests.swift`):**
- Each canonical split produces consistent roles.
- "Swap dips for chin-ups" on a Push day flips the role (signaling invalid A/B candidate).

**Commit:** `feat(program): session-role tagging`

### Task A4 — RegionFatigueBudget

**File:** Create `RegionFatigueBudget.swift`.

**Acceptance**
- Computes weekly load per `BodyRegion` from planned workouts + active skill blocks + active vows.
- Returns a trim recommendation: `{region: trimAmount}` only for regions over budget.
- Cross-region adds (pull skill + leg vow) produce zero trim recommendations.
- Same-region adds (pull skill + pull-focused vow) produce a non-zero trim only on `.pull`.

**Test (`RegionFatigueBudgetTests.swift`):**
- Verify the cross-region no-trim case explicitly (per Decision 10).
- Verify same-region trim with reasoned warning payload.
- Edge: empty week → empty trim.

**Commit:** `feat(program): region-aware weekly fatigue budget`

### Task A5 — ArcGenerator

**File:** Create `ArcGenerator.swift`.

**Acceptance**
- `generateInitialArc(from calibration: CalibrationOutput) -> Arc` produces a 28-day Arc with:
  - day-level workout blueprints (load, reps, sets, RPE targets, exercises) from Calibration loads
  - `sessionRole` tagged on every scheduled day
  - region budget honored from the start
- `generateNextArc(from previousArc: Arc, checkpoint: CheckpointOutcome?) -> Arc`
  - if Checkpoint completed: incorporates structured signals
  - if skipped: applies conservative continuation (current loads, no shape change)
- Both call paths emit `ProgramRationale`s for every meaningful default deviating from the previous Arc.

**Test (`ArcGeneratorTests.swift`):**
- Initial Arc from a known Calibration fixture produces a stable, expected schedule.
- Next Arc with `nil` checkpoint preserves session structure; loads progress conservatively (≤2.5% per week).
- Next Arc with checkpoint signals applies expected adjustments and emits matching rationales.

**Commit:** `feat(program): ArcGenerator — Calibration→Arc and Arc N→Arc N+1`

### Task A6 — WaveAdjuster (Day 15 trigger, snooze-to-undo metadata)

**File:** Create `WaveAdjuster.swift`.

**Acceptance**
- Idempotent: calling on Day 14 yields no adjustments; Day 15+ produces adjustments at most once per arc-week boundary.
- Every emitted adjustment carries `ProgramRationale` with `revertible: true`.
- Region-aware: respects `RegionFatigueBudget`.
- Never silently:
  - replaces Saved Workouts marked customized
  - changes the split shape
  - removes user-added custom sessions
  - swaps a major exercise without a reason

**Test (`WaveAdjusterTests.swift`):**
- No-op on Day 14.
- Triggers on Day 15.
- Cannot double-trigger on Day 16 if Day 15 already ran for the same week.
- Customized Saved Workouts pass through untouched.
- Region pressure within budget → load may rise; over budget → trim only the over-budget region.

**Commit:** `feat(program): WaveAdjuster — Day 15 trigger with revertible rationales`

### Task A7 — ArcScheduler

**File:** Create / extend `ArcScheduler.swift`.

**Acceptance**
- Listens for "Calibration complete" → calls `ArcGenerator.generateInitialArc`.
- Listens for "Arc Day 28 complete" → either:
  - if user opens Checkpoint flow: hand off to Agent D; await `CheckpointOutcome`
  - if user skips Checkpoint window (24h grace): call `ArcGenerator.generateNextArc(checkpoint: nil)`
- Exposes an `ArcContext` (current arc, current wave, days remaining) for the Program tab strip.

**Test (`ArcSchedulerTests.swift`):**
- Calibration → Arc 1 happy path.
- Arc N → Arc N+1 with Checkpoint completed.
- Arc N → Arc N+1 with Checkpoint skipped (after 24h grace).
- Mid-arc Day 17 query returns `ArcContext { arc: 3, wave: .wave2, daysRemaining: 11 }`.

**Commit:** `feat(program): ArcScheduler with Checkpoint hand-off + skip grace`

### Task A8 — MissedSessionMetric

**File:** Create `MissedSessionMetric.swift`.

**Acceptance**
- Rolling-7-day window measured from "today."
- `% missed = missed scheduled sessions / total scheduled sessions in window`.
- Returns `MissedSessionState`:
  - `< 50%` → `.normal`
  - `50–79%` → `.softCheckIn`
  - `≥ 80%` → `.rampWeekOffered`
  - `≥ 80% sustained 14 days` → `.staleRecalibrationRecommended`

**Test (`MissedSessionMetricTests.swift`):**
- 3×/wk user missing 2 sessions in 7 days → 67% → `.softCheckIn`.
- 6×/wk user missing 5 sessions in 7 days → 83% → `.rampWeekOffered`.
- 6×/wk user missing 5 sessions in 7 days for 14 days → `.staleRecalibrationRecommended`.
- Zero scheduled sessions (deload week) → `.normal`.

**Commit:** `feat(program): rolling-7d missed-session metric`

### Task A9 — Calibration→Arc integration

**Files:** Modify Calibration completion path (`UNBOUND/Services/Calibration/`) + `CalibrationBaseline.swift`.

**Acceptance**
- Calibration Summary screen hands `CalibrationOutput` to `ArcScheduler.startFirstArc(...)`.
- `CalibrationOutput` carries: per-movement standards, session-role inferences (from logged Calibration workouts), region history, declared schedule, missing-data flags.
- No regression in existing Calibration flow.

**Test:** simulator slice — run Calibration through Completion → assert Arc 1 exists with correct start date and Wave 1 active.

**Commit:** `feat(program): Calibration hand-off to ArcScheduler`

### Task A10 — Full-engine sim suite (integration owner)

**Acceptance**
- Run the full simulator test slice for Program / Calibration / Scan / Skill / Reward.
- Verify Agent B / C / D's tests pass against current engine.
- Document any cross-agent friction.

**Test:** full Xcode test plan green.

**Commit:** `chore(program): engine-side integration suite passes`

---

## Verification (end of phase)

```
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:UNBOUNDTests/ArcGeneratorTests -only-testing:UNBOUNDTests/WaveAdjusterTests -only-testing:UNBOUNDTests/RegionFatigueBudgetTests -only-testing:UNBOUNDTests/SessionRoleTaggerTests -only-testing:UNBOUNDTests/MissedSessionMetricTests -only-testing:UNBOUNDTests/ArcSchedulerTests
```

All green = phase done.
