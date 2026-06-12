# Models/Movements

The canonical movement and exercise layer: the unified `MovementCatalog` (single source of truth for every logged movement), type definitions, classification helpers, validation, name resolution, proof matching, and user-facing exercise library/preference models.

| File | Purpose |
|------|---------|
| `CustomExercise.swift` | `CustomExercise` struct representing a user-created exercise with pattern, classification, and rep defaults |
| `ExerciseCatalog.swift` | Legacy gym seed data (`CatalogExercise` structs grouped by movement pattern); kept during migration from the older program/preferences stack |
| `ExerciseLibraryItem.swift` | `ExerciseLibraryItem` and `ExerciseCategory` — the view-layer representation of a searchable exercise entry |
| `ExerciseLibrarySearch.swift` | `ExerciseLibrarySearchSignals` and search-result helpers (recent flag, preference badge, fuzzy ranking) |
| `ExercisePreference.swift` | `ExercisePreferenceStatus` (available/substitute/avoid) and the `ExercisePreference` record persisted per user per exercise |
| `MovementCatalog.swift` | Central `MovementCatalog` enum — assembles `definitions` from skill-tree nodes, `ExerciseCatalog`, cardio, and carries, plus lookup helpers |
| `MovementCatalog+Classification.swift` | `MovementCatalog` extension: `variantRankStandardNames` map and movement-family classification logic |
| `MovementCatalog+Definitions.swift` | `MovementCatalog` extension: `cardioDefinitions`, carry/sled definitions, and alias tables for non-gym movement types |
| `MovementCatalogTypes.swift` | Core enums for the catalog layer: `MovementRole`, `MovementLoggerMode`, `MovementDefinition`, `ResolvedMovement`, and metric types |
| `MovementCatalogValidation.swift` | `MovementCatalogValidation` — debug-mode issue scanner that checks for duplicate ids, orphan aliases, and catalog/ExerciseCatalog count mismatches |
| `MovementProgress.swift` | `RewardLedgerQuantizer` and AP/attribute point calculation helpers that turn raw performance into whole-point rewards |
| `MovementProofMatcher.swift` | `MovementProofMatcher` — strict name/id matching used by skill proof and tier-criterion evaluation; intentionally stricter than AP roll-up |
| `MovementResolver.swift` | `MovementResolver` — resolves a raw exercise-name string to a typed `ResolvedMovement` via the catalog, with inferred fallback |

## Where to find X

| Task | File |
|------|------|
| Look up metadata for any logged movement (logger mode, rank template, attribute weights) | `MovementCatalog.swift` |
| Resolve a raw exercise name string to a typed movement | `MovementResolver.swift` |
| Check whether a log entry satisfies a skill tier criterion | `MovementProofMatcher.swift` |
| Add or validate exercise preferences for a user | `ExercisePreference.swift` |
| Search or filter the exercise library for the picker UI | `ExerciseLibrarySearch.swift` / `ExerciseLibraryItem.swift` |
| Compute AP / attribute-point rewards from a performance log | `MovementProgress.swift` |
