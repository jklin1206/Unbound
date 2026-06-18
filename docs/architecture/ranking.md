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
- `UNBOUND/Services/Ranking/OverallRankTrialService.swift`: trial value types (`TrialStation`, `RankTrialFormat`, requirement lines, station results).

## Rank Gates (the eight rank-up trials)

A rank crossing is earned by passing that gate's trial. The eight gates are destination-world
themed (`First Light → The Count → The Forging → Deck of Proof → The Ascent → The Seven Seals →
The Threshold → The Last Gate`). The engine is split by responsibility — keep it that way:

- `OverallRankTrialDefinitions.swift`: the 8 gate definitions and their per-loadout station builders
  (no-gym / home / gym). Floors are read from `TrialStandards`, never hardcoded inline.
- `Models/Standards/Gates/TrialStandards.swift`: every tunable floor (reps, holds, meters, %bw loads,
  caps, qualifying sets), one gate-named enum per gate. `TrialStandardsSnapshotTests` locks them.
- `OverallRankTrialRunner.swift`: draft creation, pass/fail evaluation, completion, rank-advance.
- `RankTrialLoadoutResolver.swift`: picks the loadout variant and resolves dynamic stations.
- `TrialReadinessService.swift`: builds requirement lines (overall level + accumulated rank + gate keys).
- `GateKeys.swift`: named eligibility proofs auto-cleared from real training history (no new logging path).

Station machinery worth knowing:
- `strengthTier` on a station resolves a load floor from `StrengthStandards` at draft + evaluation time
  (the heavy "strike" stations — Forging, Seven Seals Power, Last Gate). Both the rep floor and the load
  floor must be met in the same set.
- `floorOverride` on a movement option gives a per-substitution floor (e.g. rows count for more reps than
  pull-ups). `dynamicGroupKey` groups mutually-exclusive stations (Last Gate's weakest-attribute landing).
- `isScored == false` marks prescribed-but-unscored work (Gate III "Stoke the Fire" warm-up); it is
  reported but excluded from the verdict.
- Gates rename old ids via `legacyIds`; readiness/progress lookups and Codable decode are legacy-tolerant
  so no attempt history is lost.

## Cleanup Notes

Do not reintroduce E-S, `SubRank`, `SkillRank`, or muscle rank concepts. If a value describes status, recovery, display flavor, or difficulty placement, name it that way instead of calling it rank.
