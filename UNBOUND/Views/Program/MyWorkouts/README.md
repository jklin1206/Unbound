# Program/MyWorkouts

The "Workouts" sub-tab: list-first saved-workouts surface where the saved workouts are the content and Quick Log / Create Workout are small secondary actions.

## Files

| File | What it is |
|---|---|
| `MyWorkoutsView.swift` | `MyWorkoutsView` — the sub-tab root: saved list + Quick Log + Create Workout actions. |
| `SavedWorkoutsInlineList.swift` | Inline (no modal chrome) saved-workouts list backed by `SavedWorkoutStore`; title-first drop-down cards with exercise previews, Start + share/edit/delete actions; delete + Squad-share handled locally, start/edit bubble up to the parent. |
| `LoadoutExercisePreview.swift` | A loadout's exercises in the daily-card row style (`ProgramVisualExerciseRow` with art thumbnails); capped preview or full list; shared by the Loadouts tab list and `DayLoadoutPickerSheet`. |
| `MyWorkoutsDemoHarness.swift` | Verification harness via `-myWorkoutsDemo` launch arg; mirrors production Quick Log → active workout, Build → SessionEditor → active workout, and edit-in-place flows. |

## Where to find X

- **Saved workout rows (start / share / edit / delete)** → `SavedWorkoutsInlineList.swift`.
- **Placing a loadout on a program day** → `DayLoadoutPickerSheet.swift` (Overview) or the month planner — day-side flows, not this directory.
- **Quick Log / Create Workout entry points** → `MyWorkoutsView.swift`.
- **Screenshot/verify on sim** → `MyWorkoutsDemoHarness.swift` (`-myWorkoutsDemo`).
