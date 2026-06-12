# Services/Scan

Handles progress checkpoint captures: photo storage, checkpoint summarization, Arc-boundary validation, and lightweight AI narrative copy. BuildIdentity is derived from the attribute system — the scan photo is never graded or sent to an AI model. Also owns nutrition target calculation and travel override persistence.

| File | Purpose |
|---|---|
| `ScanCheckpointService.swift` | Primary orchestrator: captures a checkpoint photo, reads `BuildIdentity` from `AttributeService`, persists to `ScanCheckpointStore`, and optionally generates narrative copy via `ScanNarrativeService`. |
| `ScanCheckpointStore.swift` | Persistence for `ScanCheckpoint` records in the `scanCheckpoints` collection. |
| `CheckpointFlow.swift` | Value-type state machine for the multi-step checkpoint UI flow (entry → bodyCapture → standardsCheck → freeText → nutrition → review → commit). |
| `CheckpointSummarizer.swift` | Aggregates `CheckpointSummaryInput` (free text, standards check, nutrition, missed-session signal) into a `CheckpointSignals` struct for the rollover. |
| `CheckpointValidator.swift` | Validates a `CheckpointSignalDraft`; computes the bounded `loadAdjustmentBias` from structured signals (never trusts an AI-supplied bias directly). |
| `ScanNarrativeService.swift` | Generates first-scan and evolution narrative copy using Claude Haiku 4.5; never sees a photo, never grades the body; falls back to a template on error. |
| `ScanPayoffFlavorService.swift` | Generates one-liner Build Identity flavor copy via Claude Haiku 4.5; falls back to a localized default. |
| `ScanComparisonService.swift` | Legacy bridge from the old two-photo comparison surface to the checkpoint system; maintains `ScanDeltaReport` for older coach/rollover readers. |
| `ScanContextBuilder.swift` | Legacy builder for the removed photo-analysis payload; retained for migration references and older tests. |
| `NutritionTargetCalculator.swift` | Pure calculator for personalized protein targets and hydration from bodyweight and recent session history. |
| `TravelOverrideStore.swift` | Async cache + persistence for `TravelOverride` records; read by the home view and program overview to substitute a travel workout for scheduled days. |

## Where to find X

| Task | File(s) |
|---|---|
| Saving a new checkpoint (photo + identity snapshot) | `ScanCheckpointService.swift`, `ScanCheckpointStore.swift` |
| Checkpoint UI step progression | `CheckpointFlow.swift` |
| Validating and applying a load adjustment bias | `CheckpointValidator.swift`, `CheckpointSummarizer.swift` |
| Narrative / flavor copy generation | `ScanNarrativeService.swift`, `ScanPayoffFlavorService.swift` |
| Travel workout override for a date range | `TravelOverrideStore.swift` |
