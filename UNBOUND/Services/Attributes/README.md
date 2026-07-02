# Services/Attributes

Manages the six-axis attribute system (Power, Vitality, Control, Endurance, Mobility, Explosiveness): ingesting workout XP, computing catch-up factors, detecting tier crossings, persisting profiles, and projecting staleness. `AttributeService` is the main entry point; the other files are its catalog, math, persistence, and drift helpers.

| File | Purpose |
|------|---------|
| `AttributeService.swift` | Main service conforming to `AttributeServiceProtocol`; ingests workout logs and movement AP gains into permanent per-axis XP, applies catch-up factors, posts `.attributeRankUp` notifications on tier crossings, and coordinates with `AttributeProfileStore`; also contains `MockAttributeService` for tests |
| `AttributeIngest.swift` | Pure math module: converts a `WorkoutLog` or `[MovementAPGain]` into per-axis XP deltas using effort-mass × intensity × catalog-weight × catch-up factor; also defines `AttributeCatalogProtocol` and the result types |
| `AttributeCatalog.swift` | Loads `AttributeContributions.json` at init and resolves per-exercise and per-skill-node attribute weight vectors, with a resolution chain through `MovementCatalog` before falling back to the exercise name |
| `AttributeProfileStore.swift` | Persists `AttributeProfile` to `UserDefaults` (current profile + pinned scan history); defines `AttributeProfileStoreProtocol` for injection |
| `AttributeDrift.swift` | Pure utility that projects a profile forward to a given date (stamps `computedAt`); XP never decays so staleness is a display-only recency signal off `lastContributionAt` |
| `BuildClassStore.swift` | Hold-window hysteresis for the displayed `BuildClass`: the held `BuildIdentity` only changes after a different live reading holds for 21 days; advanced from `AttributeService`'s persist choke point, read by profile display |

## Where to find X

| Task | File |
|------|------|
| Ingest a finished workout into attribute XP | `AttributeService.swift` (`ingest(session:)` or `ingest(movementAPGains:)`) |
| Look up which attributes an exercise contributes to | `AttributeCatalog.swift` |
| Load or save a user's attribute profile | `AttributeProfileStore.swift` |
| Understand catch-up multiplier tuning constants | `AttributeIngest.swift` (`catchUpK`, `catchUpMin`, `catchUpMax`) |
| Project a profile to today without persisting | `AttributeDrift.swift` (`project(_:to:)`) |
| Apply a direct XP boost (e.g., trial capstone) | `AttributeService.swift` (`applyBoost(axis:amount:userId:)`) |
| Why the profile class name lags the live hex | `BuildClassStore.swift` (`heldIdentity` / `observe`) |
