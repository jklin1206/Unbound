# WorkoutReady

The pre-workout review/launch screen (`WorkoutReadyView`) — shows a `TrainingSessionDraft` before starting, lets the user add/edit blocks, and launches the active workout (also handles weekly-vow, rank-trial, and deck-trial drafts).

| File | What it is |
| --- | --- |
| `WorkoutReadyView.swift` | Root view: draft + sheet state (`activeWorkoutDraft`, `activeSkillSession`, block builder/edit), NavigationStack body, and workout launch. |
| `WorkoutReadyView+Blocks.swift` | `blockList` — per-block rows, or the deck-trial example grid / rank-trial ready preview when the draft is a trial. |
| `WorkoutReadyView+BuilderSheets.swift` | `BlockEditSheet` — sheet for editing a `BlockEditDraft` and saving it back into the draft. |
| `WorkoutReadyView+Controls.swift` | `addControls` — quiet add buttons (next scheduled skill, etc.) below the block list. |
| `WorkoutReadyView+Header.swift` | `header` — picks the weekly-proof / rank-trial / standard workout header variant. |
