# Phase 0 — "Logging Actually Records" + "Unmatched — Won't Count" Integrity State

Investigation + proposal. **No Swift was modified.** This is the sign-off doc for the
ONE-METRIC cleanup Phase 0.

---

## TL;DR Verdicts

| # | Concern | Verdict |
|---|---------|---------|
| a | Unrecognized / free-text exercise silently fails to count (no rank/skill/XP/attributes) | **CONFIRMED — silent drop. Reachable in the live app** via the custom-exercise builder. This is the real Phase-0 gap. |
| b | Legacy `WorkoutLoggingView` → `viewModel.saveLog()` → `recordProgressionForLegacyWorkout` path is a live side-effect-free bug | **NOT a live bug. `WorkoutLoggingView` is DEAD UI** — never presented anywhere. The screen + its VM are safely retirable. |
| c | `WorkoutLogServiceProtocol.saveLog(_:)` cascade is dead/deletable | **The `saveLog(_:)` METHOD is dead** (zero production callers) and its body is deletable. The *protocol* and the other methods (`fetchLogs`/`fetchRecentLogs`/`updateLog`/`deleteLog`/`saveCompatibleHistoryLog`) are **live — keep them.** |

---

## 1. Does an unmatched / free-text exercise silently fail to count? — YES

### How resolution works
`MovementResolver.resolve(_:)` (`MovementCatalog.swift:1862`) **never returns nil**. On no match it
falls all the way through `inferredDefinition(...)` and returns a **sentinel** `MovementDefinition`
(`MovementCatalog.swift:1903`):

| Field | Sentinel value on no-match |
|-------|----------------------------|
| `id` | `"unresolved.<slug-of-rawName>"` |
| `role` | `.routineStep` |
| `rankable` | **`false`** |
| `rankTemplate` | `.unranked` |
| `substitutionGroup` | `"unresolved"` |

So it does **not** mis-attribute to a wrong movement (good — no false rank). Instead it produces a
non-rankable sentinel.

### What that sentinel does downstream (the silent part)
`MovementAPCalculator.resolveMovement(...)` (`MovementProgressService.swift:306`) **returns nil**
whenever `exact.rankable == false`:

```swift
guard let resolved = ...,
      resolved.exact.rankable,        // <- sentinel is false → bail
      let standard = resolved.standard,
      standard.rankable else { return nil }
```

Because `gains(...)` does `guard let resolved else { continue }`, an unmatched exercise yields **zero
`MovementAPGain`s**. With no gains, the entire reward fan-out produces nothing:

| Reward axis | Source | Result for unmatched exercise |
|-------------|--------|------------------------------|
| Movement AP / rank | `MovementAPCalculator.gains` | none (no gain emitted) |
| Attributes / XP | `AttributeIngest.xpDeltas(for: gains)` | none (gains empty) |
| Body map | `regionLoads(from: gains)` | none |
| Overall Level | `OverallLevelService.ingest(gains:)` | none |
| Skill XP | `SessionLog.skillId` from `resolved.skillId` (nil for sentinel) | none |

**Net: the set is written to history, but contributes nothing to any progression metric, and the user
is never told.** That is the exact "silently vanishes" failure Phase 0 targets.

### Is it reachable in the live app? — YES
The live logger is `ActiveWorkoutContainerView` (→ `TrainingCompletionService.complete()`). It exposes a
**Custom exercise builder** (`ActiveWorkoutContainerView.swift:237` → `CustomExerciseBuilderView`).
That builder is a **free-text name field** (`CustomExerciseBuilderView.swift:64`, placeholder
`"e.g. Zercher Squat"`) and saves `CustomExercise(name: trimmedName.lowercased(), ...)` with **no
movementId binding** (`CustomExerciseBuilderView.swift:268`). Resolution happens purely by name at log
time. A novel name the catalog can't match → `unresolved.*` → silent zero-reward.

### Skill matching
`SessionLog`s are built from `resolved.skillId`, which is `nil` for the sentinel, so no skill node gets
XP either — same silent behavior, consistent with the above.

---

## 2. Is `WorkoutLoggingView` reachable? — NO (dead UI)

| Check | Finding |
|-------|---------|
| Construction sites of `WorkoutLoggingView(...)` | **Only `WorkoutLoggingView.swift:43`** — i.e. its own `init`. No `.sheet` / `.fullScreenCover` / `NavigationLink` / tab anywhere presents it. |
| Construction sites of `WorkoutLoggingViewModel(...)` | **Only in tests** (`ProgramAwareLoggingTests.swift:95,165`). Zero in `UNBOUND/`. |
| Live program logger today | `ActiveWorkoutContainerView` (presented by `ProgramOverviewView:196,1450` and `WorkoutReadyView:71`) → `complete()`. |

`complete()` is the canonical path used by **all** live loggers: `ProgramViewModel:125`,
`SkillSessionView:699`, `SkillDetailView:4161`, `LogCardioView:285`, `ProgramOverviewView:3698`,
`ActiveWorkoutContainerView:553`, `OverallRankTrialService:1917`.

### About the "side-effect-free legacy path"
It is true that `WorkoutLoggingViewModel.saveLog()` → `previewProgression` (side-effect-free) and that
`flushPendingCompletionEffects()` → `recordProgressionForLegacyWorkout` is **intentionally**
side-effect-free (Phase 9 de-double-award, `WorkoutLoggingViewModel.swift:17-20, 230-237`;
`TrainingCompletionService.swift:145-151`). **But because nothing presents `WorkoutLoggingView`, no real
session ever takes this path.** So it is *not* a live "workouts silently don't count" bug — it is dead
code that merely *looks* dangerous.

> Distinction that matters: `viewModel.saveLog()` is the **VM method** (preview only). It is **not** the
> `WorkoutLogServiceProtocol.saveLog(_:)` cascade. They share a name but are unrelated.

---

## 3. The `saveLog` cascade — what's dead vs live

There are **two** `saveLog`s:

| Name | Location | Status |
|------|----------|--------|
| `WorkoutLoggingViewModel.saveLog()` (VM) | `WorkoutLoggingViewModel.swift:167` | dead-with-its-view (see §2) — returns `previewProgression`, no service call |
| `WorkoutLogServiceProtocol.saveLog(_:)` (service cascade) | proto `:7`; impls `WorkoutLogService.swift:11`, `SupabaseWorkoutLogService.swift:24` | **method body is DEAD** |

### Production callers of the service-protocol `saveLog(_:)`
**Zero.** `grep '\.saveLog('` across `UNBOUND/` returns only the VM call (`WorkoutLoggingView:556`, which
hits the VM method) and comments. The cascade impls (`WorkoutLogService.saveLog`,
`SupabaseWorkoutLogService.saveLog`) are referenced only by **tests** + `MockWorkoutLogService`.
`SupabaseWorkoutLogService` is the wired impl (`ServiceContainer.swift:58`), but its `saveLog(_:)` is
never invoked in production — `complete()` routes WorkoutLog history through
`saveCompatibleHistoryLog(_:)` instead (`TrainingCompletionService.swift:439`).

The "identical side-effect chain" comment (`SupabaseWorkoutLogService.swift:40`) describes a cascade
(ProgressionEngine / SkillProgressService / RankService / SkinService / SessionXPService / BadgeService)
that **only fires for callers of `saveLog(_:)` — and there are none.** It is dormant code.

### What is LIVE on the protocol (must keep)
- `fetchRecentLogs(userId:limit:)` — `ActiveWorkoutContainerView:520`, `BadgeService:292`, plus direct
  `WorkoutLogService.shared.fetchRecentLogs` in `RankDecayService`, `SkillProgressService:122`,
  `BlockRolloverService`, `ProgramPhaseEngine`, `SupabaseWorkoutLogService` in `SkillDetailView:388`.
- `fetchLogs`, `updateLog`, `deleteLog` — live history/read/delete paths.
- `saveCompatibleHistoryLog(_:)` (`WorkoutLogCompatibilityHistoryWriting`) — **the canonical history
  writer** used by `complete()`. Keep.

---

## Proposal

### A. The "Unmatched — won't count" UX (jlin sign-off required)

**Goal:** when a logged exercise resolves to the `unresolved.*` sentinel, tell the user honestly instead
of silently dropping it. Keep it to **one badge/line** — not a workflow.

**Detection (simple, single source of truth):** an exercise is "unmatched" when its resolved movement is
the sentinel:

```swift
// helper on ResolvedMovement / MovementDefinition
var isUnmatched: Bool { movementId.hasPrefix("unresolved.") }   // or substitutionGroup == "unresolved"
```

This is exact and cheap — no fuzzy threshold, no new state. (Note: a free-text name that *infers* to a
real movement — cardio/carry/mobility/alias-base — is treated as matched, which is correct.)

**Where it surfaces — recommended: the reward sequence (post-complete receipt).** That is where the user
looks to see "what did I earn," so a missing line is exactly where a silent drop hurts. Add one honest
line per unmatched exercise in `WorkoutRewardSequenceSummary` / `WorkoutRewardSequenceView`:

> **"Zercher Squat — Unmatched · won't count toward rank or XP (saved to history)"**

**Options for jlin to choose placement (pick one):**

| Option | Where | Pro | Con |
|--------|-------|-----|-----|
| **R1 (recommended)** | A muted "Didn't count" section at the **bottom of the reward sequence** | Honest at the moment of reward; zero extra taps; matches the "where did my XP go" mental model | Post-hoc (after the set is already logged) |
| R2 | A small badge on the **set/exercise row** while logging (live in `ActiveWorkoutContainerView`) | Earliest signal; user can rename before finishing | Resolution must run per-keystroke/row; more surface area |
| R3 | A **confirm-time warning** before `complete()` ("1 exercise won't count — log anyway?") | Forces awareness | Adds a modal/interstitial — heavier than "one honest line" |

Recommendation: **R1**, because the deliverable spec says "one honest badge/line, not a workflow," and the
reward sequence already iterates movement lines. R2 is a reasonable add-on later but is more code now.

**This is the one decision that needs jlin.** Everything else below is mechanical.

### B. Retire the dead legacy logger (recommended: delete, not re-home)

Because `WorkoutLoggingView` is unpresented and the live program logger is already
`ActiveWorkoutContainerView` → `complete()`, **re-homing its progression is unnecessary** — there's no
traffic to re-home. Recommend **retiring the screen**:

- Delete `Views/Program/WorkoutLoggingView.swift`.
- Delete `ViewModels/WorkoutLoggingViewModel.swift`.
- Delete the dependent test `UNBOUNDTests/Models/ProgramAwareLoggingTests.swift` (it exists only to assert
  this VM's side-effect-free behavior — `saveLogCallCount == 0`).
- `Views/Components/SetLogRow.swift` references `WorkoutLoggingView` only in a doc comment
  (`SetLogRow.swift:5`) — check whether `SetLogRow` itself is still used by `ActiveWorkout*` before
  deleting; if used elsewhere, just leave it (don't touch the comment per surgical-changes rule, or
  reword the one line).

**Blast radius:** low. No production view presents these; only tests reference the VM. Confirm with a
clean build + test run after deletion.

> Per project memory ("delete old code on change"): retire in the same commit as the change, don't park
> it. This is a clean candidate.

### C. Deletion plan for the dead `saveLog(_:)` cascade

`saveLog(_:)` has **zero production callers** (§3). Two valid moves:

1. **Minimal (recommended for Phase 0):** delete the `saveLog(_:)` **method body + protocol requirement**:
   - Remove `func saveLog(_:)` from `WorkoutLogServiceProtocol.swift:7`.
   - Remove `saveLog(_:)` from `WorkoutLogService.swift:11-101` and
     `SupabaseWorkoutLogService.swift:24-67`.
   - Remove `saveLog` from `MockWorkoutLogService.swift:8` and its `saveLogCallCount`.
   - Update the tests that call `saveLog` / assert `saveLogCallCount`
     (`MovementProgressServiceTests.swift:806,937-941`, `TrainingSessionDraftStoreTests.swift:195`,
     `ProgramAwareLoggingTests.swift` — the latter goes away with §B).
   - **Keep** `WorkoutLogService.swift` itself — `fetchRecentLogs` etc. are live.
   - `WorkoutLogService.shared` (`WorkoutLogService.swift`, used by `RankDecayService`,
     `SkillProgressService`, `BlockRolloverService`, `ProgramPhaseEngine`, `PTContextBuilder`) stays.
2. **Aggressive:** also delete now-orphaned side-effect entry points if `saveLog` was their *only* caller
   (e.g. `ProgressionEngine.ingest`, `RankService.evaluate(log:)`, `SkinService.evaluateUnlocks` via this
   path). **Do NOT do this blind** — several are also called by `complete()`/other services. Out of scope
   for Phase 0; flag for a later dead-code sweep.

**Recommendation:** do (1) only. Verify each test still compiles/passes.

---

## What needs a jlin call vs mechanical

| Item | Type |
|------|------|
| **Unmatched UX placement (R1 / R2 / R3)** + exact copy | **jlin decision** (the deliverable) |
| Retire `WorkoutLoggingView` + VM + `ProgramAwareLoggingTests` (delete vs keep) | jlin go/no-go (recommend delete) |
| Delete `saveLog(_:)` method + protocol requirement + mock + fix tests | Mechanical (after go-ahead) |
| `isUnmatched` helper on `ResolvedMovement` | Mechanical |
| Aggressive side-effect-entry-point cleanup | **Out of scope** — later sweep |

---

## Key file map

| Concern | File:line |
|---------|-----------|
| Resolver no-match sentinel | `UNBOUND/Models/MovementCatalog.swift:1862, 1903` |
| `ResolvedMovement` shape | `UNBOUND/Models/MovementCatalog.swift:243` |
| Sentinel dropped (rankable guard) | `UNBOUND/Services/Progression/MovementProgressService.swift:306` |
| Reward fan-out (preview) | `UNBOUND/Services/TrainingCompletionService.swift:192` |
| Live custom free-text entry | `UNBOUND/Views/ExerciseLibrary/CustomExerciseBuilderView.swift:64, 268` |
| Custom builder presented | `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift:237` |
| Live `complete()` save | `ActiveWorkoutContainerView.swift:551-553` |
| Dead legacy view | `UNBOUND/Views/Program/WorkoutLoggingView.swift` (init at :43, only construction site) |
| Dead legacy VM | `UNBOUND/ViewModels/WorkoutLoggingViewModel.swift:167` (`saveLog`), `:221` (`flush`) |
| Side-effect-free legacy completion | `UNBOUND/Services/TrainingCompletionService.swift:124-190` |
| Dead `saveLog(_:)` cascade | `WorkoutLogService.swift:11`, `SupabaseWorkoutLogService.swift:24`, proto `:7` |
| Live history writer (keep) | `TrainingCompletionService.swift:439` → `saveCompatibleHistoryLog` |
| Reward sequence UI (UX target) | `UNBOUND/Models/WorkoutRewardSequence.swift`, `Views/Components/Unbound/WorkoutRewardSequenceView.swift` |
