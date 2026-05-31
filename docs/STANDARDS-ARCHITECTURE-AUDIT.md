# Standards Architecture Audit — single-source consolidation

**Goal:** every rank standard for every movement defined **exactly once**, in files
organized by category (**skills / ranked movements / unranked**), zero duplicates.
This documents the current scattered state (from a 4-agent code audit) and the
proposed target architecture. No code changed yet — this is the plan.

---

## Part 1 — Where standards live today (scattered)

### A. Skill rank standards (bodyweight skills) — the *good* pipeline
Data-grounded, single shape, but the anchor tables are spread across 8 files:
- `SkillTierGenerator.swift` → `PullSkillAnchors` (pull, 26 nodes) **+ the generator**
- `Tiers/CalSkillTiers.swift` → `PushSkillAnchors` (push, 24)
- `Tiers/ClSkillTiers.swift` → `CoreSkillAnchors` (core/levers, 30)
- `Tiers/HsSkillTiers.swift` → `HandstandSkillAnchors` (14)
- `Tiers/LdSkillTiers.swift` → `LegsSkillAnchors` (24)
- `Tiers/OahSkillTiers.swift` → `OneArmHandstandSkillAnchors` (2)
- `Tiers/PlSkillTiers.swift` → `PlancheSkillAnchors` (5)
- `Tiers/CoSkillTiers.swift` → **hand-authored (NOT generated), and DEAD** (conditioning is filtered out of the graph)

Flow: `SkillAnchor → SkillTierGenerator → node.tierCriteria → RankService.computeTier`.
**Inconsistency:** `PullSkillAnchors` is the only anchor table not co-located with its tier file.

### B. Loaded-movement standards — `StrengthStandards.swift` (legitimate, mostly clean)
- Compound bw-ratio tables: squat/bench/deadlift/OHP/row (male + female) — **no duplicates, keep.**
- Accessory families F1–F9 (male + female) — **no duplicates, keep.**
- `weightedPullupAddedKg` `[0,0,5,12,18,25,32,40,60]` — **conflicts with a skill** (see dup #3).

### C. The duplicate bodyweight ladders — the core mess
The same bodyweight rep/hold thresholds are authored in **three** places:
1. Skill tree anchors (B-grounded, the real source)
2. `StrengthStandards.repLadders` / `holdLadders`
3. `RankService.bodyweightRepRank` / `holdRank` (inline)

### D. Name resolution / catalog layer — also duplicated
- **3 normalizers**: `MovementCatalog.normalized` (strips punctuation), `StrengthStandards.normalize` (keeps it), `RankService.normalizedKey` (trim+lower).
- **2 divergent variant→standard maps**: `MovementCatalog.variantRankStandardNames` vs `StrengthStandards.compoundAliases` — and they **conflict** (e.g. `plate loaded row` → `machine row` in one, `barbell row` in the other).
- **`accessoryFamilyMap`** re-lists ~120 `ExerciseCatalog` names by hand.
- **regression-term list** `["assisted","band","banded","machine","negative","jumping","eccentric","partial"]` duplicated in **3 places** (`MovementProofMatcher`, `RankService.isRegressionOnlyBodyweightKey`, `MovementResolver.inferAliasBase`).

### E. Unranked — fragmented across 3 mechanisms
- `StrengthStandards.unrankedNames` (the real "earns XP, no badge" list — lateral raises, kickbacks, pallof, kettlebell swing, etc.)
- `MovementRankTemplate.unranked` (structural flag on a definition)
- `rankable: false` (skills / routines / cardio / unresolved)

### F. Other threshold definitions found (beyond the 4 known sources)
- `OverallRankTrialService.swift` — **every trial-station floor** (reps / hold-sec / distance / %bw load) hardcoded inline (~30+ stations).
- `BadgeService.swift` — strength milestones: squat ≥2.0×bw, bench ≥1.5×bw, deadlift ≥3.0×bw, push-up ≥50.
- `CapstoneCatalog.swift` / `PrestigeCapstoneCatalog.swift` — per-movement pass targets (plank 90s, pull-up 15, L-sit 20s, …).
- `AttributeValue.rankThresholds` — attribute-XP → tier (different axis; not a movement standard).

---

## Part 2 — Every duplicate, proven

| # | Duplicate | Sources | Verdict |
|---|---|---|---|
| 1 | bodyweight rep/hold ladders (pullup `[0,1,5,10,15,20]`, pushup `[5,15,25,40,60,80]`, dip, l-sit, plank, dead-hang, hollow) | `StrengthStandards.repLadders/holdLadders` **≡** `RankService.bodyweightRepRank/holdRank` (verbatim) | **exact dead copy** — delete one |
| 2 | same 6 bodyweight skills ranked AGAIN with **different** numbers | dup-1 ladders **vs** skill-tree anchors (pullup ladder peak 20 vs skill 32; pushup 80 vs 90; dip 35 vs 44; dead-hang 90 vs 120) | **conflicting** — user gets different tier from `computeTier` vs `computeLiftRank` for the same set |
| 3 | weighted pull-up | `weightedPullupAddedKg` (absolute **kg**) vs `pp.weighted-pullup` skill anchor (**bw-ratio**) | **conflicting units** — pick one |
| 4 | variant→standard map | `variantRankStandardNames` vs `compoundAliases` (conflicting targets) | merge to one |
| 5 | normalizer | `MovementCatalog.normalized` vs `StrengthStandards.normalize` vs `RankService.normalizedKey` | merge to one |
| 6 | regression terms | duplicated 3× | merge to one |
| 7 | accessory family membership | `accessoryFamilyMap` re-lists `ExerciseCatalog` names | derive from one |

---

## Part 3 — Proposed single-source architecture

A new `UNBOUND/Models/Standards/` directory, organized exactly as you asked
(skills / ranked movements / unranked), each standard defined once:

```
Models/Standards/
  StandardsCore.swift        // RankTier (moves here), ONE normalizer, shared TierCriterion/anchor types
  SkillStandards.swift       // THE source for every bodyweight-skill rank.
                             //   - all 7 family anchor tables merged into one keyed registry
                             //   - the SkillTierGenerator
                             //   - the ONLY place pullup/pushup/dip/plank/l-sit/etc. rep/sec thresholds exist
  MovementStandards.swift    // THE source for loaded-lift ranks.
                             //   - compound bw-ratio tables (squat/bench/dl/ohp/row, M/F)
                             //   - accessory families F1–F9 (M/F)
                             //   - weighted pull-up/dip (ONE metric — see decision Q3)
  UnrankedMovements.swift    // THE single "earns XP, no rank badge" authority
  MovementResolution.swift   // ONE normalizer + ONE alias/variant→standard map + ONE regression-term list
```

**Single-source rules after consolidation:**
- A **bodyweight skill** (pullup, pushup, dip, plank, l-sit, dead-hang, handstand, planche, levers, pistol, nordic…) is ranked **only** by `SkillStandards`. `computeLiftRank`'s rep/hold path and `progressToNextRank`'s rep/hold path both route here. **Delete** `repLadders`, `holdLadders`, `ladderAnchors`, `ladderPosition`, `bodyweightRepRank`, `holdRank`.
- A **loaded lift** (barbell/accessory/weighted) is ranked **only** by `MovementStandards`.
- An **unranked** movement is decided **only** by `UnrankedMovements`.
- Name normalization + variant routing + regression veto happen **only** in `MovementResolution`.

---

## Part 4 — Migration (delete-old-in-the-same-change)

1. Move `RankTier` + a single normalizer into `StandardsCore`.
2. Merge the 7 anchor tables into `SkillStandards` (keep generation); re-point `*SkillTiers` routing at it. Move `PullSkillAnchors` out of `SkillTierGenerator`.
3. Add one helper: *rank a bodyweight rep/hold value for an exercise via its skill anchor*. Route `computeLiftRank` (bodyweight path) + `progressToNextRank` (rep/hold path) through it. **Delete** the dup-1 ladders entirely.
4. Collapse the 2 variant maps + 3 normalizers + 3 regression lists into `MovementResolution`.
5. Make `UnrankedMovements` the one authority; `rankTemplate==.unranked`/`rankable==false` reference it, don't re-list.
6. Add a **consistency test**: for every overlapping exercise, `computeTier == computeLiftRank` (locks skills + lifts to one number forever).
7. Run the full 993-test suite; ranks for pullup/pushup/dip/etc. **will shift** to the data-grounded numbers (intended).

---

## Part 5 — Decisions (LOCKED by jlin 2026-05-31)

- **Q1 — Conditioning:** ✅ **Delete entirely** — the 9 dead `co.*` nodes + `CoSkillTiers.swift`.
- **Q2 — Trial / badge / capstone thresholds:** ✅ **Own folder** — `Models/Standards/Gates/` (TrialStandards / BadgeStandards / CapstoneStandards). Kept separate from rank standards (they're pass/fail gates, a different concern), but consolidated out of their inline scatter.
- **Q3 — Weighted pull-up metric:** ✅ **Bodyweight (bw-ratio).** Delete `weightedPullupAddedKg` (absolute kg); weighted pull-up/dip ranked by added-load %bw via the skill system.
- **Q4 — Scope:** ✅ **Staged.** Stage 1 = ranking core. Stage 2 = resolution layer. Gates move is folded into Stage 1 (low-risk relocation).
- **Plus — separate further by category:** skills AND movements each split into per-category files, not two monolith files (see revised Part 3).

### Revised target layout (per "separate further by category")
```
Models/Standards/
  StandardsCore.swift              // RankTier, SkillAnchor/TierCriterion types, SkillTierGenerator, shared
  Skills/
    PullSkillStandards.swift       // PullSkillAnchors  (moved OUT of SkillTierGenerator.swift)
    PushSkillStandards.swift
    LegsSkillStandards.swift
    CoreSkillStandards.swift
    HandstandSkillStandards.swift
    PlancheSkillStandards.swift
    OneArmHandstandSkillStandards.swift
    SkillStandardsRegistry.swift   // merge all family tables → one keyed registry + generate()
  Movements/
    CompoundStandards.swift        // squat/bench/dl/ohp/row (M/F)
    AccessoryStandards.swift       // F1–F9 (M/F)
    WeightedBodyweightStandards.swift  // weighted pullup/dip as %bw added load
    MovementStandardsRegistry.swift
  UnrankedMovements.swift          // the one "earns XP, no badge" authority
  MovementResolution.swift         // ONE normalizer + ONE alias map + ONE regression list  (Stage 2)
  Gates/
    TrialStandards.swift           // from OverallRankTrialService
    BadgeStandards.swift           // from BadgeService
    CapstoneStandards.swift        // from Capstone/PrestigeCapstone catalogs
```

### Staging
- **Stage 1 (correctness + structure):** scaffold `Standards/`; delete conditioning; collapse dup-1/dup-2 (route bodyweight rep/hold ranking through skill anchors, delete `repLadders`/`holdLadders`/`bodyweightRepRank`/`holdRank`); weighted-pullup → bw-ratio; split skill anchors into per-family files (move `PullSkillAnchors` out); split movement tables into per-category files; move gates into `Gates/`; add the `computeTier == computeLiftRank` consistency test; full-test verify.
- **Stage 2 (resolution layer):** merge 3 normalizers / 2 variant maps / 3 regression lists into `MovementResolution`; everything routes through it.

---

## Part 6 — What shipped (2026-05-31)

| Stage | Commit | Result |
|---|---|---|
| 1a — delete conditioning skill family | `38fcb8e` | −701 lines; kept the program-gen conditioning DAY (load-bearing) |
| 1b — single-source bodyweight rep/hold ranking | `46ff65a` | dup-1/dup-2 killed; `SkillStandards` + `SkillRankConsistencyTests` lock the two paths together |
| 1c — weighted pull-up → %bw | `0b751fc` | dup-3 killed; ranked off `pp.weighted-pullup` node |
| 1d — split movement standards by category | `5c127de` | `CompoundStandards` / `AccessoryStandards` / `UnrankedMovements`; `PullSkillAnchors` co-located |
| 2 — resolution layer | (this) | `MovementResolution` (one regression list + one simple normalizer) |

986 tests pass throughout. Rank shifts (1b/1c) checkpointed + approved: the
rank-up cinematic/badges now read the data-grounded skill-tree numbers the
skill card already showed, instead of the old over-generous lift ladders.

### Corrections to the original audit
- **Conditioning was not fully dead** — it also powered a live program-gen
  training day; only the skill family was removed (decision: keep the day).
- **Regression list = 2 copies, not 3** — `MovementResolver.inferAliasBase`'s
  word-checks are bespoke alias routing, a different concern (left alone).
- **Two "normalizers" of the three are identical** (trim+lower); the third
  (`MovementCatalog.normalized`) is a genuinely different rich normalizer and
  was intentionally left as its own single source.

### Deliberately deferred (behavior-sensitive, needs a balance call)
- **Variant maps** `StrengthStandards.compoundAliases` ↔
  `MovementCatalog.variantRankStandardNames` overlap but **conflict** on some
  entries — merging changes matching results, so it's a design decision, not a
  mechanical dedup. Left separate.
- **Gates** (trial/badge/capstone thresholds) — not relocated this pass; their
  thresholds are still inline. Folder move (Q2) deferred as low-value churn.
