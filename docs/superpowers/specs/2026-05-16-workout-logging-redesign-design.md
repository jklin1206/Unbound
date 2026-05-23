# Sub-project A — Workout Logging Redesign (Focused Active-Set Flow)

## Context

UNBOUND's workout logging is the spine of the app — skill XP, rank-ups, the
post-workout reward payoff, and (later) skill→program rebalancing all hang off
"a clean logged workout." Today it is the weakest surface:

- `SetLogRow` packs ~5 interactive zones into a 26px row (gloved-gym friction).
- Three modals (swap / custom-exercise / reward) compete during a session.
- No rest timer in program workouts at all (`Exercise.restSeconds` is loaded
  but never used; a rest timer only exists in the unrelated RoutinePlayerView).
- Session summary is retrospective — no live clock/among-sets feedback.
- Weight prefills once per exercise, not per set from last session.
- A mid-session crash or network drop loses the entire workout.
- Zero test coverage on `WorkoutLoggingViewModel` / `WorkoutLogService`.
- `ProgramOverviewView` is 3478 lines; `WorkoutLoggingView` is 584 lines of
  nested `Binding(get:set:)` chains.

This is sub-project **A** of a 5-part Program/Skills overhaul (A logging → B
post-workout rewards → C skill knowledge base → D skill→program engine → E
skill visuals). Each ships its own spec→plan→build→iterate cycle. A is first
because everything else depends on a clean, tested logged-workout path.

**Outcome:** replace the logging surface with a focused, one-thing-on-screen
"active-set" flow that is glove-simple, auto-times rest, autosaves, and is
fully unit-tested — while keeping the existing `WorkoutLogService.saveLog`
cascade byte-compatible so sub-project B (rewards) can wire in cleanly later.

## Locked Decisions (from brainstorming)

1. **Interaction model:** Focused active-set flow. One big current-set screen:
   exercise · "Set X of Y" · prev ghost · weight/reps steppers · one LOG SET.
   Dot navigator (`••●•`) + session clock to jump exercises.
2. **Rest timer:** Auto full-screen countdown after LOG SET. Default from the
   exercise's rest target; fallback ~150s compound / ~90s isolation. Skip and
   +30s. Auto-dismisses to the next set at zero.
3. **RPE/extras:** Default screen = weight + reps + LOG only. After a set is
   logged, an inline 3-tap effort chip (Easy / Solid / Hard) maps to an RPE
   value the existing ProgressionEngine consumes. Warmup flag, per-exercise
   notes, swap exercise, add/remove set, skip exercise all live behind a single
   "⋯" overflow menu.
4. **Draft safety:** Every logged set autosaves the in-progress session
   locally. On relaunch, "Resume your workout?" restores it intact. Supabase
   save still happens only on COMPLETE SESSION.

## Scope

**In:** the in-workout logging experience and its local-draft safety.
**Out (explicit):** reward choreography (sub-project B — keep the existing
`rewardSummary` hook working but unchanged), skill→program (C/D), skill visuals
(E), program *generation*, supersets/circuits (note as future), Apple Watch.

## Architecture

New focused flow in its own files; old `WorkoutLoggingView` retired only after
screenshot parity is verified. The `WorkoutLog`/`ExerciseLogEntry`/`SetLog`
models and `WorkoutLogService.saveLog` + its 11-step cascade are **unchanged**.

### New units (each one clear responsibility, independently testable)

- **`ActiveWorkoutSession`** (ObservableObject, plain state machine) — the
  single source of truth during a workout: ordered exercises, per-exercise
  logged sets, current exercise/set index, start time, effort per set. Pure
  logic (advanceSet, jumpToExercise, addSet, skipExercise, assembleWorkoutLog).
  No SwiftUI. Replaces the binding-hell ViewModel. **Heavily unit-tested.**
- **`WorkoutDraftStore`** — local persistence (Codable snapshot of
  `ActiveWorkoutSession` to app-support file). `save(session)` debounced after
  each logged set; `resumeIfAvailable() -> ActiveWorkoutSession?`; `clear()`
  on COMPLETE or explicit discard. **Unit-tested** (save→load round-trip,
  stale-draft handling, clear).
- **`SetPrefill`** — given an exercise + history, returns per-set
  prefill/ghost (weight, reps) from the **last actual logged session** for that
  exercise name; falls back to the existing working-weight service; nil-safe.
  **Unit-tested.**
- **`RestPrescription`** — `restSeconds(for: Exercise) -> Int`: use
  `Exercise.restSeconds` when present/sane; else classify compound vs isolation
  (reuse the existing equipment/muscle-group heuristic from
  ProgramGeneration's `ExerciseEquipmentClassifier`/muscle data) → 150 / 90.
  **Unit-tested.**
- **`EffortRPEMap`** — Easy/Solid/Hard → RPE doubles the ProgressionEngine
  already expects (e.g. Easy 6.5 / Solid 8 / Hard 9.5; final numbers in plan).
  Pure function. **Unit-tested.**

### New views

- **`ActiveWorkoutContainerView`** — fullScreenCover host; owns the
  `ActiveWorkoutSession`, wires draft autosave, routes between active-set and
  rest states, handles COMPLETE.
- **`ActiveSetView`** — the focused current-set screen (exercise, Set X/Y,
  prev ghost, big weight/reps steppers, LOG SET, post-log effort chip, dot
  navigator + clock, "⋯" menu).
- **`RestTimerView`** — full-screen draining ring countdown, skip / +30s,
  auto-advance. Adapt the proven ring/countdown from `RoutinePlayerView`
  (don't reinvent).
- **`ExerciseDotNavigator`** — `••●•` strip + session clock; tap a dot to jump.
- **`ExerciseOverflowMenu`** — warmup toggle, notes, swap (reuse existing
  `ExerciseSwapSheet`), custom exercise (reuse `CustomExerciseBuilderView`),
  add/remove set, skip exercise. Relocates existing entry points; does not
  rebuild those sheets.

### Data flow

Start (`WorkoutDetailView` "Log Workout") → if a draft exists, "Resume?" →
else build `ActiveWorkoutSession` from the planned `Workout` (exercises, sets,
target reps, restSeconds) with `SetPrefill` ghosts → per set: adjust steppers →
LOG SET (haptic) → record set → effort chip → `RestTimerView` (auto from
`RestPrescription`) → on finish/skip advance → `WorkoutDraftStore.save` →
… → COMPLETE SESSION → confirm if sets remain → `ActiveWorkoutSession`
assembles the **same `WorkoutLog`** shape → `WorkoutLogService.saveLog`
(unchanged cascade) → on success `WorkoutDraftStore.clear()` → existing reward
sheet path fires unchanged (B rewires it later).

### Reuse (do not rebuild)

`WorkoutLog`/`ExerciseLogEntry`/`SetLog`; `WorkoutLogService.saveLog` + cascade;
RoutinePlayerView rest-ring pattern; working-weight service (prefill fallback);
`ExerciseEquipmentClassifier`/muscle data (compound vs isolation);
`UnboundHaptics` (soft press / medium log / success complete / tick stepper);
`ExerciseSwapSheet` + `CustomExerciseBuilderView` (relocated, not rewritten).

## Critical files

- Create: `UNBOUND/Models/ActiveWorkoutSession.swift`
- Create: `UNBOUND/Services/WorkoutLog/WorkoutDraftStore.swift`
- Create: `UNBOUND/Services/WorkoutLog/SetPrefill.swift`
- Create: `UNBOUND/Services/WorkoutLog/RestPrescription.swift`
- Create: `UNBOUND/Models/EffortRPEMap.swift`
- Create: `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift`
- Create: `UNBOUND/Views/Program/ActiveWorkout/ActiveSetView.swift`
- Create: `UNBOUND/Views/Program/ActiveWorkout/RestTimerView.swift`
- Create: `UNBOUND/Views/Program/ActiveWorkout/ExerciseDotNavigator.swift`
- Create: `UNBOUND/Views/Program/ActiveWorkout/ExerciseOverflowMenu.swift`
- Modify: `UNBOUND/Views/Program/WorkoutDetailView.swift` (swap the
  `showLogging` fullScreenCover target to `ActiveWorkoutContainerView`; add
  resume entry)
- Modify: `UNBOUND/Views/Program/ProgramOverviewView.swift` (surface the
  "Resume your workout?" affordance when a draft exists — minimal, no refactor)
- Retire after parity: `UNBOUND/Views/Program/WorkoutLoggingView.swift`,
  `UNBOUND/ViewModels/WorkoutLoggingViewModel.swift`,
  `UNBOUND/Views/Components/SetLogRow.swift`
- Reuse as-is: `Models/WorkoutLog.swift`, `Services/WorkoutLog/WorkoutLogService.swift`,
  `Views/Program/ExerciseSwapSheet*`, `Views/.../CustomExerciseBuilderView`,
  `Views/Routine/RoutinePlayerView.swift` (pattern source),
  `Utilities/Extensions/View+UnboundStyle.swift` (UnboundHaptics)

## Design system & quality bar (non-negotiable)

This screen is used mid-set, sweaty, sometimes gloved, under fatigue. It must
feel like a **premium training instrument**, not a form. Reference language:
Whoop / Oura / Eight Sleep restraint × UNBOUND cinematic violet-on-black.
Implementation uses the **frontend-design** skill discipline; every view is
reviewed against this bar before its task is marked complete.

**Hard rules (from project memory):**
- Premium-native, NOT brutalist boxes — materials, depth, springs; never flat
  sharp rectangles. Use the app's existing `Color.unbound.*` tokens and
  `Font.unbound.*` scale; introduce no new palette.
- Quiet-default / dramatic-moments: the logging screen is *restrained* (charcoal
  surfaces, violet used only on the primary action + active state). Drama is
  reserved for the rest-timer ring and (later, sub-project B) the reward
  sequence. No confetti, no gradients-for-decoration here.
- Locked full-presence components, not pill soup. The LOG SET button and the
  steppers are the heroes; secondary affordances recede.

**Concrete specs the implementer must hit:**

- **Layout & rhythm:** one 8pt-grid column, generous vertical breathing room,
  thumb-reachable primary action in the bottom third. Steppers sized for a
  gloved tap (≥56pt hit targets, value type ≥34pt mono). Nothing on the active
  screen smaller than 13pt. Safe-area aware; no clipped controls in landscape.
- **Hierarchy:** exercise name (display) → "Set X of Y" + prev ghost (muted,
  mono) → the two steppers (dominant) → LOG SET (primary, full-width, violet,
  weighted). Everything else (dots, clock, ⋯) is tertiary and edge-parked.
- **The stepper:** custom component — large central value, ▲/▲ affordances with
  rigid `tick` haptic per increment, long-press to repeat, tap value to type.
  Sensible step sizes (weight 2.5kg/5lb, reps 1). Never a tiny TextField.
- **LOG SET:** the satisfying beat. Press = soft haptic + 0.97 scale; release =
  medium/`success` haptic, a brief violet bloom on the button, the set row
  "banks" with a spring (the just-logged set animates into the dot strip / a
  thin completed-set ledger). This is the dopamine micro-moment — get it right.
- **Rest timer (the one allowed quiet-drama):** full-screen, near-black, a
  single large draining ring (adapt RoutinePlayerView's ring), big mono
  countdown, "next: <exercise> set N" beneath, skip / +30s as low-emphasis
  text buttons. Last 3 seconds: ring pulses, soft ticks, then a single
  `success` haptic and a spring transition straight into the next set. It
  should feel like a held breath, not a kitchen timer.
- **Effort chip:** appears inline only *after* LOG SET, 3 segments
  (Easy/Solid/Hard), one tap, then it collapses. Selected = filled violet;
  never modal, never blocking.
- **Transitions:** set → rest → next set is one continuous choreographed motion
  (matched-geometry / spring, ~0.35s, `EASE` cubic), never a hard cut or a
  sheet pop. Exercise jumps via the dot strip cross-fade. `prefers-reduced-
  motion` collapses motion to fades, keeps haptics.
- **States designed, not afterthoughts:** first set (no prev ghost), last set
  of last exercise (LOG SET → "FINISH" treatment), skipped exercise, resumed
  draft ("Resume your workout?" is a calm restore, not an alert), zero-input
  guard, COMPLETE with sets remaining (graceful confirm, not a scold).
- **Motion/haptic budget:** every primary action has exactly one haptic; no
  haptic spam. Animations are spring, interruptible, 60fps on device.

**Definition of done for any UI task:** builds, matches these specs, reviewed
on-device via screenshot at the active-set / rest / effort / complete states,
and passes a side-by-side restraint check (does day-to-day logging stay quiet;
is the only "moment" the rest ring). A task is not complete if it looks like a
generic form.

## Testing / verification

- **TDD** on the pure units: `ActiveWorkoutSession` (advance/jump/add/skip/
  assembleWorkoutLog), `WorkoutDraftStore` (round-trip, clear, stale draft),
  `SetPrefill` (last-session > working-weight > nil), `RestPrescription`
  (explicit > classified), `EffortRPEMap`. New tests under
  `UNBOUNDTests/Services/WorkoutLog/` and `UNBOUNDTests/Models/`.
- `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test`
  must pass (authoritative; SourceKit cross-file noise ignored per project rule).
- Install to iPhone 17 sim → screenshot the active-set screen, rest timer, and
  COMPLETE → confirm a row lands in Supabase `workoutLogs` and the existing
  reward sheet still appears (regression guard for sub-project B).
- Parity check: a logged session through the new flow produces a `WorkoutLog`
  equivalent to the old flow (same cascade side-effects fire).

## Execution

Subagent-driven development (fresh subagent per task, spec-compliance then
code-quality review), Sonnet minimum per project rule. Branch:
`program-redesign` (canonical). Frequent commits, co-authored trailer.
