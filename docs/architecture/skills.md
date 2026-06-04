# Skills

Skills are graph nodes with prerequisites and one clear proof target. The graph should be explainable as: locked until prerequisites are met, proven after the target is hit.

## Active Model

- `SkillNode.tier` is placement difficulty.
- `SkillNode.placementRank` exposes that difficulty as a `RankTier` for display/weighting.
- `NodeState` stores only `locked` or `proven`.
- Legacy persisted values (`attempting`, `achieved`, `mastered`) decode into the two-state model.
- The user's earned skill rank comes from proof and `UserSkillTierState`, not from `NodeState`.

## Owners

- `UNBOUND/Models/SkillTree.swift`: graph types, requirements, state decoding.
- `UNBOUND/Models/SkillTreeContent.swift`: authored skill nodes.
- `UNBOUND/Models/SkillDisplayTree.swift`: top-level display grouping.
- `UNBOUND/Services/SkillProgress/SkillProgressService.swift`: proof ingestion and node unlocks.
- `UNBOUND/Models/Standards/SkillStandards.swift`: skill standard matching.

## Cleanup Notes

Avoid "mastered" as a stored state. If the UI needs a top-end label, derive it from `RankTier` and keep the persistence model as locked/proven.
