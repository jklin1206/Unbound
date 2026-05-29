# Skill-Redesign — Families Checkpoint Summary

**Date:** 2026-05-29 · **Branch `main` after `f7e4a32`** · **Status: audits done, awaiting jlin's ladder refinement**

Foundations shipped & live:
- **F1** (`76339f8`) — killed the fake attendance ladder (`currentLevel`/`mastered`/`SkillRank`); skills now earn a `RankTier` from logged proof via `tierCriteria`. `NodeState` → `locked`/`proven` (tolerant decoder). 969 tests.
- **F2** (`f7e4a32`) — honest hold-seconds (`SetLog.durationSeconds`); `TierCriterionEvaluator.seconds` works. Statics can rank by real hold-time. 976 tests.

The families pass = reseat each skill's low/mid `tierCriteria` onto real assisted/variant/bridge rungs (Forged = first clean rep/hold of the named skill). **You refine the ladders; I implement per family with a checkpoint.** Per-family detail in `CHECKPOINT-{pull-power,advanced-push,legs,statics}.md`.

---

## Cross-cutting findings (the recurring shape)

**The matcher rule (verified across all 4 audits):** a `tierCriterion` exercise name resolves only if it's (a) a `MovementCatalog` exercise, (b) a **live** node's self-registered criterion alias, or (c) its own verbatim logged string. **Orphan-table-only names resolve to nothing** → silently never match ("won't count"). Regression words are guarded: `assisted / band / banded / machine / negative / jumping / eccentric / partial` are blocked **unless the criterion itself names the regression** (so band/negative bridge rungs must spell it out — the proposals do). `wall`, `pike`, `box`, `counterbalance`, `elevated` are **not** guarded (some proposal-doc notes were wrong on this).

**DEBUG asserts:** all count table keys, not node parity — so they pass while orphans hide. Only **pull-power's assert is stale** (asserts 38, dict has 39) → blocks any `Pp` edit until reconciled. All others (Cal 34, Hs 20, Pl 10, Hspu 10, Oah 2, Cl 37, Co 10, Ld 34) match.

---

## Decision queue for jlin (by theme)

### 1. B1 — net-new catalog tokens to add (the universal blocker; nothing ranks until these resolve)
- **Pull:** `false grip ring row`, `banded ring muscle-up`, `negative muscle-up`, `archer chin-up`, `one-arm chin-up negative`, `typewriter pullup`
- **Push:** `pike HeSPU`, `tripod-to-tuck negative`, `bent arm press (kick-assisted)`, `straddle planche pushup` (opt); use existing `wall handstand` instead of `wall handstand hold`
- **Legs (10):** box pistol, negative pistol, box shrimp squat, counterbalance shrimp, elevated shrimp squat, weighted shrimp squat, band/partial/negative/weighted nordic curl — **plus** 3 that look "EXISTS" but are orphan-only (`assisted pistol`, `elevated pistol`, `dragon pistol` — catalog only has the different string `assisted pistol squat`)
- **Statics:** `tuck back lever` (bites a LIVE node — gates straddle/full back-lever Initiate/Novice → currently un-rankable). Inert orphan-only: `frog pose`, `one-arm planche`, `reverse-hand plank`.

### 2. Forged mis-anchors to fix (Forged should = first clean rep/hold, not N reps)
Pull: 7 nodes (ring-MU, archer, clapping, heighted-chin, strict-MU, OAC, OAP). Push: `cal.handstand-pushup` (Forged=3). Legs: pistol/shrimp/nordic (Forged=5). Statics: planche low tiers are pushup-rep proxies.

### 3. B3 — bugs & structural (some are near-pure fixes, but all touch gating → your call)
- **Pull:** reconcile the stale `PpSkillTiers` assert (38→39).
- **Legs:** **nordic double-gate** — `ld.advancing-nordic-curl` + `ld.nordic-curl` both gate on `nordic curl`; the *easier* node reaches 12 reps while the *harder* Forges at 5 (inversion). Needs distinct logged names or re-gating.
- **Statics:** `cl.german-hang` **circular prereq** — it's T3 but its prereq `cl.tuck-front-lever` is T4, and its Forged needs skin-the-cat (T4, which itself needs german-hang). `cl.hanging-leg-raise` monotonicity (T4+ tiers consume rep counts before its node ranks them).
- **Dead code (delete-in-same-commit per [[delete-old-code-on-change]]):** `HspuSkillTiers` fully dead (10 keys, 0 nodes, dispatch wired at `SkillTreeContent.swift:45`). **But** several orphan `pl.*`/`hs.*`/`ld.*`/`cl.*` tables are candidates to *promote to nodes* in the reseat, not delete — so **orphan add-vs-delete is a per-family content call**, not a blanket purge.

### 4. Design gaps needing your input
- **One-Arm Handstand** is the biggest: only 2 nodes, gated on a freestanding-HS + HSPU **rep** (strength proxy). The whole balance lead-up is missing. Statics doc proposes **4 new nodes** (close-hand straddle+shift → 2-finger tent → 1-finger tent → fingertip float), named skill landing at Vessel — needs your design pass.
- **Which holds convert to `.seconds`** now that F2 is live (levers/L-sit/german/dead-hang currently binary `.variant`/rep-proxy — cheap swap, but you set the hold-time anchors).

### 5. Model constraints the proposals hit
- `.compound` is **AND-only** → legs.md's "Unbound = weighted-pistol OR dragon-pistol" isn't expressible as one criterion (needs OR-across-tiers or a pick).
- `cl.three-sixty-pulls` **does** have a (flat) ladder in `ClSkillTiers` — pull-power.md STEP-4 said it was missing; a reseat there edits `ClSkillTiers`, not `PpSkillTiers`.

---

## Recommended sequence once you refine
Per family: (1) add its B1 tokens to `MovementCatalog`; (2) reseat its `tierCriteria` (your refined ladders) + fix Forged anchors; (3) resolve its orphans (add-node or delete-table) + fix that family's B3 bug; (4) reconcile the DEBUG assert; (5) build + full test; (6) push. Then wire `evaluateTierCrossings` into the completion flow (the deferred tier-crossing connection) so the earned-tier reward beat goes live — recommend doing it **after** the first family lands so there's a real graduated ladder behind it.
