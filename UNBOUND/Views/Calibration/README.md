# Views/Calibration

The calibration workout logging screen, presented directly from Home (`CalibrationWorkoutView`). The older stepped intro → baselines → preferences → custom → complete container flow was retired and removed (never presented from anywhere in the app); do not resurrect it — build calibration UI directly into `CalibrationWorkoutView` instead.

## Files

| File | What it is |
|---|---|
| `CalibrationWorkoutView.swift` | `CalibrationWorkoutView` + `CalibrationEntry` — the calibration workout logging screen. |

## Where to find X

- **The calibration workout logging screen** → `CalibrationWorkoutView.swift`.
- **Persisting calibration baselines / completed flag** → `UNBOUND/Services/Calibration/CalibrationService.swift`.
- **HUD-styled inputs used elsewhere** → `UNBOUND/Views/Components/HUD/`.
