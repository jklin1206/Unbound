# Recovery

Recovery answers "which areas have been trained recently, and how fresh are they?"

## Active Model

`MuscleHeatGroup` is a status/recovery model. It is not a rank ladder and should not be used as proof that the user is "good" at a muscle group.

## Owners

- `UNBOUND/Models/MuscleHeatGroup.swift`: group definitions and status.
- `UNBOUND/Services/TrainingCompletionService.swift`: body load fanout from completed work.
- `UNBOUND/Services/Progression/MovementProgressService.swift`: movement-load helper paths.

## Cleanup Notes

Keep recovery copy separate from rank copy. If UI needs a badge, label it as freshness/load/status, not ability.
