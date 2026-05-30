# Skill-Rank Migration — one standard per skill, RankTier everywhere

**Date:** 2026-05-30 · **Status:** SCOPE (for jlin checkpoint, no migration code yet)

**The locked model (council-reviewed 2026-05-30):** a skill is mastered through **5 discrete pips** on its OWN movement (hand-authored ascending thresholds) + an **honest whole-number tally** to the next pip ("7 / 10 reps" — no fractional bar; reps are chunky). Depth-within-a-node = the metric; depth-across-difficulty = the TREE (harder variations are their own nodes), so **feat nodes keep LOW capped ceilings** (muscle-up 1/2/3/4/5, not /15) and grind nodes get higher ones. Past pip 5 → PB forever. XP→attributes stays the per-session drip, separate from pips. Deletes the per-node `tierCriteria` tables (~1,350 criteria); **keeps `TierCriterion` + `TierCriterionEvaluator`** (trials persist them). Prototype shipped + rewritten to pips (pull family).

> **Council findings that corrected this plan (grounded grep):**
> - The live skill-rank/reward path is **`ProofEngine.evaluate`** (`TrainingCompletionService.swift:79`, reads `node.tierCriteria` at `ProofEngine.swift:150/155/266`) — **not** `evaluateTierCrossings`, which is **dead** (only its own mock calls it, `RankService.swift:467`). Phase B repoints **ProofEngine**.
> - **Keep `TierCriterion`/`TierCriterionEvaluator`**: they're a persisted Codable trial field (`TrialCapstone.swift:13`) + capstone inline literals (`CapstoneCatalog.swift:15`). Delete only the 8 `*SkillTiers.swift` tables. Trials never blocked deletion.
> - **`PrereqClearer.swift:123` prefers `tierCriteria[requiredTier]` over `node.target`** — deleting tables silently shifts prereq thresholds. Drop the table branch deliberately in the same commit.
> - **`aggregateRank` reads `perSkill` ordinals** (`RankService.swift:293`) written only by the dead function. Need a `pip → SkillTier` bridge to feed it; `aggregateRank` itself (reads `tier.rawValue × difficulty`) needs no change.
> - Two competing difficulty weights: `SkillRankStandard.weight` (1–7) vs `RankService.difficultyWeight`(`node.tier`). Pick one before Phase E.

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

## Sequencing recommendation (council's safe commit-by-commit order, pull family)
1. **pip→SkillTier bridge** — additive `SkillRankResult.asSkillTier`, tests only. No deletion. Green.
2. **Repoint ProofEngine for `pp.*` nodes** behind a per-family switch (pull routes to `SkillRankEngine`/`PullSkillStandards`, all others stay on tables). Wire pip→`perSkill`. Keep `TierCriterion`/evaluator. Build+test.
3. **Delete `PpSkillTiers.swift` + its `count==39` assert + `PpSkillTiersTests` + the `PrereqClearer` pull-table branch — same commit.** Verify pull skill card + prereqs + rank-up beat on device.
4. **D/E (UI + aggregate)** once the feel is blessed. Roll the remaining 7 families identically. `TierCriterion`, `TierCriterionEvaluator`, `node.target`, all trial/capstone code stay in place the whole migration.

Checkpoint the device feel after step 3 of each family before pushing (persistence-adjacent + changes the live skill card).
