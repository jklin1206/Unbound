# SessionEditor

The workout builder/editor sheet (`SessionEditorView`) — edits a `TrainingSessionDraft` in three modes: `.startSession` (EDIT WORKOUT), `.planAhead` (PLAN WORKOUT), `.saveWorkout` (CREATE WORKOUT). Split into extensions to stay under the SwiftUI metadata cliff.

| File | What it is |
| --- | --- |
| `SessionEditorView.swift` | Root view: `Mode` enum (header/eyebrow/footer copy per mode), draft state, and the main body. |
| `SessionEditorView+Blocks.swift` | `blocksList` — the "EXERCISES" section header plus a `blockCard` per draft block. |
| `SessionEditorView+EditableRows.swift` | `EditablePrescriptionRow` — flat always-visible exercise row (thumbnail + name + overflow menu) with the compact Set · Weight · Reps grid and "add set". |
| `SessionEditorView+Footer.swift` | `bottomStartBar` — persistence label + exercise count, add-exercise button, and the start/save CTA. |
| `SessionEditorView+Header.swift` | `header` — Close button and the mode title bar. |
| `SessionEditorView+Keypad.swift` | Bottom-docked keypad editing: `CellEditTarget` cell identity + per-cell `NumberPadCellConfig`, driving the shared `NumberPadEditorModel` so this grid matches in-workout logging. |
| `SessionEditorDemoHarness.swift` | DEBUG-only harness (`-sessionEditorDemo` launch arg) that boots the real editor with a seeded draft for on-sim screenshots. |
