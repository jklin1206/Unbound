# Models/Body

Body-scan and physique-tracking models: the monthly scan checkpoint flow (`ScanCheckpoint` + signals/outcome), legacy scan/analysis shapes kept for decoding compatibility, progress photos, the muscle/region taxonomies, and the body-map training-load ledger.

| File | What it contains |
| --- | --- |
| `BodyAnalysis.swift` | Legacy `BodyAnalysis` (scan verdict record, judgment-free by design) + `ProportionData`, `FocusArea`. |
| `BodyMapProgress.swift` | `BodyRegionLoad`, `BodyMapProfile`, `BodyMapRegionReward`, `BodyMapIngestResult`, `BodyMapSourceReceipt` — per-region load/progress state for the body map. |
| `BodyRegion.swift` | `BodyRegion` — granular muscle partition for the home character-sheet figure (UI gauge; parallel to the coarser `MuscleGroup`). |
| `BodyRegionTrainingLedger.swift` | `BodyRegionSetRole`, `BodyRegionTrainingLoad`, and the `BodyRegionTrainingLedger` ingest logic that buckets logged sets into region loads. |
| `BodyScan.swift` | Legacy `ScanSession` + `ScanStatus`. |
| `BodyScanInsights.swift` | `BodyScanInsights` — on-device Vision-derived shape measurements (ratios, posture flags); onboarding hint only, never a grade. |
| `CalibrationBaseline.swift` | `CalibrationBaseline` — a user's per-exercise baseline measurement (kind, value, unit). |
| `CheckpointOutcome.swift` | `CheckpointOutcome` — completed(signals) vs skipped result of a checkpoint. |
| `CheckpointSignals.swift` | `RecoveryState` and `CheckpointSignals` — the deterministic training-signal payload a checkpoint summarizes. |
| `MuscleGroup.swift` | `MuscleGroup` — coarse 12-case muscle enum used for exercise tagging (chest, back, …, calves). |
| `ProgressPhoto.swift` | `ProgressPhoto` — a saved progress photo (manual, scan, or post-workout source); a `.workout` photo carries an optional `WorkoutPhotoSummary`. |
| `ScanAngle.swift` | `ScanAngle` — front/side/back capture angles with user-facing instructions. |
| `ScanCheckpoint.swift` | `ScanCheckpoint` — the CURRENT monthly scan record (photos + `BuildIdentity` snapshot read from the attribute system); also `BuildIdentity: Codable` conformance. |
| `ScanDeltaReport.swift` | Legacy `ScanDeltaReport` + `BodyPartDelta` — between-scan recap shape kept for persistence compatibility. |
| `WorkoutPhotoSummary.swift` | `WorkoutPhotoSummary` — compact, denormalized snapshot (title, date, duration, exercise lines) of the workout a `.workout` progress photo was taken after; built from a `PerformanceLog`. |

Where to find X:

- The live monthly-scan model → `ScanCheckpoint.swift` (with `CheckpointSignals.swift` / `CheckpointOutcome.swift`)
- Legacy scan shapes kept only for decoding → `BodyScan.swift`, `BodyAnalysis.swift`, `ScanDeltaReport.swift`
- The muscle taxonomy → coarse tagging `MuscleGroup.swift`; UI figure regions → `BodyRegion.swift`
- How logged sets become per-region load → `BodyRegionTrainingLedger.swift`, accumulated state in `BodyMapProgress.swift`
- Camera capture instructions per angle → `ScanAngle.swift`
- Progress photos → `ProgressPhoto.swift`
- A post-workout photo's "what you did" snapshot → `WorkoutPhotoSummary.swift`
