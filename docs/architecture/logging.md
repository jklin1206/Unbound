# Logging And Completion

Logging is the app's core write path. A completed workout should enter one canonical coordinator, write idempotently, and return a reward receipt the UI can render.

## Active Model

`TrainingCompletionService.complete()` is the canonical ingest path for modern workout completion. It coordinates:

- movement progress
- skill proof
- overall LVL
- attributes
- body-map/recovery load
- badges/cosmetics
- squad and challenge fanout
- reward receipt fields

Callers should not rebuild this cascade in a view.

## Owners

- `UNBOUND/Services/TrainingCompletionService.swift`: completion coordinator and result.
- `UNBOUND/Services/Progression/MovementProgressService.swift`: movement ledger writes.
- `UNBOUND/Services/Attributes/AttributeService.swift`: attribute ingest.
- `UNBOUND/Models/WorkoutRewardSequence.swift`: reward payload model.
- `UNBOUND/Views/Components/Unbound/WorkoutRewardSequenceView.swift`: reward timeline/orchestration.
- `UNBOUND/Views/Components/Unbound/WorkoutRewardComponents.swift`: reward visual components.

## Cleanup Notes

The next simplification is to split the service by responsibility without changing behavior: receipt/idempotency, progression ingest, reward receipt building, and social fanout.
