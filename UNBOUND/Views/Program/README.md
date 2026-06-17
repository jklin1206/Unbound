# Views/Program

The Program tab: the three-tab training-plan surface (`ProgramOverviewView`) plus day/workout/exercise detail screens, the editor and pre-workout flows, and supporting sheets.

## Subfolders

| Folder | What lives there |
| --- | --- |
| `ActiveWorkout/` | Live in-workout logging surface — container view, exercise log cards, set grid, rest timer, keypad, trial stages (tower ascent, deck of proof). |
| `MyWorkouts/` | My Workouts tab — saved-workout list, inline list component, schedule-date sheet, demo harness. |
| `Overview/` | Internals behind `ProgramOverviewView` — overview state machine, day-panel resolvers/previews, command dock, block rollover/complete, focus-switch coordinator, dev simulation. |
| `RankLibrary/` | Rank library detail layer — exercise rank detail view, row/models, proof + ruler visuals, target body figure. |
| `RankTrials/` | Rank-trial mode screens — boss rush, daily 100, final exam, finisher, threshold raid, operator ready/active visuals. |
| `Routines/` | Routines tab — challenge cards, preview sheet, completion flow, travel overlay, helpers. |
| `Schedule/` | Program schedule editor views. |
| `SessionEditor/` | Workout builder/editor sheet (`SessionEditorView` + extensions, demo harness) — see its README. |
| `WorkoutReady/` | Pre-workout review/launch screen (`WorkoutReadyView` + extensions) — see its README. |

## Root files

| File | What it is |
| --- | --- |
| `BlockProgressRevealView.swift` | Block-complete sheet rendering a fresh `ScanDeltaReport` — checkpoint proof signals, short narrative, shareable card via `ImageRenderer` + `ShareLink` (no match-percent / setback UI by design). |
| `CheckpointFlowSheet.swift` | Checkpoint flow sheet driven by `CheckpointFlow` — collects standards attempted/cleared, pain/form-breakdown flags, free text; commits a `CheckpointOutcome` or hands off to body scan. |
| `CoachActionsRow.swift` | Structured action chips for program adjustments (DELOAD / TRAVEL / SHORT) feeding `CoachActionExecutor`; swaps deliberately live in SessionEditorView instead. |
| `DayDetailView.swift` | Preview screen for a `ProgramDay` — workout, nutrition, recovery; optional `ProgramViewModel` enables the edit toolbar, with wave-adjustment undo hooks. |
| `ExerciseDetailSections.swift` | Field-based detail sections (muscles, programming, form cues, substitution) shared by `ExerciseDetailView` and the inline expansion in `ExerciseLogCard`. |
| `ExerciseDetailView.swift` | Standalone exercise detail screen for an `Exercise`, resolving its `MovementDefinition` via `MovementResolver`/`MovementCatalog`. |
| `ExerciseSwapSheet.swift` | Add/swap sheet picking a replacement from `CatalogExercise` alternatives, with preference statuses, equipment filter, and create-custom hook. |
| `NutritionDayView.swift` | Day nutrition screen for a `NutritionPlan` with optional `DayNutrition` override and a training-day / rest-day toggle. |
| `ProgramExerciseLibraryView.swift` | Full exercise-library browser variant of add/swap — same `CatalogExercise` selection contract as `ExerciseSwapSheet`. |
| `ProgramFocusSwitchModels.swift` | Model types for the focus switch — `ProgramFocusSwitchPresentation`, `ProgramFocusSwitchClearTarget` (daily / pending next-block), and related selection enums. |
| `ProgramFocusSwitchSheet.swift` | Sheet for switching training focus (style/equipment/experience) with mode + scope choices, apply/clear callbacks, and applying/error state. |
| `ProgramFocusSwitchSheet+Sections.swift` | Section builders for the focus-switch sheet — active/pending context control cards and rails. |
| `ProgramFuelTargetBand.swift` | Compact fuel-target band for a `ProgramDay`; NavigationLink into `NutritionDayView`. |
| `ProgramOverviewView.swift` | Root three-tab Program surface: PROGRAM (week strip + selected-day card), ROUTINES, RANKS; day tiles open `DayDetailView` preview-first. |
| `ProgramRankLibraryView.swift` | Rank library list screen — searchable, filterable `ProgramRankLibraryRow`s opening into the RankLibrary detail views. |
| `RecoveryView.swift` | Recovery plan screen — sleep-target card and activities list for a `RecoveryPlan`. |
| `TowerTrialReadyPreview.swift` | Tower-trial preview visual — floor list + tower silhouette built from the trial's `TrainingBlock`s. |
| `WhyThisProgramView.swift` | "Why this program" explainer rendering a `ProgramRationale` (hero + summary blocks). |
| `WorkoutDetailView.swift` | Workout detail screen; optional `ProgramViewModel` enables edit mode (swap exercises, adjust sets) persisting to the program doc, and it can launch WorkoutReady. |
| `WorkoutLogSummaryView.swift` | Completed-workout summary for a `WorkoutLog` — total work sets, reps, and per-exercise breakdown in the user's weight unit. |
