# Program/MyWorkouts

"Workouts" sub-tab: browse and launch saved workouts, quick-log, build new workouts, and schedule a saved workout onto a calendar day.

| File | Purpose |
|------|---------|
| `MyWorkoutsView.swift` | Top-level sub-tab view with Quick Log + Create Workout action buttons above `SavedWorkoutsInlineList` |
| `SavedWorkoutsInlineList.swift` | Flat inline list of saved workouts from `SavedWorkoutStore` with delete and squad-share handling |
| `ScheduleWorkoutDateSheet.swift` | Calendar day-picker sheet for placing a saved workout on a specific date |
| `MyWorkoutsDemoHarness.swift` | DEBUG-only harness (`-myWorkoutsDemo`) for verifying the sub-tab end-to-end |

## Where to find X

| Task | File |
|------|------|
| Change the Quick Log or Create Workout button appearance | `MyWorkoutsView.swift` |
| Edit saved-workout row layout or swipe actions | `SavedWorkoutsInlineList.swift` |
| Modify the schedule date picker | `ScheduleWorkoutDateSheet.swift` |
| Verify the sub-tab in isolation | `MyWorkoutsDemoHarness.swift` (DEBUG) |
