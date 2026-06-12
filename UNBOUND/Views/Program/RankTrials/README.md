# Program/RankTrials

Rank trial mode views: ready-preview and active-stage layouts for every trial variant (BossRush, Daily100, FinalExam, Finisher, Operator, ThresholdRaid), plus shared visual primitives and a DEBUG demo recorder.

| File | Purpose |
|------|---------|
| `RankTrialActiveStageLayout.swift` | Generic container for the active trial stage: header, active exercise slot, completed-content slot via `RankTrialExercisePair` |
| `OperatorScreenTrialModeView.swift` | Operator Screen trial: ready preview with lane-station grid |
| `OperatorActiveModeViews.swift` | Operator active stage: `OperatorActiveFocusPanel` with station progress and viewport shape |
| `OperatorReadyModeViews.swift` | Operator ready-state models (`OperatorReadyStation`) and lane-strip visuals |
| `OperatorSharedVisuals.swift` | Shared Operator-flavored shapes and beacon components (`OperatorLaneBeacon`, `OperatorBeaconShape`) |
| `BossRushTrialModeView.swift` | Boss Rush trial: ready preview with ranked boss list |
| `Daily100TrialModeView.swift` | Daily-100 trial: ready preview showing oath-marks and target total |
| `FinalExamTrialModeView.swift` | Final Exam trial: ready preview with section grouping |
| `FinisherTrialModeView.swift` | Finisher trial: ready preview with station sequence |
| `ThresholdRaidTrialModeView.swift` | Threshold Raid trial: ready preview with node chain |
| `RankTrialDemoRecorderView.swift` | DEBUG-only demo recorder: drives scripted trial scenarios for screenshot / video capture |

## Where to find X

| Task | File |
|------|------|
| Add a new trial mode (ready + active views) | `RankTrialActiveStageLayout.swift` as the active container; create a new `*TrialModeView.swift` following existing pattern |
| Change the shared active-stage header layout | `RankTrialActiveStageLayout.swift` |
| Adjust Operator visual language (beacons, lanes) | `OperatorSharedVisuals.swift` + `OperatorActiveModeViews.swift` |
| Edit a trial's ready-preview card | The corresponding `*TrialModeView.swift` (e.g. `BossRushTrialModeView.swift`) |
| Record or re-record a trial demo video | `RankTrialDemoRecorderView.swift` (DEBUG build, `-rankTrialDemo` launch arg) |
