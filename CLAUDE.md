# UNBOUND - Claude Code project notes

## How ranking works (read this before touching any rank code)

The one thing to internalize: **a user's rank is earned by passing trials (rank gates), not by any aggregate score.**
The real, displayed rank is `OverallRankTrialStore.currentRank`.
There is no "overall rank" computed from a sum of movement tiers.

### The progression loop (how you rank up)

1. You log movements - bodyweight skills (pull-up, plank, lever) AND gym lifts (bench, squat, deadlift, OHP).
2. Each logged movement adds to your **attribute profile** through its `attributeWeights` (e.g. heavy compounds train Power).
3. Trial **readiness** is gated by `attributesAtRank` gate keys - "have N attributes at rank X" - plus your overall level.
4. When the gate keys are satisfied the next trial becomes `ready`; you attempt it, and **passing it confirms the next rank.**

So lifting genuinely progresses your rank: it feeds your attributes, which unlock the next trial.
This attribute -> gate-key -> trial path is the one that matters.
Never assume a movement "doesn't count" toward rank just because it isn't in some tier table - check whether it feeds attributes.

### Where the trials and their requirements are defined

`OverallRankTrialDefinitions.swift` is THE source for the rank gates.
There are 8 gates, each an `OverallRankTrialDefinition` that confirms one rank:

| Gate | Confirms | Min overall level |
|------|----------|-------------------|
| gate-01 First Light | Novice | 1 |
| gate-02 The Count | Apprentice | 8 |
| gate-03 The Forging | Forged | 15 |
| gate-04 The Reckoning | Veteran | 22 |
| gate-05 The Ascent | Master | 40 |
| gate-06 Seven Seals | Vessel | 55 |
| gate-07 The Threshold | Ascendant | 72 |
| gate-08 The Last Gate | Unbound | 90 |

That file is authoritative; levels and loadouts are tuned there, so do not hardcode these numbers elsewhere.

A gate has two separate things: the trial **loadout** (what you perform) and the **readiness requirements** (what unlocks the attempt).

The loadout is `performanceStandards` / `loadoutVariants` on the definition - the feats you perform, with noGym / home / gym variants, picked for your equipment by `RankTrialLoadoutResolver`.

The readiness requirements are built in `TrialReadinessService.requirementLines` and are exactly three:
1. **Overall level** >= `minOverallLevel`.
2. **Equipment** - your gear must resolve a runnable loadout (`resolution.isReady`).
3. **Gate keys** for the gate's `format`, defined in `GateKeys.swift`. Two kinds, both kept light and achievable:
   - `attributesAtRank` - "have K attributes at rank R" (build-expressive; you pick which axes).
   - `movementsAtRank` - "have K proven movements at rank R" (any skills or the 4 barbell compounds; required rank stays one tier below the gate target, capped at Master). Counted from `gateKeyMovementTiers` = skill tiers (`UserSkillTierStore`) + lift tiers (`LiftTierService`).
   K and R scale per gate; `GateKeys.swift` is the source for the exact numbers, and the final gate also needs `gatesAnswered(7)`.

Both gate keys ultimately reflect your trained exercises (attribute ranks and movement tiers are both derived from what you log).
Historical note: an older opaque per-exercise "accumulated rank" check (`OverallRankTrialRequirementKind.rank`) was folded out (see `docs/AP-GATE-REDESIGN-PROPOSAL.md` §5); the enum case still exists but is not emitted. The current `movementsAtRank` key is the deliberate lightweight successor to that idea.

You are `ready` when all three checks pass; passing the attempt is recorded in `OverallRankTrialStore`, which advances `currentRank` - your real rank.

### The "aggregate" is NOT the rank

`RankService.aggregateTier` / `aggregateRank` is a secondary "demonstrated strength" signal, not the rank.
- `aggregateRank` is passed into trial readiness but is **ignored** there (`requirementLines` never reads it), so it gates nothing.
- `aggregateTier` only floors cosmetic unlocks (`max(confirmedRank, aggregateTier)`) and appears as a stat on home/profile/squad.

It is fed by two local (UserDefaults) tier stores, both written at workout completion inside `RankService.evaluateTierCrossings`:
- `UserSkillTierStore` - per-skill tiers.
- `LiftTierService` - per-barbell-compound tiers (bench / squat / deadlift / OHP).

Treat the aggregate as cosmetic/display only.
If you find yourself saying a change "raises the overall rank," you are almost certainly confusing the aggregate with the trial-confirmed rank.

### Movement standards (single source, no parallel ladders)

- Bodyweight skills rank via `SkillStandards`, which reads each skill node's generated `tierCriteria` - that is THE source.
- Loaded movements (barbell compounds, accessory families, weighted pull-up) rank via `StrengthStandards` on a load / bodyweight ratio.
- For loaded lifts, **Initiate is the x0.00 floor** (any load qualifies); the first real benchmark is Novice.
- That is why loaded lifts show Initiate as "-" in the standards doc - by design, not a bug.

### Gotchas worth remembering

- `SkillTier` is a typealias for `RankTier` - the same 9-value enum (initiate ... unbound).
- `SkillGraph` plus each node's `tierCriteria` is the rank database that skills, proof, program generation, and the rank library all read; the zoomable skill-tree VIEWS are only a presentation layer on top of it.
- The rank library and the skill tree both list the same `SkillGraph` skills and open the same `RankDetailView`.
