# Program/MyWorkouts

The "Workouts" sub-tab: list-first saved-workouts surface where the saved workouts are the content and Quick Log / Create Workout are small secondary actions.

## Files

| File | What it is |
|---|---|
| `MyWorkoutsView.swift` | `MyWorkoutsView` — the sub-tab root: saved list + Quick Log + Create Workout actions. |
| `SavedWorkoutsInlineList.swift` | Inline (no modal chrome) saved-workouts list backed by `SavedWorkoutStore`; delete + Squad-share handled locally, start/schedule bubble up to the parent. |
| `ScheduleWorkoutDateSheet.swift` | Date picker shown when tapping Schedule on a saved workout; parent places it on the chosen day and jumps to the PROGRAM tab. |
| `MyWorkoutsDemoHarness.swift` | Verification harness via `-myWorkoutsDemo` launch arg; mirrors production Quick Log → active workout and Build → SessionEditor → active workout flows. |

## Where to find X

- **Saved workout rows (delete / share / start / schedule)** → `SavedWorkoutsInlineList.swift`.
- **Scheduling a saved workout to a day** → `ScheduleWorkoutDateSheet.swift` (sheet) — placement is applied by the parent.
- **Quick Log / Create Workout entry points** → `MyWorkoutsView.swift`.
- **Screenshot/verify on sim** → `MyWorkoutsDemoHarness.swift` (`-myWorkoutsDemo`).
