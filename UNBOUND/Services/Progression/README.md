# Progression

Post-workout progression ingest: deterministic RPE-based weight/rep advancement per exercise, plateau detection and automatic deloads, movement AP and overall-level (LV) accumulation, and body-map/stamina derived metrics. Runs after every logged session.

## Files

| File | Purpose |
| --- | --- |
| `AutoDeloadService.swift` | Runs at the end of post-log ingest: detects plateaus and applies `DeloadPlanner.planDeload` automatically (anti-thrash: never re-deloads an athlete already in a deload block). |
| `BodyMapProgressService.swift` | Per-region training-load profile with recency half-life; supplies the region-novelty multiplier (including a synchronous cached preview path). |
| `DeloadPlanner.swift` | Decides when a deload is warranted (`shouldDeload`) and rewrites `ProgressionState`s into a deload block (`planDeload`). |
| `MovementAPCalculator.swift` | Computes per-movement AP gains from a `PerformanceLog`; resolves logged names to rank-standard movement ids. |
| `MovementProgressConsolidationMigration.swift` | One-time local migration that folds a retired `movement_progress` row into its canonical standard when a movement's rank standards were unified (P3); idempotent, sums AP + unions dedupe sets. |
| `MovementProgressService.swift` | `@MainActor` ingest entry point for a `PerformanceLog` → `MovementProgressIngestResult`; best-effort or strict persistence modes. |
| `OverallLevelCloudBackup.swift` | Cloud mirror for the overall level: patches the whole `OverallLevelProgress` ledger onto the synced `users` doc (`overallLevelBackup`) after every persist, and restores it into the local `overall_level_progress` doc on launch (higher `totalXP` wins, never regresses). |
| `OverallLevelService.swift` | Accumulates weighted XP into `OverallLevelProgress` (total XP / level); caches last-known progress for synchronous reward previews. |
| `PlateauDetector.swift` | Flags exercises stalled at the same weight for consecutive sessions (`PlateauedExercise`). |
| `ProgressSnapshotCloudBackup.swift` | Compact cloud mirror of the local-only progression collections (`movement_progress`, `progression_states`, `progression_families`) patched onto the synced users doc as `progressSnapshot`; never-regressing `seedLocalStores` restore after reinstall. |
| `ProgressionEngine.swift` | Deterministic autoregulation: two clean top-range sessions advance, low-RPE over-performance advances immediately, accessories add reps first with bounded auto-load ramps, and isometrics climb seconds ladders. |
| `ProgressionMode.swift` | `advance` (default) vs `preserve` (Cut mode: hold weights, tier unlocks still fire). |
| `ProgressionStateStore.swift` | Persistence for `ProgressionState` records via `SyncedDatabase` (collection `"progression_states"`). |
| `ResolvedMovement+Definition.swift` | Tiny extension: `ResolvedMovement.definition` lookup into `MovementCatalog`. |
| `StaminaCalculator.swift` | Maps a stamina value to `StaminaTier` (sedentary → elite) with display names. |

## Where to find X

- **Why weights went up (or didn't) after a session** → `ProgressionEngine.swift`; the per-exercise state lives in `ProgressionStateStore.swift`.
- **Plateau → deload behavior** → `PlateauDetector.swift` → `AutoDeloadService.swift` → `DeloadPlanner.swift`.
- **How a logged session becomes XP/LV** → `MovementProgressService.swift` (ingest) → `MovementAPCalculator.swift` (AP) → `OverallLevelService.swift` (level), with novelty from `BodyMapProgressService.swift`.
- **Cut-mode behavior** → `ProgressionMode.swift` (consumed by the engine).
- **Why tiers/working loads survive a reinstall** → `ProgressSnapshotCloudBackup.swift` (users-doc `progressSnapshot` field; restore seeded at launch).
