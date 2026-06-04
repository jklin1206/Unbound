# Levels

LVL answers "how much has this user trained over time?"

## Active Model

`OverallLevelProgress` stores total XP and the current level curve. Training completion, scans/photos, routines, and other approved effort sources should grant LVL through `OverallLevelService`, not through separate counters.

Streak is separate and belongs to consistency, not skill.

## Owners

- `UNBOUND/Models/MovementProgress.swift`: `OverallLevelProgress`, `OverallLevelCurve`, level reward structs.
- `UNBOUND/Services/Progression/MovementProgressService.swift`: `OverallLevelService`.
- `UNBOUND/Services/Ranking/SessionXPService.swift`: streak and session consistency.

## Cleanup Notes

Do not add another app-wide counter. If a feature grants effort, route it through the level service with a source id so retries are idempotent.
