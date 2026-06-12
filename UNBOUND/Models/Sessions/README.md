# Models/Sessions

Workout-session data models: the persisted log records, live-session state machine, draft construction helpers, and ancillary per-session models (rest timer, cardio, AI-prescribed sessions).

| File | Purpose |
|------|---------|
| `ActiveWorkoutSession.swift` | `@MainActor` observable that owns live-workout state, set logging, and progress tracking during an in-progress session |
| `ActiveWorkoutSession+LogAssembly.swift` | Extension that assembles a completed `WorkoutLog` from the live `ActiveWorkoutSession` at finish time |
| `AISession.swift` | Legacy model for a user-contextualized, RPE-adjusted skill session surfaced by `SkillSessionView` |
| `CardioSession.swift` | `CardioType` enum and `CardioSession` model representing a logged cardio effort (run, bike, row, etc.) |
| `PerformanceLog.swift` | Persisted record of a completed training session — the canonical write-once log stored to the backend |
| `QuickLogDraftFactory.swift` | Factory enums (`QuickLogDraftFactory`, `SavedWorkoutDraftFactory`) that build blank `TrainingSessionDraft` values for free-form and template sessions |
| `RestTimerModel.swift` | `@MainActor` singleton countdown timer with date-based state so it survives app backgrounding and screen transitions |
| `SavedWorkout.swift` | User-saved reusable workout template consisting of ordered `TrainingBlock`s |
| `TrainingBlock.swift` | One logical section of a session (warmup / main / skill / cardio), carrying prescriptions and optional skill/routine links |
| `TrainingSessionAdaptationSummary.swift` | Value types describing how a program day was adapted (travel, deload, substitution, etc.) for the coaching surface |
| `TrainingSessionAdapters.swift` | Static helpers converting `Workout` and program data into `TrainingSessionDraft` values |
| `TrainingSessionAdapters+RoutineAdapters.swift` | Extension adding adapter logic for routine-based sessions and their `PerformanceLog` assembly |
| `TrainingSessionDraft.swift` | Mutable pre-session draft — `TrainingSessionSource`, `TrainingBlockKind`, and the full `TrainingSessionDraft` struct passed into `ActiveWorkoutSession` |
| `TrainingSessionEditSupport.swift` | `TrainingSessionEditPersistence` enum powering mid-session exercise swap/substitution options |
| `Workout.swift` | Program-generated workout value — a named list of `Exercise` objects organized into warmup/main/cooldown |
| `WorkoutBlock.swift` | Structured block (warmup/main/accessory/cooldown/skill) used inside `SavedWorkout`, with prescriptions and optional skill links |
| `WorkoutLog.swift` | Codable log of a completed workout keyed to a program day, storing `ExerciseLogEntry` records |

## Where to find X

| Task | File |
|------|------|
| Read or write the permanent workout history record | `PerformanceLog.swift` |
| Drive live set-by-set logging during a workout | `ActiveWorkoutSession.swift` |
| Build the blank draft that starts a Quick Log or template session | `QuickLogDraftFactory.swift` |
| Control the rest-countdown timer between sets | `RestTimerModel.swift` |
| Understand how a program workout becomes a launchable session | `TrainingSessionAdapters.swift` |
| Inspect or edit what a session block contains | `TrainingBlock.swift` / `WorkoutBlock.swift` |
