# Program/Schedule

The weekly training-schedule editor.

## Files

| File | What it is |
|---|---|
| `ProgramScheduleEditorViews.swift` | `WeeklyScheduleEditorSheet` (V4) — drag-to-reorder weekly split editor: day labels stay pinned Mon–Sun while the user reorders training *categories* via SwiftUI `List` + `.onMove`; includes the deterministic OPTIMIZE SPLIT action derived from Program Focuses. |

## Where to find X

- **Reordering which category lands on which weekday** → `ProgramScheduleEditorViews.swift` (`.onMove` handling).
- **The auto "optimize split" behavior** → same file, OPTIMIZE SPLIT section.
- **Scheduling a single saved workout to a date** → not here; see `../MyWorkouts/ScheduleWorkoutDateSheet.swift`.
