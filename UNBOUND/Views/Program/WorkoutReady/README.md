# WorkoutReady

Pre-workout confirmation screen — shows the session draft (blocks, exercises, trial headers) and lets the user modify it before tapping Begin.

| File | Description |
|------|-------------|
| `WorkoutReadyView.swift` | Root view; owns draft state, active-workout draft handoff, skill-session launch, and block-builder presentation |
| `WorkoutReadyView+Blocks.swift` | `blockList` — renders training blocks including deck-trial example grids |
| `WorkoutReadyView+BuilderSheets.swift` | `BlockEditSheet` — inline sheet for editing an individual `BlockEditDraft` |
| `WorkoutReadyView+Controls.swift` | `addControls` — add-scheduled-skill and add-custom-block control row |
| `WorkoutReadyView+Header.swift` | `header` — adaptive header for standard workouts, weekly-proof, and rank-trial variants |
