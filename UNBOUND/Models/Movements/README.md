# Models/Movements

Movement/exercise identity layer: the canonical `MovementCatalog` of `MovementDefinition`s, the legacy `ExerciseCatalog` gym seed data it absorbs, name resolution from raw logged strings, and the user-facing exercise-library/preference/custom-exercise models.

## Files

| File | What it is |
|---|---|
| `CustomExercise.swift` | `CustomExercise` — a user-defined exercise (name, `MovementPattern`, classification, default rep range, notes/video). |
| `ExerciseCatalog.swift` | `CatalogExercise` + `MovementPattern` — legacy gym seed data grouped by movement pattern; kept during migration, `MovementCatalog` is the canonical source of truth. |
| `ExerciseLibraryItem.swift` | `ExerciseCategory` (compound/isolation/bodyweight/...) + `ExerciseLibraryItem` display model for the exercise library. |
| `ExerciseLibrarySearch.swift` | Exercise-library search model: `ExerciseLibrarySearchSignals` (Recent/Favorite badges), `ExerciseLibraryCompatibilityState`, `ExerciseLibrarySearchResult`, `ExerciseLibraryContextFilter`. |
| `ExercisePreference.swift` | `ExercisePreferenceStatus` (available / substitute / avoid — the YES/SUB/NO marks) + `ExercisePreference` record. |
| `MovementCatalog.swift` | `enum MovementCatalog` — assembles the canonical `definitions: [MovementDefinition]` list from skill-tree definitions + every `ExerciseCatalog` exercise. |
| `MovementCatalog+ClassificationAssociations.swift` | Associated classification metadata: `substitutionGroup`, `skillAssociations`, `contraindicationTags`, logger mode/metric, and `exerciseAliases` for logged-name matching. |
| `MovementCatalog+ClassificationBodyRegions.swift` | `bodyRegions(for:)` — which `BodyRegion`s an exercise (or raw muscle group list) trains, with isolation-exercise overrides. |
| `MovementCatalog+ClassificationIdentity.swift` | Rank-standard identity tables: `variantRankStandardNames` (variant → rank-standard movement, e.g. "wide grip lat pulldown" → "lat pulldown"), `exerciseSkillTwins` / `skillDrillCanonicalStandard` / `owningSkillId`, and the `exerciseAttributeWeights` feed. |
| `MovementCatalog+ClassificationSelection.swift` | Program-generation selection: `movementSlot` mapping, `alternativeScore` / `programScore` ranking, and equipment capability resolution (`movementCapabilities`, `requiredProgramEquipment`). |
| `MovementCatalog+ClassificationTraits.swift` | Per-exercise traits derived from the exercise name: `blockKind`, `rankTemplate`, `equipment(for:)`, `difficulty`. |
| `MovementCatalog+Definitions.swift` | Additional `MovementDefinition` tables, e.g. `cardioDefinitions` generated from `CardioType` with aliases and attribute weights. |
| `MovementCoaching.swift` | `enum MovementCoaching` — curated form cues + common mistakes for non-skill gym lifts (specific by canonical name, with a `MovementSlot` pattern fallback). `resolved(for:)` is the shared entry the rank detail uses; skill-linked movements borrow their skill node's cues instead. |
| `MovementCatalogTypes.swift` | The catalog's enum vocabulary: `MovementRole`, `MovementLoggerMode`, `MovementVariationTag`, `MovementRankTemplate`, `MovementEquipment`. |
| `MovementCatalogValidation.swift` | `MovementCatalogValidation.issues()` — integrity checks over the catalog (duplicate ids, dangling skill ids, unknown exercise names). |
| `MovementProgress.swift` | `MovementProgressState` — per-user per-rank-standard-movement progress ledger (stored field keeps the legacy AP name) + `RewardLedgerQuantizer` whole-point splitting. |
| `MovementProofMatcher.swift` | `MovementProofMatcher` — strict matching for skill proof and tier criteria (assisted/eccentric variants don't prove a strict skill unless named explicitly). |
| `MovementResolver.swift` | `MovementResolver.resolve(_:)` — turns a raw exercise-name string into a `ResolvedMovement` via catalog normalization, direct lookup, then inference. |

## Where to find X

- **"What movement is this logged string?" (name → identity):** `MovementResolver.swift`, normalization in `MovementCatalog.swift`, alias tables in `MovementCatalog+ClassificationAssociations.swift`
- **Which rank standard a variant rolls up to:** `MovementCatalog+ClassificationIdentity.swift` (`variantRankStandardNames`)
- **Adding or auditing catalog entries:** `MovementCatalog.swift` / `MovementCatalog+Definitions.swift`, validated by `MovementCatalogValidation.swift`
- **Whether a set counts as proof for a skill/tier:** `MovementProofMatcher.swift`
- **Gym exercise list by pattern (program gen, preferences):** `ExerciseCatalog.swift` + `ExercisePreference.swift`
- **Exercise-library UI models (search, categories, custom entries):** `ExerciseLibrarySearch.swift`, `ExerciseLibraryItem.swift`, `CustomExercise.swift`
