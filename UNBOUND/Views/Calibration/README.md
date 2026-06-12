# Views/Calibration

Post-onboarding calibration flow (Chapter V): 3-step wizard capturing baseline reps/weights, exercise preferences, and optional custom lifts, culminating in a "Arc Locked" interstitial. Uses `CalibrationViewModel` for state.

| File | Purpose |
|------|---------|
| `CalibrationContainerView.swift` | Root container: initializes `CalibrationViewModel`, routes between calibration steps |
| `CalibrationScaffold.swift` | Reusable step scaffold: eyebrow, title, subtitle, Continue/Back buttons, content slot |
| `CalibrationWorkoutView.swift` | Optional live calibration workout: logs a test set to seed baseline data |
| `HUDBaselineCard.swift` | Per-baseline input card using `HUDPanel`: rep/weight entry with "I don't know" toggle |
| `Step_Cal00_Intro.swift` | Chapter V intro interstitial: "CALIBRATION — Lock your starting point" |
| `Step_Cal01_Baselines.swift` | Baseline reps/weights input step (01/03) |
| `Step_Cal02_Preferences.swift` | Exercise YES/SUB/NO preference step (02/03) |
| `Step_Cal03_Custom.swift` | Custom lift addition step (03/03) |
| `Step_Cal04_Complete.swift` | Completion interstitial: "ARC LOCKED — Your path is live" |

## Where to find X

| Task | File |
|------|------|
| Change calibration step routing or add a step | `CalibrationContainerView.swift` + `CalibrationViewModel` |
| Edit the baseline input card layout | `HUDBaselineCard.swift` |
| Modify the scaffold (Continue button, progress label) | `CalibrationScaffold.swift` |
| Adjust the preference picker step | `Step_Cal02_Preferences.swift` |
| Change the intro or completion interstitial copy | `Step_Cal00_Intro.swift` / `Step_Cal04_Complete.swift` |
