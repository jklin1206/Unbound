# Ranking

Ranking answers one question: how good is this user at this movement or skill?

## Active Model

`RankTier` is the single rank ladder. Movement rank is computed by the movement template:

- Loaded movement: bodyweight-relative standards in `StrengthStandards`.
- Bodyweight reps: the node or movement rep ladder.
- Holds: the seconds ladder.
- Cardio, carries, and pure mobility: unranked unless a product decision adds standards later.

Overall rank is derived by `RankService` from proven movement/skill ranks, weighted by difficulty and build relevance. It is not a second per-movement ladder.

## Owners

- `UNBOUND/Models/SkillTier.swift`: `RankTier` and display names.
- `UNBOUND/Models/StrengthStandards.swift`: bodyweight-relative rank standards.
- `UNBOUND/Services/Ranking/RankService.swift`: movement rank and aggregate rank.
- `UNBOUND/Services/Ranking/ProofEngine.swift`: proof evaluation.
- `UNBOUND/Services/Ranking/OverallRankTrialService.swift`: ceremony/readiness around overall rank.

## Cleanup Notes

Do not reintroduce E-S, `SubRank`, `SkillRank`, or muscle rank concepts. If a value describes status, recovery, display flavor, or difficulty placement, name it that way instead of calling it rank.
