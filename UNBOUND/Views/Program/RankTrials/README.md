# Program/RankTrials

Rank-trial workout modes: each trial format has a `*TrialReadyPreview` (pre-start) and a `*TrialActiveView` (in-progress, generic over the current station/floor card), plus the shared "operator screen" visual language and the active-stage layout shell they all share.

## Files

| File | What it is |
|---|---|
| `BossRushTrialModeView.swift` | Boss Rush format: `BossRushTrialReadyPreview` + `BossRushTrialActiveView`. |
| `Daily100TrialModeView.swift` | Daily 100 format: ready preview + active view. |
| `FinalExamTrialModeView.swift` | Final Exam format: ready preview + active view. |
| `FinisherTrialModeView.swift` | Finisher format: ready preview + active view. |
| `OperatorActiveModeViews.swift` | Active-mode operator panels: focus panel, lane board/rows, calibration track, complete panel. |
| `OperatorReadyModeViews.swift` | Ready-mode operator widgets: readiness scanner, gauge strip, lane rows, metric pips, `OperatorReadyStation` model. |
| `OperatorScreenTrialModeView.swift` | Operator Screen format: ready preview + active view. |
| `OperatorSharedVisuals.swift` | Shared operator primitives: lane beacon, micro gauge, status chip, sweep line, `OperatorExerciseState`/`OperatorIcon`/`OperatorText`. |
| `RankTrialActiveStageLayout.swift` | `RankTrialActiveStageLayout` — generic header/active/completed shell all active trial views use; also `RankTrialInfoChip` and `ActiveWorkoutSession` convenience extensions. |
| `RankTrialDemoRecorderView.swift` | `RankTrialDemoRecorderView` (@MainActor) — dev harness for recording trial-mode demos. |
| `ThresholdRaidTrialModeView.swift` | Threshold Raid format: ready preview + active view. |

## Where to find X

- **Add or change a trial format's screen** → the matching `*TrialModeView.swift`.
- **The common active-stage scaffold (header / station card / completed list)** → `RankTrialActiveStageLayout.swift`.
- **Pre-start readiness UI (scanner, gauges)** → `OperatorReadyModeViews.swift`.
- **In-trial lane/station board** → `OperatorActiveModeViews.swift`.
- **Shared chips/beacons/icon-text styling** → `OperatorSharedVisuals.swift`.
- **Tower trial** → lives in `../ActiveWorkout/TowerTrialAscentView.swift`, not here.
