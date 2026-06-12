# SessionEditor

Workout builder / plan-ahead editor — lets users create, edit, or save a training session draft before starting it.

| File | Description |
|------|-------------|
| `SessionEditorView.swift` | Root view and `Mode` enum (`startSession`, `planAhead`, `saveWorkout`); owns all state and coordinates sub-extensions |
| `SessionEditorView+Blocks.swift` | Renders the exercises list (`blocksList`) with per-block editable rows |
| `SessionEditorView+EditableRows.swift` | `EditablePrescriptionRow` — flat exercise row with set/weight/reps grid and add-set control |
| `SessionEditorView+Footer.swift` | Bottom start/save bar (`bottomStartBar`) with persistence-control toggle |
| `SessionEditorView+Header.swift` | Top navigation bar (`header`) with close button and title |
| `SessionEditorView+Keypad.swift` | Bottom-docked number-pad editing via shared `NumberPadEditorModel`; builds per-cell `NumberPadCellConfig` for the draft's set plan |
| `SessionEditorDemoHarness.swift` | DEBUG-only verification harness; boots `SessionEditorView` with a seeded draft via `-sessionEditorDemo` launch arg for on-sim screenshots |
