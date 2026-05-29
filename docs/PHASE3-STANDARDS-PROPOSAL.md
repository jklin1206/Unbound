# Phase 3 — One-Metric Cleanup: Bodyweight-Relative Strength Standards Proposal

**Status:** CHECKPOINT — review before implementation. No Swift modified.
**Goal:** Every weighted movement returns exactly one `RankTier` from a bodyweight-relative strength standard sourced from StrengthLevel, replacing the absolute-kg `LiftTierCriteria`.
**Source approved by owner:** StrengthLevel (strengthlevel.com/strength-standards). Ratios below were fetched live 2026-05-29 from the per-lift `/kg` pages (their published bodyweight-multiple bands).

---

## 0. The 9 tiers (target ladder)

`RankTier` (UNBOUND/Models/SkillTier.swift): `initiate(0) novice(1) apprentice(2) forged(3) veteran(4) master(5) vessel(6) unbound(7) ascendant(8)`.

---

## A. Current-state map

There are **three** parallel strength-standard mechanisms today. This is the mess Phase 3 collapses.

| Mechanism | File | Unit | Live consumers | Status |
|---|---|---|---|---|
| `StrengthStandards` (ratio anchors E–S, interpolated → `RankTier`) | `UNBOUND/Models/StrengthStandards.swift` | **bodyweight ratio** | `RankService.computeLiftRank` (the live per-set rank path), `RankService.aggregateRank` (family-tier mean) | **KEEP / extend** — this is the one true path |
| `LiftTierCriteria` (absolute kg per tier) | `UNBOUND/Models/LiftTierCriteria.swift` | **absolute kg** | `ExerciseLibraryViewModel.criteriaTable` (library "next benchmark" text), `ProfileView.liftTier`, `SettingsView.liftTier`/dev seeders | **DELETE** |
| `MovementCatalog` ladder engine (`MovementTierStandard` / `MovementStandardLadder` / `tierStandards(for:)`) | `UNBOUND/Models/MovementCatalog.swift` (L260–772) | bodyweight ratio + reps/seconds/etc. | **NONE in production** — only `UNBOUNDTests/Models/MovementResolverTests.swift` (L224, 593, 607–617) | **DEAD — delete (see E)** |

### A.1 Movements that ALREADY have a ratio standard (`StrengthStandards.table`)

| Lift (canonical key) | E | D | C | B | A | S | Notes |
|---|---|---|---|---|---|---|---|
| back squat | 0.50 | 1.00 | 1.25 | 1.75 | 2.25 | 2.75 | |
| bench press | 0.50 | 0.75 | 1.00 | 1.25 | 1.75 | 2.10 | |
| deadlift | 0.75 | 1.25 | 1.50 | 2.00 | 2.75 | 3.25 | |
| overhead press | 0.30 | 0.45 | 0.60 | 0.80 | 1.00 | 1.25 | |
| weighted pullup | — | — | — | — | — | — | uses **added-kg** anchors (0/5/15/25/40/60), not a ratio |

Aliases resolve to these (squat→back squat, bench→bench press, ohp/military→overhead press, trap bar/conventional→deadlift, weighted chin/dip→weighted pullup). Interpolation: a logged top-set ratio is placed on the 6 letter anchors (E…S sit at ladder positions 1,4,7,10,13,16), then projected onto the 9-tier ladder via `RankTier.nearest(position/2)`.

### A.2 Weighted movements that rely on `LiftTierCriteria` (absolute kg) today

Only the same 4 keys: **bench press, back squat, deadlift, overhead press**. `LiftTierCriteria` is purely a parallel absolute-kg view of the lifts `StrengthStandards` already covers as ratios — it's redundant, not additive. Used only for library "next benchmark" text and Profile/Settings tier display + dev seeders.

### A.3 Weighted movements with NO standard today (fall back / unranked)

Everything loaded that isn't one of the 5 anchored lifts. The real catalog (`UNBOUND/Models/ExerciseCatalog.swift`, **181 exercises** across 9 patterns) is dominated by these. Examples of loaded accessories with no live ratio standard:

- **Quad/legs (26):** front squat, hack squat, leg press, pendulum/v-squat/belt/smith squat, goblet squat, leg extension, dumbbell step up, bulgarian split squat (loaded), walking lunge…
- **Posterior (23):** trap bar DL (alias→deadlift OK), romanian deadlift, dumbbell RDL, good morning, hip thrust, leg curl, glute-ham raise, reverse hyper…
- **Push-horizontal (23):** incline/decline bench, dumbbell bench, machine chest press, cable fly, weighted dip…
- **Push-vertical (19):** dumbbell shoulder press, arnold press, push press, lateral raise, machine press…
- **Pull-horizontal (18):** barbell row, dumbbell row, t-bar row, cable row, chest-supported row, face pull…
- **Pull-vertical (21):** lat pulldown, weighted pullup (added-kg path), cable pullover…
- **Arms (26):** barbell/dumbbell curl, hammer curl, skullcrusher, pushdown, preacher curl…
- **Calves (6):** standing/seated/leg-press calf raise…

In `MovementCatalog`, `rankTemplate(for:)` (L1057) already auto-classifies every one of these into `.barbellStrength`, `.machineStrength`, `.weightedBodyweight`, `.bodyweightReps`, `.holdControl`, etc. — but because the ladder engine that consumes those templates is dead (A.3 above), today these accessories produce **no rank** through the live `StrengthStandards` path. They are effectively unranked.

---

## B. Proposed bodyweight-relative ratio → RankTier table

### B.1 Band → tier mapping rule

StrengthLevel publishes **5 bands** (Beginner, Novice, Intermediate, Advanced, Elite). We have **9 tiers**. Map the 5 bands onto our 9 by **anchoring the 5 named bands to 5 tiers and interpolating the 4 in-between tiers as the midpoint ratio**:

| StrengthLevel band | RankTier (anchor) | ordinal |
|---|---|---|
| (below Beginner) | initiate | 0 |
| Beginner | **novice** | 1 |
| — interp — | apprentice | 2 |
| Novice | **forged** | 3 |
| — interp — | veteran | 4 |
| Intermediate | **master** | 5 |
| — interp — | vessel | 6 |
| Advanced | **unbound** | 7 |
| Elite | **ascendant** | 8 |

Rule, stated precisely:
- **initiate (0):** below the Beginner ratio (anything logged under Beginner). Floor.
- **novice (1) = Beginner**, **forged (3) = Novice**, **master (5) = Intermediate**, **unbound (7) = Advanced**, **ascendant (8) = Elite**.
- **apprentice (2), veteran (4), vessel (6):** linear midpoint between the two surrounding anchors.
- Mapping rationale: Elite is genuinely rare → top tier; Advanced (a serious lifter) → Unbound (the second crown tier, but reachable); Intermediate (the median committed lifter) → Master, the mid-ladder. This keeps the crown tiers (vessel/unbound/ascendant) aspirational, matching the existing cinematic gating (`isFlagshipMoment >= vessel`).

This is implementable directly on the existing `interpolateLetters` machinery — just feed it 5 anchors at ladder positions {1,3,5,7,8} (or equivalently re-anchor the function) instead of the current 6 E–S anchors at {1,4,7,10,13,16}. **Open question O1 below** asks the owner to confirm this 5→9 anchoring vs. keeping the current 6-anchor E–S scheme and just re-sourcing its numbers.

### B.2 Major lifts — StrengthLevel ratios → tier thresholds

All values are **bodyweight multiples**. Source: strengthlevel.com `/strength-standards/<lift>/kg` (fetched 2026-05-29). Beginner/Novice/Intermediate/Advanced/Elite are CITED from StrengthLevel; apprentice/veteran/vessel are interpolated midpoints (italic-flagged conceptually — marked *interp*).

#### Male

| Tier | Bench | Squat | Deadlift | OHP (shoulder press) | Barbell Row |
|---|---|---|---|---|---|
| initiate (0) | <0.50 | <0.75 | <1.00 | <0.35 | <0.50 |
| novice (1) = Beg | 0.50 | 0.75 | 1.00 | 0.35 | 0.50 |
| apprentice (2) *interp* | 0.63 | 1.00 | 1.25 | 0.45 | 0.63 |
| forged (3) = Nov | 0.75 | 1.25 | 1.50 | 0.55 | 0.75 |
| veteran (4) *interp* | 1.00 | 1.38 | 1.75 | 0.68 | 0.88 |
| master (5) = Int | 1.25 | 1.50 | 2.00 | 0.80 | 1.00 |
| vessel (6) *interp* | 1.50 | 1.88 | 2.25 | 0.95 | 1.25 |
| unbound (7) = Adv | 1.75 | 2.25 | 2.50 | 1.10 | 1.50 |
| ascendant (8) = Elite | 2.00 | 2.75 | 3.00 | 1.40 | 1.75 |

#### Female

| Tier | Bench | Squat | Deadlift | OHP | Barbell Row |
|---|---|---|---|---|---|
| initiate (0) | <0.25 | <0.50 | <0.50 | <0.20 | <0.25 |
| novice (1) = Beg | 0.25 | 0.50 | 0.50 | 0.20 | 0.25 |
| apprentice (2) *interp* | 0.38 | 0.63 | 0.75 | 0.28 | 0.33 |
| forged (3) = Nov | 0.50 | 0.75 | 1.00 | 0.35 | 0.40 |
| veteran (4) *interp* | 0.63 | 1.00 | 1.13 | 0.43 | 0.53 |
| master (5) = Int | 0.75 | 1.25 | 1.25 | 0.50 | 0.65 |
| vessel (6) *interp* | 0.88 | 1.38 | 1.50 | 0.63 | 0.78 |
| unbound (7) = Adv | 1.00 | 1.50 | 1.75 | 0.75 | 0.90 |
| ascendant (8) = Elite | 1.50 | 2.00 | 2.50 | 1.00 | 1.20 |

**Source ratios (StrengthLevel Beg/Nov/Int/Adv/Elite), male / female:**
- Bench: 0.50/0.75/1.25/1.75/2.00 — 0.25/0.50/0.75/1.00/1.50
- Squat: 0.75/1.25/1.50/2.25/2.75 — 0.50/0.75/1.25/1.50/2.00
- Deadlift: 1.00/1.50/2.00/2.50/3.00 — 0.50/1.00/1.25/1.75/2.50
- OHP: 0.35/0.55/0.80/1.10/1.40 — 0.20/0.35/0.50/0.75/1.00
- Row: 0.50/0.75/1.00/1.50/1.75 — 0.25/0.40/0.65/0.90/1.20

> Note: these StrengthLevel numbers differ slightly from the current `StrengthStandards.table` (e.g. current bench E–S 0.50→2.10 vs StrengthLevel-anchored 0.50→2.00; squat S 2.75 matches; OHP current A=1.00/S=1.25 vs StrengthLevel Int 0.80/Elite 1.40). Adopting StrengthLevel makes squat slightly harder at top, OHP slightly harder, bench ~unchanged. **Open question O2.**

### B.3 Dumbbell variants (on StrengthLevel)

StrengthLevel has dumbbell pages; ratios are **per-dumbbell** or **total** depending on lift — to avoid that ambiguity we recommend treating dumbbell variants as a **fixed fraction of the barbell analog** rather than authoring separate tables (DB bench ≈ 0.45× barbell-bench *per hand* ≈ 0.90× total; in practice we rank DB lifts on the same ratio table as the barbell parent because the user logs total load). Variants already alias to a `rankStandardMovementId` parent in `MovementCatalog`, so a dumbbell bench can simply point its standard at `bench press`. **FLAG:** if the owner wants DB-specific difficulty, we'd need per-DB tables — recommend NOT, keep them on the barbell parent's ratio.

---

## C. "Everything weighted gets a standard" — the long-tail plan

We will NOT hand-author 181 tables. Use a **two-source scheme** that leans on metadata `MovementCatalog` already computes:

### C.1 Bespoke (hand-authored) — ~8 anchor standards

Bench, Squat, Deadlift, OHP, Barbell Row (B.2) + Weighted Pullup (added-kg) + Weighted Dip (added-kg) + one machine-press reference. Everything else inherits.

### C.2 Pointer inheritance (free, already wired)

`MovementDefinition.rankStandardMovementId` (default = own id, but settable) already lets a variant borrow a parent's standard. Front squat, safety-bar squat, smith squat, goblet squat → point at `back squat`. RDL, trap-bar DL, good morning → `deadlift`. Incline/decline/DB bench → `bench press`. DB/arnold/push press → `overhead press`. T-bar/DB/cable row → `barbell row`. This covers the big compound variants with **zero new tables**.

### C.3 Family-default scaled by difficulty (the true long tail)

For accessories with no sensible compound parent (curls, lateral raises, leg extensions, calf raises, machine isolations), assign a **family-default ratio curve scaled by `MovementDifficulty`** (`MovementCatalog` already infers beginner/intermediate/advanced/elite per movement, L1127). Proposed default curves (male; female = ×0.55 of male per the average cross-lift StrengthLevel sex gap — see D):

| Movement family (by `MovementSlot`/template) | novice→ascendant ratio band (male) | basis |
|---|---|---|
| Isolation arms/shoulders (curl, lateral raise, pushdown) | 0.10 → 0.50 | scaled down from OHP/row, FLAGGED as estimate |
| Single-joint legs (leg ext, leg curl, calf raise) | 0.25 → 1.25 | scaled from squat ×~0.45, FLAGGED |
| Machine press/row (chest press, machine row) | use `machineStrength` ≈ bench/row ×0.9 | analog |
| Loaded carries | distance + ratio (keep `carrySled` shape) | unchanged |

Then apply a per-movement **difficulty multiplier** to the whole band: beginner ×0.85, intermediate ×1.0, advanced ×1.15, elite ×1.30, so a harder variant in the same family demands more load for the same tier.

**Recommendation:** ship C.1 + C.2 first (covers all compounds = the lifts users actually rank-chase), and gate C.3 behind a flag — most accessories are *assistance* work the user rarely treats as a rank target. **Open question O3:** does the owner want accessories ranked at all, or just the compounds + bodyweight skills? If "compounds only," C.3 is dropped and accessories stay `.unranked` (clean, honest).

---

## D. Sex normalization

- **Primary:** `User.biologicalSex` (`BiologicalSex.male/.female`, `UNBOUND/Models/User.swift` L138) selects the male or female ratio column.
- **Fallback when nil/unset:** use the **male** column (more conservative — female ratios are lower, so using male thresholds for an unknown user under-ranks rather than over-ranks; avoids inflating ranks). Alternative considered: blended midpoint — rejected as it ranks nobody correctly. **Open question O4** if the owner prefers female-default or a neutral blend.
- Bodyweight comes from `User.weightKg` (L12). The existing path already requires `bodyweightKg > 0` and no-ops otherwise — preserve that guard.
- Cross-lift average sex gap (female/male of StrengthLevel ratios) ≈ **0.55**, which is the basis for the C.3 female scaling where no female table exists.

---

## E. Deletion plan

### E.1 Delete outright
1. `UNBOUND/Models/LiftTierCriteria.swift` (whole file).
2. `UNBOUNDTests/Models/LiftTierCriteriaTests.swift` (whole file).
3. Dead ladder engine in `UNBOUND/Models/MovementCatalog.swift`: `MovementTierStandard` (L260), `MovementStandardLadder` (L270), `movementStandardLadders` (L620), `standardLadder(for:)` (L624), `tierStandards(for:)` (L655), and the private generators `strengthRatioStandards`/`addedLoadStandards`/`singleMetricStandards`/`carryStandards` (L709–772) **IF** no production consumer — confirmed only `MovementResolverTests` touches them. Delete those test assertions too (L224, 593, 607–617).
   - *Keep* `MovementStandardMetric`/`MovementStandardComparison` enums only if referenced elsewhere; grep shows they're used solely by the structs above, so they go too.

### E.2 Re-point onto the one ratio path
- `ExerciseLibraryViewModel.criteriaTable` (L136) + `nextBenchmark` text: replace the `LiftTierCriteria.table[...]` lookup with a call into `StrengthStandards` to produce the "next tier needs X× bodyweight (≈ N kg at your weight)" benchmark string. Skill-tree movements keep `node.tierCriteria` (unchanged).
- `ProfileView.liftTier` (L582) + `SettingsView.liftTier` (L1677) + `seedLiftTiers`/`applyBestLift` dev seeders: replace `LiftTierCriteria.table` weight-threshold scan with `StrengthStandards.subRank(liftKg:bodyweightKg:exerciseKey:)` (already returns `RankTier`). These call sites currently take only `weightKg`; they must now also pass the user's bodyweight (available from `User.weightKg`).
- `LiftTierService` (UserDefaults tier cache) can stay — it stores a resolved `SkillTier`, not criteria — but its writers must source the tier from `StrengthStandards` instead of `LiftTierCriteria`.

### E.3 Proof grep (must return zero after)
```
grep -rn "LiftTierCriteria" --include="*.swift" UNBOUND UNBOUNDTests | grep -v derivedData
grep -rn "MovementTierStandard\|MovementStandardLadder\|tierStandards\|movementStandardLadders" --include="*.swift" UNBOUND UNBOUNDTests | grep -v derivedData
```

---

## F. Balance sanity-check (does this feel right?)

Using the **male** B.2 thresholds, `RankTier.nearest` rounding, and a ~80 kg lifter where kg is shown.

| Input | Ratio | Resulting tier | Gut check |
|---|---|---|---|
| 1.0× bw bench (80 kg) | 1.00 | **forged (3)** | solid beginner→intermediate, feels right |
| 1.5× bw bench (120 kg) | 1.50 | **vessel (6)** | strong recreational lifter, crown-tier entry — feels right |
| 2.0× bw bench (160 kg) | 2.00 | **ascendant (8)** | competition-grade, top tier — correct |
| 1.5× bw squat (120 kg) | 1.50 | **master (5)** | = StrengthLevel Intermediate, mid-ladder — right |
| 2.5× bw squat (200 kg) | 2.50 | **unbound (7)→ascendant edge** | between Advanced(2.25) and Elite(2.75); interpolates ~7.4 → **unbound** — feels right (elite is 2.75) |

Female cross-check (1 row): 1.0× bw bench female = **unbound (7)** (Advanced), vs male 1.0× = forged (3). The sex normalization is doing real work — a female benching bodyweight is genuinely advanced.

---

## Open questions for the owner

- **O1 (anchoring):** Confirm the 5→9 mapping rule (Beginner=novice, Elite=ascendant, midpoints interpolated). Alternative: keep the current 6-anchor E–S scheme and just re-source its numbers from StrengthLevel.
- **O2 (re-sourcing existing 4):** OK to overwrite the current `StrengthStandards.table` values (squat/OHP get slightly harder at top) with the StrengthLevel-anchored ones in B.2?
- **O3 (accessory scope):** Rank *everything* loaded (build C.3 family-defaults), or compounds + bodyweight skills only (drop C.3, accessories stay `.unranked`)? Recommendation: compounds-only for v1.
- **O4 (sex fallback):** Male-default when `biologicalSex == nil` (recommended), or female/blend?
- **O5 (dumbbell):** Point DB variants at the barbell parent (recommended) or author DB-specific tables?
