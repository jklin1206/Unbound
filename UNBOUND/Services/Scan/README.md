# Scan

The scan/checkpoint flow: capturing a checkpoint (photo + structured signals), validating and summarizing it into program-gen inputs, narrative flavor copy, and nutrition targets. Design rule throughout: the photo is ceremonial — it is never sent to AI, never graded, and never the source of truth (BuildIdentity comes from the attribute system).

## Files

| File | Purpose |
| --- | --- |
| `CheckpointFlow.swift` | State machine for the checkpoint UI: entry → bodyCapture → standardsCheck → freeText → nutritionCheck → summarizing → review → commit. |
| `CheckpointSummarizer.swift` | Turns checkpoint inputs (free text, standards check, nutrition, missed-session signal) into summarized `CheckpointSignals`. |
| `CheckpointValidator.swift` | Validates a `CheckpointSignalDraft`; load-adjustment bias is computed here from structured signals (any AI-supplied bias is ignored). |
| `NutritionTargetCalculator.swift` | Protein + hydration targets from bodyweight and recent hard-session flag, with configurable g/kg and ml/kg bounds. |
| `ScanCheckpointService.swift` | Orchestrates the scan flow: reads BuildIdentity from attributes (never the photo), persists photo + checkpoint, optional narrative recap. Defines `ScanPhotoWriting`. |
| `ScanCheckpointStore.swift` | Filesystem persistence — one JSON file per `ScanCheckpoint`, history filtered by userId. |
| `ScanComparisonService.swift` | Legacy bridge from the old two-photo comparison to the checkpoint system; keeps the persisted `ScanDeltaReport` shape for older rollover/coach surfaces. |
| `ScanNarrativeService.swift` | 2-3 sentence narrative copy around derived BuildIdentity via Claude Haiku, deterministic template fallback. Never sees a photo. |
| `TravelOverrideStore.swift` | Async cache + persistence for `TravelOverride`s (`travel_overrides`); home/program views read `activeOverride(for:)` to substitute the travel workout. |

## Where to find X

- **The checkpoint flow steps / UI state** → `CheckpointFlow.swift`.
- **How checkpoint answers become program inputs (incl. load bias)** → `CheckpointSummarizer.swift` + `CheckpointValidator.swift`.
- **Saving/loading checkpoints and photos** → `ScanCheckpointService.swift` + `ScanCheckpointStore.swift`.
- **Travel-mode workout substitution** → `TravelOverrideStore.swift`.
- **Legacy scan surfaces** → `ScanComparisonService.swift` (legacy, kept for compatibility).
