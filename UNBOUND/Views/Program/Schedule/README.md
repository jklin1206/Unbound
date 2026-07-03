# Program/Schedule

The training-schedule editor.

## Files

| File | What it is |
|---|---|
| `TrainingScheduleEditorSheet.swift` | `TrainingScheduleEditorSheet` — post-onboarding editor for the *real* schedule: which weekdays you train (3–6), session length, and time of day. Opened by tapping the week-strip header on the Program tab; saving rewrites the profile and regenerates the current arc from today forward (via `ProgramViewModel.applyTrainingSchedule`), and keeps any enabled workout reminders in step. |

## Where to find X

- **Opening the editor** → `ProgramWeekStrip` header button → `ProgramOverviewView.openScheduleEditor()` (seeds it from the profile) → this sheet.
- **Regenerating the arc from the new schedule** → `ProgramOverviewView.applyScheduleChange(...)` → `ProgramViewModel.applyTrainingSchedule(...)`.
- **Scheduling a single saved workout to a date** → not here; see `../MyWorkouts/ScheduleWorkoutDateSheet.swift`.
