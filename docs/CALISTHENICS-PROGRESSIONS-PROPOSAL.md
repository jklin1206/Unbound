# Enhanced Calisthenics Progressions — Consolidated Proposal

**Date:** 2026-05-29 · **Status:** CHECKPOINT (research done, no Swift edited) · **Owner refines the ladders**
**Goal (jlin):** every hard skill ranks across its *real graduated progression* — assisted/band → easier variants → the skill → reps/longer holds — not "1 rep of the impossible move." Earned rank = `RankTier` from where you are on that ladder.

**Per-family detail (the actual per-skill ladders) lives in:**
- `docs/progressions/static-arm-balance.md` — planche, handstand, one-arm handstand
- `docs/progressions/pull-power.md` — muscle-up, OAP, archer, weighted/clapping pulls
- `docs/progressions/advanced-push.md` — HSPU, 90°, planche-pushup, presses
- `docs/progressions/levers-core.md` — front/back lever, L-sit family, german hang
- `docs/progressions/legs.md` — pistol, shrimp, nordic curl

---

## The headline: this is mostly EDITING tier-criteria tables, not restructuring the tree

Every hard node already has a 9-tier `tierCriteria` table (in `*SkillTiers.swift`). The problem is **what's in the low tiers**: today most are a flat "1 → N reps of the full skill" ramp, so Initiate–Apprentice are unreachable until you already own the skill. The fix = **reseat the low/mid tiers onto real assisted/variant/bridge steps**, with `Forged` = first clean rep/hold of the named skill.

**`pp.muscle-up` is already the correct template** — it ships a graduated form-bridge ladder (pull-up+dip → chest-to-bar → banded MU + low-bar transition → first rep). The win is doing for every other hard node what the muscle-up already does. The `TierCriterion` model already supports it (`.reps` / `.variant` / `.compound` / `.seconds`), so adopted ladders are drop-in edits.

---

## Three cross-cutting build-outs (the real work, ranked)

### B1 — Missing catalog exercise tokens (BLOCKS everything; do first)
The new low-tier rungs reference exercises that may not exist in `MovementCatalog` (e.g. `band muscle-up`, `box pistol`, `wall HSPU negative`, `counterbalance shrimp`, `negative nordic curl`, `advanced tuck planche`). If a `.reps(exercise:)`/`.variant` names an exercise the catalog can't resolve, it **silently never matches** — the exact "won't count" trap Phase 0 just surfaced. **~20–30 new catalog tokens** must land (with the Phase-0 unmatched safety now in place to catch any miss). Single largest dependency.

### B2 — Hold-duration capture (the keystone for the entire STATIC family)
`TierCriterion.seconds` exists but `TierCriterionEvaluator` **hard-returns false** — `SetLog` has no duration field, so holds (planche, levers, L-sit, handstand, OAH — *most of the marquee skills*) currently fake graduation with rep proxies. To rank statics by hold-time we need: `SetLog.durationSeconds` + Codable migration + a `bestSeconds` evaluator + a way to **log a hold's seconds in the workout UI** (~6 files + a logging-UI affordance). Until this lands, the static ladders can't be honest. **This is a sub-project, and it gates ~half the hard skills.**

### B3 — Orphan reconciliation (tables ↔ nodes out of sync)
~20+ mismatches: tier-tables with no tree node (`cl.tuck-back-lever`, 10 `ld.*` ids incl. `assisted-pistol`/`dragon-pistol`, the dead `HspuSkillTiers.swift`), and nodes whose ladder needs new intermediate rungs. Plus the **One-Arm Handstand gap** (only 3 near-terminal nodes — its whole balance lead-up chain is missing, ~4 new nodes) and a nordic-curl double-gating bug (two nodes gate on the same logged name). Reconcile: add node, or delete table, per case.

---

## Recurring traps (for whoever implements)
- **RankTier displayName swap:** author by case name, render by `displayName` (peak = `.ascendant` case → shows "Unbound"; `.unbound` case → shows "Ascendant").
- **`#if DEBUG` invariants:** each skill must keep 9 tiers; the per-file table counts are asserted — keep them satisfied.
- This rides on the **skill redesign** (`docs/SKILL-REDESIGN-PROPOSAL.md`): kill the fake attendance `currentLevel`/`mastered`, `NodeState`→locked/proven (tolerant decoder FIRST), earned rank = these `tierCriteria`→`RankTier` ladders.

---

## What needs the owner (you)
1. **Refine the ladders** (your domain) — the per-family docs have proposed variant-per-tier ladders; correct them with what you know (esp. the bridge steps + the OAH lead-up chain).
2. **Decide B2 (hold-seconds capture)** — it's a real sub-project but it's the gate for planche/levers/L-sit/handstand/OAH. Do it (statics graduate honestly) or defer (statics stay rep-proxy for now)?
3. **Sequencing** — recommend: skill-redesign cleanup → B1 catalog tokens → ladder table edits (per family) → B3 orphans → B2 hold-seconds (its own pass). 
