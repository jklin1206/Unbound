# Program/ActiveWorkout

Live workout logging surface: grid-based set/rep entry, rest timer, rank trial flow, and the post-workout completion sequence that assembles `PerformanceLog` data and triggers the reward sequence.

| File | Purpose |
|------|---------|
| `ActiveWorkoutContainerView.swift` | Root session orchestrator: owns `ActiveWorkoutSession`, autosaves drafts, hosts grid + timer chrome, assembles and saves `PerformanceLog` on completion |
| `ActiveWorkoutContainerView+TopBar.swift` | Top bar chrome: workout title, elapsed timer, exit confirmation |
| `ActiveWorkoutContainerView+Keypad.swift` | Bottom keypad for weight/reps entry attached to the active exercise |
| `ActiveWorkoutContainerView+CompletionFooter.swift` | "Complete Workout" sticky footer and save/confirm logic |
| `WorkoutLogGridView.swift` | Scrollable exercise grid: one `ExerciseLogCard` per exercise, collapse/expand, deck-card reveal |
| `ExerciseLogCard.swift` | Per-exercise card: name, planned sets/reps/rest, muscle groups, form cues, substitution |
| `SetLogGridRow.swift` | Single set row: suggested (dim, hollow ring) vs logged (solid, check glyph) states |
| `StepperControl.swift` | Large glove-friendly numeric stepper with tap-to-type and haptic increments |
| `RPEPickerSheet.swift` | Per-set RPE picker (scale 6–10) with reps-in-reserve descriptions |
| `RestTimerPill.swift` | Floating rest timer pill with add-30s and dismiss affordances |
| `ExerciseOverflowMenu.swift` | Per-exercise overflow menu: substitute, skip, notes |
| `DeckOfProofDrawStage.swift` | "Deck of Proof" progressive card-reveal stage for discovery exercises |
| `RankTrialFlowViews.swift` | In-session rank trial wrapper views (ready/active/complete stages) |
| `TowerTrialAscentView.swift` | Tower-mode trial: multi-floor ascent layout with `currentFloorCard` slot |
| `ActiveWorkoutSheets.swift` | Sheet enum and `EditorSheet` (numeric edit for weight or reps mid-session) |
| `ActiveWorkoutDemoHarness.swift` | DEBUG-only harness (`-activeWorkoutDemo`) for screenshot verification |

## Where to find X

| Task | File |
|------|------|
| Change how a set is confirmed or logged | `SetLogGridRow.swift` + `ActiveWorkoutContainerView+Keypad.swift` |
| Modify the rest timer behavior | `RestTimerPill.swift` |
| Edit the completion save / reward trigger | `ActiveWorkoutContainerView+CompletionFooter.swift` + `ActiveWorkoutContainerView.swift` |
| Add a new rank trial mode view | `RankTrialFlowViews.swift` + `TowerTrialAscentView.swift` |
| Adjust the RPE picker scale or labels | `RPEPickerSheet.swift` |
| Change the exercise card layout | `ExerciseLogCard.swift` + `WorkoutLogGridView.swift` |
