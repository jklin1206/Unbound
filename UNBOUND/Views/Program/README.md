# Views/Program

All views for the Program tab — training plan display, workout editing, active-session logging, and rank/skill browsing.

## Root files

| File | Description |
|------|-------------|
| `BlockProgressRevealView.swift` | Post-block checkpoint sheet: renders proof signals, a short narrative, and a ShareLink card via `ImageRenderer` |
| `CheckpointFlowSheet.swift` | Multi-step checkpoint flow sheet covering nutrition context, missed-session signals, and body-scan capture |
| `CoachActionsRow.swift` | Structured action chips (DELOAD, TRAVEL, SHORT, etc.) that feed `CoachActionExecutor` for program adjustments |
| `DayDetailView.swift` | Selected-day card showing workout preview, exercise list, and the BEGIN button for the current day |
| `ExerciseDetailSections.swift` | Shared detail sections (muscle groups, body regions, sets/programming) used by both `ExerciseDetailView` and inline `ExerciseLogCard` |
| `ExerciseDetailView.swift` | Standalone full-screen exercise detail using `MovementCatalog` / `MovementResolver` |
| `ExerciseSwapSheet.swift` | Sheet for swapping or adding an exercise in the session draft |
| `NutritionDayView.swift` | Nutrition day panel showing training-day vs rest-day macro targets |
| `ProgramExerciseLibraryView.swift` | Searchable catalog used in add/swap flows to pick a `CatalogExercise` |
| `ProgramFocusSwitchModels.swift` | Data models for the focus-switch surface (`ProgramFocusSwitchPresentation`, selection, clear target) |
| `ProgramFocusSwitchSheet.swift` | Focus-switch sheet — lets the user override training style, equipment, and experience context |
| `ProgramFocusSwitchSheetHelpers.swift` | Stateless view helpers and layout extensions for `ProgramFocusSwitchSheet` |
| `ProgramFuelTargetBand.swift` | Compact nutrition-target band row linking to `NutritionDayView` for a given `ProgramDay` |
| `ProgramOverviewView.swift` | Three-tab surface (PROGRAM / ROUTINES / RANKS) for the user's training plan |
| `ProgramRankLibraryView.swift` | Searchable rank library listing skill and exercise ranks with filter controls |
| `RecoveryView.swift` | Recovery plan display showing sleep target and recovery protocol |
| `ScheduleSavedWorkoutSheet.swift` | Sheet for scheduling a `SavedWorkout` onto one or more program days |
| `SkillBlockPickerSheet.swift` | Sheet for picking a skill node and block kind to add to the session draft |
| `TowerTrialReadyPreview.swift` | Visual floor-stack preview of a tower trial's blocks shown in `WorkoutReadyView` |
| `WhyThisProgramView.swift` | Animated rationale sheet explaining why the current program was generated |
| `WorkoutDetailView.swift` | Full workout detail with exercise list, edit-mode toolbar, and navigation to `WorkoutReadyView` |
| `WorkoutLogSummaryView.swift` | Post-session log summary showing total work sets, volume, and exercise breakdown |

## Subfolders

| Folder | Description |
|--------|-------------|
| `ActiveWorkout/` | Active-session logging container, keypad, top bar, completion footer, and demo harness |
| `MyWorkouts/` | Saved-workouts list, inline list component, schedule sheet, and demo harness |
| `Overview/` | Program week strip, day-action row, command dock, block-complete/rollover, and rank exercise detail views |
| `RankLibrary/` | Rank library drill-down views with data logic, hero, and log sections |
| `RankTrials/` | Trial-mode views: Boss Rush, Daily 100, Final Exam, Finisher, and Operator |
| `Routines/` | Off-day routine cards, challenge card, completion flow, difficulty badge, and helpers |
| `Schedule/` | Program schedule editor views |
| `SessionEditor/` | Workout builder / plan-ahead editor (`SessionEditorView` + extensions + demo harness) |
| `WorkoutReady/` | Pre-workout confirmation screen (`WorkoutReadyView` + extensions for blocks, builder sheets, controls, header) |
