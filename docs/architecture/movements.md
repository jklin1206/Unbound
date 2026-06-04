# Movements

Movements are the canonical exercise definitions that logging, progression, attributes, recovery, and rewards all refer to.

## Active Model

`MovementCatalog` and `ExerciseCatalog` define what can be logged. Each movement carries enough metadata to resolve:

- rank template
- body regions
- attribute weights
- aliases and rollups
- skill links when a logged movement can prove a node

Rank standards live with `StrengthStandards` and skill/bodyweight ladders, not in UI code.

## Owners

- `UNBOUND/Models/MovementCatalog.swift`: app movement definitions and helpers.
- `UNBOUND/Models/ExerciseCatalog.swift`: gym exercise seed catalog.
- `UNBOUND/Models/MovementProgress.swift`: persisted progress state and ledger structs.
- `UNBOUND/Models/MovementProofMatcher.swift`: stricter proof matching for skill nodes.
- `UNBOUND/Services/Progression/MovementProgressService.swift`: movement ingest and ledgers.

## Cleanup Notes

The catalog should not become the place for every policy. Keep data definitions here; move validation, compatibility bridges, and progression policy into named services.
