# Workout Logging Redesign v2 — Design Spec

**Date:** 2026-05-17
**Supersedes:** the logging-flow portions of `2026-05-16-workout-logging-redesign-design.md`
**Branch:** `program-redesign` · UNBOUND iOS

## Context

Sub-project A shipped a *focused one-set-at-a-time* logger + a *full-screen*
rest timer. On device, jlin rejected both: the one-set model feels wrong —
he wants the classic block/grid logger ("like it used to be"), the full-screen
rest takeover is too heavy, and the adjacent exercise-detail screen reads
"weird and non-premium" (a giant wrapping monospace "15 each direction").
This v2 reworks the **view layer** to a block/grid logger with an inline
per-set RPE traffic-light, a dismissible rest pop-up that notifies, and a
premium exercise-detail screen — while keeping the tested core intact.

A separate pre-existing bug (program never persisted → "No program yet") was
root-caused and fixed this session (`41ff444`, detached-task persistence) and
is **out of scope here**.

## Locked decisions (from brainstorming dialogue)

1. **Block/grid logger, one scroll.** Each exercise is a card; its X sets are
   rows. All exercises stacked in one scrollable session; log any set in any
   order; one `COMPLETE SESSION` at the bottom. (The classic full-session
   logger.)
2. **Per-set RPE = real numeric 6–10 scale (REVISED — supersedes the
   traffic-light dot).** The set row is `SET · WEIGHT · REPS · RPE · ✓`:
   - **✓ is the log control** — tap to log the set. Logging never requires
     RPE.
   - **RPE is its own optional value cell** between REPS and ✓: shows the
     chosen number or "—". Tap it → an `RPEPickerSheet` listing **6, 7, 8, 9,
     10** each with its reps-in-reserve meaning (10 = nothing left, 9 = 1 rep
     left, 8 = 2, 7 = 3, 6 = 4+), plus "Clear". This is the real
     strength-training RPE scale minus the dead 1–5 range; the in-picker
     meanings are the "explain it well" requirement.
   - Column header row reads `SET WEIGHT REPS RPE`.
   - **Retired:** the traffic-light dot, the `Effort` enum, and `EffortRPEMap`
     (+ its tests). `ActiveSet` stores `rpe: Int?` directly (the underlying
     `SetLog.rpe` is already `Int?`), passed straight through —
     `assembleWorkoutLog` uses `set.rpe`, no Effort→Int mapping.
3. **Auto-progression signal:** primary = reps logged vs the prescribed rep
   target (zero user action); the optional per-set numeric RPE *refines* it,
   fed straight to the existing ProgressionEngine via `SetLog.rpe: Int?`.
4. **No "previous session" display.** Drop the ghost/prev column. Input fields
   still *prefill* a sensible starting value (working weight) but the row
   shows no "prev 80×8" reference.
5. **Rest = dismissible pop-up + notify.** Logging a set starts a compact
   countdown card that slides up from the bottom; the grid stays visible and
   usable behind it. A close (✕) dismisses the card but the timer keeps
   running. At zero: haptic **and** a local notification (pings even if the
   app is backgrounded / phone locked). First use requests notification
   authorization. `+30s` supported. Auto-duration from the exercise's
   prescribed rest via the existing `RestPrescription`.
6. **Exercise-detail screen redesigned premium.** The Target Muscles /
   Programming / Form Cues screen (`WorkoutDetailView`) is reworked: no giant
   wrapping monospace, real type hierarchy and spacing, on-brand, restrained.
7. **New onboarding RPE sandbox step ("try the app").** A dedicated slide that
   is a real mini logging session, not a passive demo: an example **Bench
   Press with 3 sets**, rendered with the ACTUAL production `ExerciseLogCard`
   /`SetLogGridRow` components backed by a throwaway in-memory
   `ActiveWorkoutSession`, prefilled (e.g. 60kg×8) so the user can immediately
   log all 3 sets (✓) and tap the RPE cell to pick a number from the **6–10
   scale with the reps-in-reserve meanings shown** — this is where RPE is
   actually taught. Cells are tappable to edit (real stepper). Copy explains
   the scale (reps-left framing) and the reinforcement line updates after
   they've logged all 3. Continue ("GOT IT") is always tappable (non-blocking)
   with a gentle nudge until first interaction — onboarding must never trap
   the user.

## What survives from the sub-project A build (do NOT rebuild)

- `ActiveWorkoutSession` (Models) — state machine already models
  `exercises[].sets[]` with `weightKg/reps/effort/logged`; backs the grid
  directly. Reused as-is. Tested.
- `WorkoutDraftStore` — autosave/resume. Reused as-is. Tested.
- `SetPrefill` — still used to prefill the *input value* from working weight;
  the "prev" ghost is simply not rendered. Reused. Tested.
- `EffortRPEMap` — green/yellow/red ↔ `.easy/.solid/.hard` ↔ Int RPE. Reused.
  Tested.
- `RestPrescription` — rest seconds per exercise. Reused. Tested.
- `ExerciseOverflowMenu` (`OverflowIntent`) — the `⋯` (warmup/notes/swap/
  add-remove/skip). Reused.
- `StepperControl` — reused as the tap-to-edit editor for a weight/reps cell.
- Byte-compatible `WorkoutLog`/`ExerciseLogEntry`/`SetLog` →
  `services.workoutLog.saveLog` + its 11-step cascade — unchanged, so
  rewards/skills/ranks/sub-project B stay intact. The reward-trigger
  reproduction in the container is preserved verbatim.

## What gets reworked / removed

- **Remove:** `ActiveSetView` (one-set focused screen), `RestTimerView`
  (full-screen takeover), `ExerciseDotNavigator` (no set-by-set paging in a
  grid). Retire after the new flow reaches parity.
- **Rework:** `ActiveWorkoutContainerView` — hosts the grid + the rest pill
  overlay instead of a `.set`/`.rest` phase swap; keeps `loadContext`,
  draft autosave on every mutation, and the `complete()` → `saveLog` →
  reward-trigger path exactly as reviewed/approved.

## Architecture (new/changed units)

- **`WorkoutLogGridView`** — the session: `ScrollView` of `ExerciseLogCard`s
  + a pinned/bottom `COMPLETE SESSION`. Reads/writes `ActiveWorkoutSession`.
- **`ExerciseLogCard`** — one exercise: header (name + `ExerciseOverflowMenu`),
  a column-header row `SET · WEIGHT · REPS · RPE`, the set rows, `+ add set`.
- **`SetLogGridRow`** — one set: set number; tappable WEIGHT cell and REPS
  cell (tap opens `StepperControl` to edit, compact value shown otherwise);
  the **RPE tap-dot** (empty → log@solid; tap filled → cycle green/yellow/red).
  Writes through `ActiveWorkoutSession.logCurrentSet`/`setEffort` (extended
  to address an arbitrary exercise/set index, since logging is now any-order
  — see Data model note).
- **`RestTimerPill`** — compact bottom card: countdown, `+30s`, `✕`. Owned by
  the container; survives its own dismissal (timer state in the container/a
  small timer model, not the view). At zero → `UnboundHaptics` + a scheduled
  `UNUserNotificationCenter` local notification. Cancels the pending
  notification if a new set is logged (restarting rest) or the workout
  completes.
- **`RestNotifier`** — thin wrapper around `UNUserNotificationCenter`:
  `requestAuthIfNeeded()`, `schedule(after:)`, `cancelPending()`. Pure-ish,
  unit-testable (auth state + scheduling logic behind a protocol seam).
- **`RPEOnboardingStep`** — one onboarding screen: explains 🟢🟡🔴, an
  interactive sample dot the user taps through all three, a `Continue`.
  Inserted into the existing onboarding router/flow.
- **Exercise-detail redesign** — rework the `WorkoutDetailView` body
  (Target Muscles / Programming / Form Cues) to premium per the design bar;
  no logic change to how it launches logging (it already points at the
  container from T12).

### Data model note

`ActiveWorkoutSession` currently mutates "current" indices. The grid logs
any set in any order, so add index-addressed mutators:
`logSet(exerciseIndex:setIndex:weightKg:reps:)`,
`setEffort(exerciseIndex:setIndex:_:)`, `cycleEffort(exerciseIndex:setIndex:)`,
plus a derived default-on-log effort = `.solid`. Existing current-index
methods stay (harmless) but the grid uses the index-addressed ones. This is
additive; existing tests stay green; new tests cover the index-addressed
mutators + the cycle order (nil→solid on log, then easy→solid→hard cycle).

## Design bar (non-negotiable — carries over verbatim)

Premium-native, materials/depth/springs, quiet-default (violet only on the
primary signal), tokens only (`Color.unbound.*`, `Font.unbound.*`),
`UnboundHaptics`. Specifics:
- The grid row is **dense but legible**: tap targets ≥44pt, value text mono,
  nothing < 13pt, the RPE dot a clear ≥28pt circle, color states obviously
  distinct (use `success`/`warning`/`alert` family but tuned, not garish).
- Logging a set is the satisfying beat: dot fill = spring + one `success`
  haptic. No prose anywhere in the grid.
- Rest pill: calm, compact, one accent; slide-up spring; never blocks the
  grid; `✕` always reachable.
- Exercise-detail: kill the giant mono wrap; numbers in `monoM`/`monoL` at
  sane sizes, labels in `captionS`, generous 8pt-grid spacing, cards with
  depth not flat boxes.
- Onboarding RPE step: one screen, cinematic-restrained, the sample dot is
  the hero, ≤ 2 short lines of copy.
- `prefers-reduced-motion` → fades only, haptics kept.
- Definition of done per UI task: builds, on-device screenshot reviewed
  against this bar, reads premium not generic.

## Testing / verification

- New unit tests: `ActiveWorkoutSession` index-addressed mutators + effort
  cycle order; `RestNotifier` (auth-needed gating, schedule/cancel logic
  behind a protocol seam). Existing 27 tests stay green.
- `xcodebuild … test` on iPhone 17 — only the known pre-existing
  `SquadMissionServiceTests` flap may fail; zero new failures. (SourceKit
  cross-file noise ignored.)
- On-device (jlin-driven, real signed-in account with a persisted program):
  Program → exercise (premium detail) → Log Workout → grid; log sets in any
  order; RPE dots cycle; rest pill appears/dismissable/notifies + haptic;
  COMPLETE → existing reward sheet still fires; a row lands in Supabase
  `workout_logs`. Onboarding RPE step shows in the onboarding flow.
- Parity guard: a logged session produces an equivalent `WorkoutLog` and the
  same cascade side-effects as before.

## Out of scope

Rewards choreography (sub-project B), skill→program (C/D), skill visuals (E),
program *generation* (the persistence bug is already fixed separately),
supersets/circuits, Apple Watch.

## Execution

Subagent-driven (fresh subagent/task, spec-then-quality review at cluster
seams), Sonnet minimum, frequent commits, co-authored trailer.
