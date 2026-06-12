# Views/Calibration

The post-onboarding calibration flow: a stepped container (intro → baselines → preferences → custom → complete) plus the calibration workout screen, driven by `UNBOUND/ViewModels/CalibrationViewModel.swift`.

## Files

| File | What it is |
|---|---|
| `CalibrationContainerView.swift` | Routes the calibration steps. |
| `CalibrationScaffold.swift` | Generic scaffold/chrome wrapping each step's content. |
| `CalibrationWorkoutView.swift` | `CalibrationWorkoutView` + `CalibrationEntry` — the calibration workout logging screen. |
| `HUDBaselineCard.swift` | Baseline-entry card in HUD styling. |
| `Step_Cal00_Intro.swift` | Step 0 — intro. |
| `Step_Cal01_Baselines.swift` | Step 1 — baseline lifts/reps entry. |
| `Step_Cal02_Preferences.swift` | Step 2 — exercise preferences. |
| `Step_Cal03_Custom.swift` | Step 3 — custom adjustments. |
| `Step_Cal04_Complete.swift` | Step 4 — completion. |

## Where to find X

- **Step ordering and state** → `UNBOUND/ViewModels/CalibrationViewModel.swift` (`CalibrationStep` enum) + `CalibrationContainerView.swift`.
- **Baseline number entry UI** → `Step_Cal01_Baselines.swift` + `HUDBaselineCard.swift`.
- **Shared step chrome** → `CalibrationScaffold.swift`.
- **HUD-styled inputs used by these steps** → `UNBOUND/Views/Components/HUD/`.
