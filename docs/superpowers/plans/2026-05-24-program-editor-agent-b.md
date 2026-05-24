# Agent B — Program Editor + Saved Workouts Phase Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`2026-05-24-program-canvas-monthly-arc.md`](2026-05-24-program-canvas-monthly-arc.md). All 12 locked decisions there are binding.

**Goal:** Make Program feel like a canvas, not a wizard. Add Saved Workouts (local-only v1), a fast swap sheet with batch-friendly persistence, replace-today flow, and weekly Saved-Workout scheduling. Enforce A/B rotation by session role.

**Architecture:** A new `SavedWorkout` model + local store (UserDefaults / on-disk JSON / Core Data — implementer choice based on existing UNBOUND patterns; see Task B0). The editor (`SessionEditorView`) gains save / replace / schedule actions. `ExerciseSwapSheet` gains a Today / Keep-using persistence chip and batch-confirm behavior. Agent A's `SessionRole` decides A/B validity.

**Tech stack:** SwiftUI, Swift Concurrency. Local persistence per existing patterns. XCTest + simulator walkthrough.

---

## Scope

In:
- `SavedWorkout` domain model + local persistence
- Editor save / replace / schedule UI
- Swap sheet — persistence chip, batch-friendly confirms
- A/B rotation gating by session role
- Program tab edit-flow entry points
- Editor walkthrough simulator tests

Out:
- Cloud sync (deferred per Decision 4)
- Engine generation logic (Agent A)
- Skill block routing (Agent C)
- Checkpoint Scan (Agent D)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/SavedWorkout.swift` | Create | id, title, blocks, order, target sets/reps/RPE, equipment, `sessionRole`, optional A/B partner |
| `UNBOUND/Services/SavedWorkouts/SavedWorkoutStore.swift` | Create | Local store (read/write/list/delete/replace). Picks the persistence strategy in Task B0. |
| `UNBOUND/Services/SavedWorkouts/SavedWorkoutScheduler.swift` | Create | Schedule a Saved Workout into one or more days of the current Arc |
| `UNBOUND/Services/SavedWorkouts/ABRotationGuard.swift` | Create | Uses Agent A's `SessionRoleTagger` to validate A/B partner candidates |
| `UNBOUND/Views/Program/SessionEditorView.swift` | Modify | Add Save / Replace-today / Schedule controls; surface revert chip for Wave 2 adjustments |
| `UNBOUND/Views/Program/ExerciseSwapSheet.swift` | Modify | Today / Keep-using chip; batch persistence; suppress repeated confirms |
| `UNBOUND/Views/Program/ProgramOverviewView.swift` | Modify | Add ongoing-user Arc context strip; entry into Saved Workouts list; reason chips on adjusted exercises |
| `UNBOUND/Views/Program/SavedWorkoutsListView.swift` | Create | Browse / open / schedule / delete saved workouts |
| `UNBOUND/Views/Program/SaveWorkoutSheet.swift` | Create | Title + tag + confirm; surfaces "stored on this phone" copy |
| `UNBOUND/Views/Program/ScheduleSavedWorkoutSheet.swift` | Create | Pick days within the current Arc to schedule into |
| `UNBOUND/ViewModels/ProgramViewModel.swift` | Modify | Wire save / replace / schedule actions; revert handler for Wave 2 |
| `UNBOUND/ViewModels/SessionEditorViewModel.swift` | Create or modify | Owns editor state + batch swap behavior |
| `UNBOUND/UNBOUNDTests/SavedWorkoutStoreTests.swift` | Create | Persistence round-trip, multi-workout list, delete, idempotent write |
| `UNBOUND/UNBOUNDTests/SavedWorkoutSchedulerTests.swift` | Create | Schedule into Arc days, conflict resolution with generated workouts |
| `UNBOUND/UNBOUNDTests/ABRotationGuardTests.swift` | Create | Same-role A/B passes; different-role A/B rejected |
| `UNBOUND/UNBOUNDUITests/EditorWalkthroughTests.swift` | Create | End-to-end simulator slice (see Task B7) |

---

## Tasks

### Task B0 — Pick local persistence strategy

**Action:** Read existing UNBOUND persistence patterns (`grep -rin "UserDefaults\|Core Data\|JSON.*Encoder" UNBOUND/Services`) and pick the strategy that matches them. Document the choice in `SavedWorkoutStore.swift` header.

**Acceptance:** A single justified choice (e.g., "matches `WorkoutLogStore` which uses on-disk JSON via `FileManager`"). If multiple precedents exist, prefer JSON-on-disk for v1 (cheaper migration path to cloud later).

**Commit:** `chore(saved-workouts): persistence-strategy decision noted in SavedWorkoutStore`

### Task B1 — `SavedWorkout` domain model

**File:** Create `SavedWorkout.swift`.

**Fields**
- `id: UUID`
- `title: String`
- `blocks: [WorkoutBlock]` (the new sub-workout block type — see Migration Note in the spec; not the existing 14-day phase struct, which is being renamed to `ProgramPhase`)
- `order: Int` (display ordering)
- `targets: WorkoutTargets` (sets/reps/RPE per block — reuse existing type if present)
- `preferredEquipment: Set<Equipment>`
- `sessionRole: SessionRole` (Agent A)
- `abPartnerID: UUID?` (optional A/B partner — both must share `sessionRole`)
- `createdAt`, `updatedAt`

**Acceptance:** Codable; equatable on `id`; can be initialized from a `Workout` via a `SavedWorkout.from(_:title:)` factory.

**Commit:** `feat(saved-workouts): SavedWorkout domain model`

### Task B2 — `SavedWorkoutStore`

**File:** Create `SavedWorkoutStore.swift`.

**Acceptance**
- `all() -> [SavedWorkout]`
- `save(_ workout: SavedWorkout)` — upsert by id
- `delete(id: UUID)`
- `get(id: UUID) -> SavedWorkout?`
- Idempotent: saving the same workout twice yields one entry.
- Survives app restart (round-trip test).

**Test (`SavedWorkoutStoreTests.swift`):** create, save, restart-simulating reload, verify; delete; upsert.

**Commit:** `feat(saved-workouts): local SavedWorkoutStore`

### Task B3 — `ABRotationGuard`

**File:** Create `ABRotationGuard.swift`.

**Acceptance**
- `canPair(_ a: SavedWorkout, with b: SavedWorkout) -> Bool` returns true iff `a.sessionRole == b.sessionRole`.
- Returns `false` and a structured reason for mismatched roles (UI can show "Push A and Legs B can't rotate together").

**Test (`ABRotationGuardTests.swift`):**
- Push A / Push B → ok.
- Push A / Legs B → rejected with `.differentRole(.push, .legs)`.
- Custom-role A and custom-role B with same `.custom("evening-mobility")` → ok.

**Commit:** `feat(saved-workouts): A/B rotation guard by session role`

### Task B4 — `SavedWorkoutScheduler`

**File:** Create `SavedWorkoutScheduler.swift`.

**Acceptance**
- `scheduleIntoArc(savedWorkoutID, on days: [Date]) throws`:
  - replaces the engine-generated workout on those days with the Saved Workout's blueprint
  - marks the day with `source = .savedWorkout(id)` so Agent A's `WaveAdjuster` preserves it
- `unschedule(from day: Date)` returns the day to engine-generated content.
- Conflict: scheduling on a day already holding a customized session prompts the user (don't silently overwrite).

**Test (`SavedWorkoutSchedulerTests.swift`):**
- Schedule onto 3 Arc days, verify day source flips to `.savedWorkout`.
- Unschedule, verify day reverts to engine-generated.
- Customized day collision raises a non-fatal conflict event.

**Commit:** `feat(saved-workouts): Saved Workout scheduling`

### Task B5 — Editor save / replace / schedule UI

**Files:**
- Modify `SessionEditorView.swift` — add three actions in the editor toolbar: Save (opens `SaveWorkoutSheet`), Replace Today (picker over Saved Workouts), Schedule (opens `ScheduleSavedWorkoutSheet`).
- Create `SaveWorkoutSheet.swift` — title + role pre-filled from the current session + a small "Saved on this phone" line (per Decision 4).
- Create `ScheduleSavedWorkoutSheet.swift` — day picker over current Arc.
- Create `SavedWorkoutsListView.swift` — list view from the editor and from Program tab settings.

**Acceptance**
- Save round-trips through `SavedWorkoutStore`.
- Replace-today calls `SavedWorkoutScheduler.scheduleIntoArc(_:on: [today])`.
- Schedule offers only days remaining in the current Arc.
- A/B partnering is offered inline when saving with a matching-role candidate present.

**Test:** ViewModel tests on `SessionEditorViewModel` for each action; visual confirmation via simulator slice in Task B7.

**Commit:** `feat(editor): Save / Replace-Today / Schedule actions`

### Task B6 — Swap sheet batch behavior + Wave 2 chips

**Files:** Modify `ExerciseSwapSheet.swift`, `ProgramOverviewView.swift`.

**Acceptance**
- Swap sheet shows a chip: **Today** (default) / **Keep using** (persists the swap on this scheduled day's slot for the rest of the Arc).
- Swapping 5 exercises in a single editor session yields exactly one confirmation (or zero, if all are "Today").
- Wave 2 adjusted rows show a small revert chip ("Revert this change"). Tapping it calls back into Agent A's `WaveAdjuster.revert(for: blockID)`.
- The chip only appears for `ProgramRationale.revertible == true`.

**Test:** ViewModel test — five swaps in one session emit a single batch confirm event; revert chip dispatches the correct callback.

**Commit:** `feat(editor): swap sheet batch behavior + Wave 2 revert chip`

### Task B7 — Editor walkthrough simulator slice

**File:** Create `EditorWalkthroughTests.swift` (UITests).

**Scenario**
1. Open Program tab on Day 5 of Arc 1.
2. Open today's session editor.
3. Swap one exercise via the swap sheet (Today persistence). Verify no extra confirm.
4. Save the workout as "My Vert Pull A."
5. Schedule "My Vert Pull A" onto Day 12 of Arc 1.
6. Confirm Day 12 now shows the Saved Workout source.
7. Open Day 17 (Wave 2 active) and verify a revert chip is present on any adjusted exercise.

**Acceptance:** all 7 steps pass on simulator.

**Commit:** `test(editor): end-to-end editor walkthrough UI test`

### Task B8 — Saved Workouts list integration

**File:** Modify `ProgramOverviewView.swift`.

**Acceptance**
- The Program tab does not become a library dashboard (per spec).
- Saved Workouts surface lives behind a single "Saved" entry point in the editor and behind a small "library" overflow action in Program tab — not as a permanent top-level card.

**Commit:** `feat(program): minimal Saved Workouts entry points`

---

## Verification (end of phase)

```
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/SavedWorkoutStoreTests \
  -only-testing:UNBOUNDTests/SavedWorkoutSchedulerTests \
  -only-testing:UNBOUNDTests/ABRotationGuardTests \
  -only-testing:UNBOUNDUITests/EditorWalkthroughTests
```

All green = phase done. Hand off to Agent A for full-engine sim suite.
