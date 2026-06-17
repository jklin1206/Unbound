# Program/ActiveWorkout

The live in-workout logging screen: `ActiveWorkoutContainerView` owns the `ActiveWorkoutSession`, autosaves drafts, hosts the grid-based set-logging surface plus timer chrome, and on COMPLETE assembles `PerformanceLog` data before the post-workout reward sequence.

## Files

| File | What it is |
|---|---|
| `ActiveWorkoutContainerView.swift` | The session orchestrator view — owns session state, draft autosave, completion + reward handoff. |
| `ActiveWorkoutContainerView+Chrome.swift` | Top bar (close / elapsed / mode badge / progress rail), draft-autosave warning row, trial-format flags, time formatting. |
| `ActiveWorkoutContainerView+Intents.swift` | Overflow-menu intent handling (warmup toggle, add/remove set, skip, notes, swap) + DEBUG fill-planned-sets. |
| `ActiveWorkoutContainerView+Keypad.swift` | Wires the session into the shared `NumberPadEditorModel` (per-cell config, live-write/commit/RPE closures); dock chrome lives in `../../Components/Unbound/NumberPadEditor.swift`. |
| `ActiveWorkoutContainerView+RewardSummary.swift` | Assembles the post-workout `WorkoutRewardSequenceSummary` (incl. rank-trial callout) from the completion result. |
| `ActiveWorkoutDemoHarness.swift` | TEMPORARY proof harness — boots the real container with a seeded draft via `-activeWorkoutDemo` launch arg for screenshots. |
| `ActiveWorkoutSheets.swift` | `EditorSheet` + `NotesEditSheet` presented from the workout. |
| `DeckOfProofDrawStage.swift` | `DeckOfProofDrawStage` — the card-draw trial stage view. |
| `DeckOfProofDrawStage+CardModel.swift` | Derives the playing-card descriptor (rank/suit/title/tint) from exercise block metadata. |
| `ExerciseLogCard.swift` | `ExerciseLogCard` — one exercise's logging card. |
| `ExerciseOverflowMenu.swift` | `OverflowIntent` enum + `ExerciseOverflowMenu` per-exercise menu. |
| `RestTimerPill.swift` | `RestTimerPill` — compact rest-timer pill. |
| `RPEPickerSheet.swift` | Optional per-set RPE picker (real 6–10 scale with reps-in-reserve meaning); returns `Int?` (nil = Clear). |
| `SetLogGridRow.swift` | One set row: SUGGESTED (dim program values, hollow confirm ring) vs LOGGED (solid actuals, quiet check). |
| `StepperControl.swift` | Glove-friendly numeric stepper (tap to type, step arrows, per-tick haptic). |
| `WorkoutLogGridView.swift` | `WorkoutLogGridView` — the scrolling grid of exercise log cards. |

## Where to find X

- **How a set gets confirmed/edited** → `SetLogGridRow.swift` (row UI) + `ActiveWorkoutContainerView+Keypad.swift` (editor wiring).
- **What happens on COMPLETE** → `ActiveWorkoutContainerView.swift` + `+RewardSummary.swift`.
- **Add set / skip / swap / notes actions** → `ExerciseOverflowMenu.swift` + `ActiveWorkoutContainerView+Intents.swift`.
- **Rest timer** → `RestTimerPill.swift`.
- **Screenshot/verify the screen on sim** → `ActiveWorkoutDemoHarness.swift` (`-activeWorkoutDemo`).
- **Trial-specific stages** → `DeckOfProofDrawStage.swift` (more modes in `../RankTrials/`).
