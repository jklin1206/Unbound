# Skill-Rank Migration — one standard per skill, RankTier everywhere

**Date:** 2026-05-30 · **Status:** SCOPE (for jlin checkpoint, no migration code yet)

**The locked model:** a skill ranks on the 9-tier **RankTier** (consistent with movements), computed from **ONE standard** (best ÷ the skill's standard → shared band; ratio 1.0 = Forged, ≈3× = peak) + a **%-to-next-rank bar** for depth. Deletes the per-node 9-tier `tierCriteria` tables (~1,350 criteria). Prototype shipped (`aef0eb4`, pull family).

---

## What's live today (what we're replacing)
- **`*SkillTiers.swift`** (Cal/Cl/Co/Hs/Oah/Pl/Pp/Ld): per-node `[SkillTier: TierCriterion]` — ~1,350 hand-authored criteria. **← deleted.**
- **`TierCriterionEvaluator`** + **`RankService.computeTier`**: evaluate a node's tier from those 9 criteria. **← replaced by `SkillRankEngine`.**
- **`RankService.evaluateTierCrossings`** (currently unwired): would set per-skill RankTier from the tables. **← rewired to the standard.**
- **`node.target`** (NodeRequirement) — flips locked/proven. **← kept** (still the "can you do it" gate) and is the natural source for most standards.
- **`UserSkillTierState.perSkill`** (per-skill RankTier) + **aggregate overall rank** (Phase 7) + the **%-to-next-rank bar** (Phase 6). **← kept**, now fed by standard-derived tiers.
- This session's **family reseats** (pull/push/legs/statics tier tables) — **superseded/deleted** with the tables (git keeps them).

---

## Migration phases (staged, each build+test gated, checkpointed)

**A — Standards data (~150 numbers, mostly derivable).**
Author a `SkillRankStandard` per skill node: metric (reps/seconds/bwRatio) + one `standard` (Forged anchor) + difficulty `weight`. Default the `standard` from `node.target`'s value and `weight` from `node.tier`; jlin refines. Per-family tables (Pull done; add Push/Legs/Statics/Core/Conditioning).
*Output:* `{Cluster}SkillStandards` tables replacing `{Cluster}SkillTiers`.

**B — Engine swap.**
Point `RankService.computeTier(skill:)` at `SkillRankEngine.rank` (best ÷ standard → RankTier). Wire it into the completion flow (the deferred tier-crossing connection) so per-skill RankTier updates from logged proof. Confirm `perSkill` + aggregate update live.

**C — Delete the old (same commit as B per discipline).**
Remove the 8 `*SkillTiers.swift` files, `TierCriterionEvaluator`, and `TierCriterion.*` IF unused elsewhere (**OPEN: trials** — `TrialsService`/`OverallRankTrial*` switch on `TierCriterion`; verify before deleting, may need its own adapter). Keep `node.target`. Reconcile all the `#if DEBUG` count asserts + the per-cluster `*SkillTiersTests`.

**D — Skill-card + constellation UI.**
Skill card shows **RankTier + %-to-next-rank bar** (reuse the Phase-6 bar component). Constellation colors each node by its tier. Remove any 9-tier-table-driven skill UI.

**E — Overall rank.**
Confirm the Phase-7 aggregate reads `perSkill` RankTier + the new difficulty weights (a ★-equivalent on a hard skill counts more). Family-balance gate optional (deferred — only if we want "weakest link" capping).

**F — Prereqs (optional, separate).**
Soften hard prereq gating → visual guidance only (kills the original double-down). Independent of A–E; can ship later.

---

## Open decisions for jlin
1. **The shared band curve.** Current: ratio 1.0 → Forged, ≈3× → peak (sub-Forged spans Initiate→Forged linearly; above spans Forged→peak). Bless or tune (e.g. where "you own it" sits, how fast the top is).
2. **Standards authoring.** ~150 nodes × one number. Auto-default from `node.target` + `tier`, then you refine the ones that matter? Or hand-set the flagships and auto the long tail?
3. **Trials dependency (the real blocker to deleting `TierCriterion`).** Trials currently consume the tier tables. Keep `TierCriterion` for trials + a small adapter, or migrate trials to standards too? (Investigate in Phase C.)
4. **Difficulty weight source.** Reuse `node.tier` (1–7, already authored) as the weight, or the 1×/2×/4×/7×/12× council scale?
5. **Prereqs (Phase F).** Soften to soft-edges now, later, or never.

## Sequencing recommendation
Pull family is the proven slice. Do **A+B+C for one family end-to-end** (pull) wired into the live skill card (extend D to real), checkpoint the feel on device, then roll the remaining families the same way — one coherent push each, exactly like the reseats. Trials adapter (open #3) gets resolved before the first deletion.
