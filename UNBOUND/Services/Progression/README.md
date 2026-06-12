# Services/Progression

Tracks per-movement progression state, computes AP (ability points) for each logged set, advances weights and tiers when RPE targets are met, detects plateaus, applies auto-deloads, and aggregates progress into the overall-level XP bar and body-map heat. Also covers the body-composition body map and stamina tier.

| File | Purpose |
|---|---|
| `ProgressionEngine.swift` | Core RPE-based progression: advances weight when top-of-rep-range at target RPE for 2 consecutive sessions; handles compound weight jumps vs accessory rep-before-weight logic. |
| `ProgressionMode.swift` | Enum: `advance` (default) or `preserve` (cut mode — holds weights, still records sessions). |
| `ProgressionStateStore.swift` | `@MainActor` store persisting `ProgressionState` records to the `progression_states` collection via `SyncedDatabase`. |
| `MovementProgressService.swift` | Ingests a `PerformanceLog`: writes `MovementProgressRecords`, emits `.progressionAdvanced` for weight bumps. |
| `MovementAPCalculator.swift` | Pure calculator: derives AP earned per movement from set volume, intensity relative to personal best, and movement type. |
| `OverallLevelService.swift` | Ingests raw AP + novelty multiplier to update total XP, level, and percentage-to-next-level; emits `.overallLevelAdvanced`. |
| `BodyMapProgressService.swift` | Decays region-load scores with a 14-day half-life; produces the body-map heat profile consumed by the home dashboard. |
| `PlateauDetector.swift` | Reads recent logs via `WorkoutLogService` and identifies exercises with stalled progression across N sessions. |
| `DeloadPlanner.swift` | Pure deload planner: returns deloaded `ProgressionState` copies (10% weight reduction, block week reset). |
| `AutoDeloadService.swift` | Wires `PlateauDetector` + `DeloadPlanner` into the post-log ingest path; auto-applies deload without requiring a Coach tap. |
| `ResolvedMovement+Definition.swift` | Extension bridging `ResolvedMovement` to its `MovementDefinition` from the catalog. |
| `StaminaCalculator.swift` | Derives `StaminaTier` (sedentary→elite) from cardio log history and session frequency. |

## Where to find X

| Task | File(s) |
|---|---|
| Change weight/rep progression rules | `ProgressionEngine.swift` |
| Change how AP is calculated per set | `MovementAPCalculator.swift` |
| Change overall-level XP formula | `OverallLevelService.swift` |
| Change plateau detection or auto-deload | `PlateauDetector.swift`, `AutoDeloadService.swift`, `DeloadPlanner.swift` |
| Change body-map decay / heat profile | `BodyMapProgressService.swift` |
