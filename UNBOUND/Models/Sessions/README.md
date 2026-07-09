# Models/Sessions

Workout-session model layer: the live in-workout state machine (`ActiveWorkoutSession`), the planned-session draft/block types it runs from, the persisted logs it produces, and the adapters that convert programs/routines into drafts and logs.

## Files

| File | What it is |
|---|---|
| `ActiveWorkoutSession.swift` | `@MainActor final class ActiveWorkoutSession: ObservableObject` — live in-workout state machine (exercises, current set, elapsed time); also `RepRange` rep-string parsing helper. |
| `ActiveWorkoutSession+CustomExercises.swift` | `appendCustomExercise(_:)` and friends — adding user `CustomExercise`s to a running session with default sets/reps/rest. |
| `ActiveWorkoutSession+LogAssembly.swift` | `assembleWorkoutLog(userId:completedAt:)` etc. — builds the persisted log payloads from finished session state. |
| `ActiveWorkoutSession+Models.swift` | Nested value types on the session, e.g. `ProgressSummary` (logged vs total working sets, completion). |
| `ActiveWorkoutSession+SetLogging.swift` | Set logging plus auto-advance of `currentExerciseIndex`/`currentSetIndex` and exercise-completion marking. |
| `ActiveWorkoutSession+TrainingDraft.swift` | `init(trainingDraft:)` — boots a live session from a `TrainingSessionDraft`, converting blocks to `ActiveExercise`s. |
| `AISession.swift` | `AISession`/`AIExercise`/`AIPrescriptionTarget` — legacy name for a user-contextualized skill session; shape kept so `SkillSessionView` rendering stays stable. |
| `CardioSession.swift` | `CardioType` enum (run/bike/row/...) with display names + `CardioSession` record. |
| `LastPerformanceLookup.swift` | `LastSetPerformance` + `LastPerformanceLookup` — pure lookup of the most-recent prior performance per exercise, built from recent completed `WorkoutLog`s (drives the logger's PREV column and weight prefill). |
| `PerformanceLog.swift` | `PerformanceLog`/`PerformanceBlock` — the persisted record of a completed training session (source, blocks, RPE). |
| `QuickLogDraftFactory.swift` | `QuickLogDraftFactory` (empty draft backing "Quick Log" free workouts) + `SavedWorkoutDraftFactory` (empty draft for saving a reusable template). |
| `RestTimerModel.swift` | `@MainActor final class RestTimerModel: ObservableObject` — date-based rest countdown that survives UI dismissal and app backgrounding. |
| `SavedWorkout.swift` | `SavedWorkout` — a reusable user workout template (title, `TrainingBlock`s, equipment, A/B partner link). |
| `TrainingBlock.swift` | `TrainingBlock` + `TrainingSetPlan` — one planned block inside a draft (kind, skill/routine/cardio link, prescriptions). |
| `TrainingSessionAdaptations.swift` | Adaptation/modifier display model: `TrainingSessionAdaptationKind`, `TrainingSessionAdaptationLine`, `ProgramModifierLine`/`Summary`/`ColorRole`. |
| `TrainingSessionAdapters.swift` | `TrainingSessionAdapters` — converts a planned `Workout` (plus scheduled skill blocks) into a `TrainingSessionDraft`, and back. |
| `TrainingSessionAdapters+Routines.swift` | Routine adapters — builds a `PerformanceLog` from a `RoutineDef` + `RoutineCompletionRecord`. |
| `TrainingSessionDraft.swift` | `TrainingSessionDraft` + the core session enums: `TrainingSessionSource`, `TrainingBlockKind`, `TrainingSide`, `TrainingMetricKind`. |
| `TrainingTarget.swift` | `TrainingTarget` — typed prescription target (reps, range, AMRAP, hold seconds, distance, calories, timed). |
| `Workout.swift` | `Workout` + `Exercise` — a planned program-day workout (warmup/main/cooldown exercise lists). |
| `WorkoutBlock.swift` | `WorkoutBlock` — a section of a planned workout with `Kind` (warmup/main/accessory/cooldown/skill). |
| `WorkoutLog.swift` | `WorkoutLog`/`ExerciseLogEntry`/`SetLog` — persisted per-program-day workout log keyed by program id + day number. |

## Where to find X

- **Live in-workout state (current exercise/set, logging a set):** `ActiveWorkoutSession.swift` + its `+SetLogging` / `+Models` extensions
- **The planned session before it starts:** `TrainingSessionDraft.swift` (draft + enums), `TrainingBlock.swift` (blocks), `TrainingTarget.swift` (set targets)
- **What gets persisted when a session ends:** `PerformanceLog.swift` (current shape), `WorkoutLog.swift` (program-day log), assembled in `ActiveWorkoutSession+LogAssembly.swift`
- **Converting a program workout or routine into a draft/log:** `TrainingSessionAdapters.swift` and `TrainingSessionAdapters+Routines.swift`
- **Rest timer behavior:** `RestTimerModel.swift`
- **User workout templates and Quick Log:** `SavedWorkout.swift`, `QuickLogDraftFactory.swift`
