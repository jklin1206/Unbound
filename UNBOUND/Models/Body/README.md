Data models for body scanning, progress photography, muscle-region tracking, and monthly scan checkpoints. The scan pipeline is ceremonial (onboarding context, not program input); `ScanCheckpoint` is the current active record shape; older `BodyAnalysis` / `ScanContext` shapes are kept for migration compatibility.

| File | Purpose |
|---|---|
| `BodyScan.swift` | `ScanSession` — a photo-capture session record (photos, status, body metrics, program link) |
| `BodyAnalysis.swift` | `BodyAnalysis` — AI-driven per-scan analysis with muscle assessments; retained for migration; new flow uses `ScanCheckpoint` |
| `BodyRegion.swift` | `BodyRegion` enum — granular muscle partition for the home character-sheet figure (UI gauge, parallel to `MuscleGroup`) |
| `BodyMapProgress.swift` | `BodyRegionLoad` and `BodyRegionLoad`-keyed load snapshot — per-region recent + lifetime training load state |
| `BodyRegionTrainingLedger.swift` | `BodyRegionSetRole`, `BodyRegionTrainingLoad` — set-role taxonomy and per-region load ledger entries |
| `BodyScanInsights.swift` | `BodyScanInsights` — on-device Vision-derived measurements (shoulder-hip ratio, torso/leg proportions, posture flags); onboarding only |
| `ScanCheckpoint.swift` | `ScanCheckpoint` — the current monthly scan record: photo filename + `BuildIdentity` snapshot read from the attribute system |
| `ScanContext.swift` | `ScanContext` — legacy transient build-and-send payload from the removed photo-analysis pipeline; kept for migration decoding |
| `ScanAngle.swift` | `ScanAngle` enum — front / side / back capture angles with user-facing capture instructions |
| `ScanDeltaReport.swift` | `ScanDeltaReport` — legacy inter-checkpoint delta shape; kept so rollover/share/coach surfaces remain readable |
| `ProgressPhoto.swift` | `ProgressPhoto` — stored progress photo record with source (manual vs scan), storage URL, and capture metadata |
| `MuscleGroup.swift` | `MuscleGroup` enum — coarse 12-way muscle taxonomy used by `ExerciseCatalog` tagging and `BuildIdentity` priority groups |
| `MuscleHeatGroup.swift` | `MuscleHeatGroup` enum — coarse 12-way training-signal partition keyed by `ScanContext`'s monthly checkpoint map |
| `CheckpointSignals.swift` | `RecoveryState` and `CheckpointSignals` — deterministic recovery + training-load signals fed into monthly recap pipeline |
| `CheckpointOutcome.swift` | `CheckpointOutcome` — `completed(CheckpointSignals)` or `skipped`; wraps the nullable signals result |
| `CalibrationBaseline.swift` | `CalibrationBaseline` — per-user, per-exercise known-weight or known-rep baseline captured during onboarding |

## Where to find X

| Task | File |
|---|---|
| Display the home character-sheet muscle-region heat map | `BodyRegion.swift` + `BodyMapProgress.swift` |
| Read or write the current monthly scan record | `ScanCheckpoint.swift` |
| Access per-region recent training load | `BodyRegionTrainingLedger.swift` |
| Decode a legacy scan or analysis document | `BodyAnalysis.swift` / `ScanContext.swift` / `ScanDeltaReport.swift` |
| Show a user's stored progress photos | `ProgressPhoto.swift` |
| Look up which muscle group an exercise targets | `MuscleGroup.swift` |
