# LEGS — Graduated Calisthenics Progression Proposal

**Family:** LEGS (`ld.*` — Leg Dominance cluster)
**Scope:** Research + proposal only. **No Swift edits.** Proposes graduated 9-tier ladders for the hard single-leg / posterior-chain skills, mapping each skill's *real-world progression* (assisted/easier variant → the skill → reps → harder variant / weighted) onto the app's nine `RankTier`s.

## The 9-tier ladder (canonical)

Source of truth: `UNBOUND/Models/SkillTier.swift` (`enum RankTier`).

| rawValue | case | displayName |
|---|---|---|
| 0 | `.initiate` | Initiate |
| 1 | `.novice` | Novice |
| 2 | `.apprentice` | Apprentice |
| 3 | `.forged` | Forged |
| 4 | `.veteran` | Veteran |
| 5 | `.master` | Master |
| 6 | `.vessel` | Vessel |
| 7 | `.unbound` | **Ascendant** |
| 8 | `.ascendant` | **Unbound** (peak) |

> ⚠️ **Label flip (load-bearing).** The displayName of tiers 7 and 8 is *swapped* on purpose: `.unbound` (raw 7) renders "Ascendant", `.ascendant` (raw 8) renders "Unbound" — "Unbound" is the brand peak. This doc uses the **displayNames** in the prompt's order (Initiate·Novice·Apprentice·Forged·Veteran·Master·Vessel·Ascendant·Unbound). The Swift `case` token in each table's footer is what you'd actually write in `LdSkillTiers.table`.

## How tiers are currently authored vs. what's proposed

- **Today** (`UNBOUND/Models/SkillTreeContent/Tiers/LdSkillTiers.swift`): each `ld.` skill already has all 9 tiers, but most are a **single-exercise rep ramp** on one logged exercise name (e.g. `ld.pistol-squat` is `pistol squat` 1→2→3→5→8→10→12→15→20 reps). Lower tiers are *fewer reps of the full skill*, not an *easier variant*.
- **Proposed** (this doc): make the ladder **graduated by variant** — low tiers = the assisted / box / partial-ROM / negative regression, **Forged ≈ first clean rep of the named skill**, top tiers = rep volume then a harder variant or added load. This matches how the cited sources actually teach the progression and keeps the skill reachable for a beginner (you can rank up on the regression before you own the skill).

Each tier criterion uses the existing `TierCriterion` enum (`UNBOUND/Models/TierCriterion.swift`): `.variant(name)`, `.reps(n, exerciseName:)`, `.exerciseBodyweightRatio(r, exerciseName:)`, `.compound([...])`. **No new criterion shapes are needed.** The cost is new logged-exercise *names* (catalog entries) for the regression variants.

---

## Existing hard `ld.` tree nodes (the build target)

From `UNBOUND/Models/SkillTreeContent.swift`. "Hard" = `rank` C and up, the keystone, and the loaded variants.

| node id | title | tree tier | type | target (`NodeRequirement`) | prereq | rank |
|---|---|---|---|---|---|---|
| `ld.shrimp-squat` | Shrimp Squat | 4 | skill | 3 × shrimp squat | `ld.bulgarian-split-squat` | C |
| `ld.pistol-squat` | Pistol Squat | 4 | skill (keystone) | 5 × pistol squat | `ld.deep-squat` | C |
| `ld.weighted-pistol` | Weighted Pistol | 5 | strength | 3 × weighted pistol @ 0.5× bw | `ld.pistol-squat` | B |
| `ld.nordic-curl` | Nordic Curl | 6 | skill | 3 × nordic curl | `ld.advancing-nordic-curl` | A |
| `ld.advancing-nordic-curl` | Advanced Nordic Hip Hinge | 5 | skill | 5 × advanced nordic hip hinge | `ld.nordic-hip-hinge` | B |
| `ld.weighted-sl-calf` | Weighted Single-Leg Calf Raise | 4 | strength | 10 × single-leg calf raise @ 0.5× bw | `ld.calf-raise` | C |
| `ld.floor-to-ceiling-squat` | Floor to Ceiling Squat | 5 | skill (mythic) | 1 rep | `ld.jumping-squat` | S |

**Supporting intermediate progressions already in the tree (the on-ramps):**
`ld.goblet-20` (Half Squat, T1) → `ld.split-squat` (T2) → `ld.bulgarian-split-squat` (T3) → `ld.deep-squat` (hold, feeds pistol) ; `ld.step-up` → `ld.calf-raise` ; `ld.glute-bridge` → `ld.single-leg-glute-bridge` → `ld.nordic-hip-hinge` → `ld.advancing-nordic-curl` → `ld.nordic-curl` ; `ld.jumping-squat` → `ld.box-jump`. Quad path: `ld.leg-extensions` → `ld.sissy-squat`.

### ⚠️ Gap: tier-table ids with NO tree node (rank-only "ghost" skills)

These 10 ids exist in `LdSkillTiers.table` (so they rank if logged) but have **no `SkillNode`** in `SkillTreeContent.v3Nodes`, so they never render in the tree:

`ld.assisted-pistol`, `ld.heighted-pistol`, `ld.dragon-pistol`, `ld.jumping-pistol`, `ld.tempo-squat`, `ld.bw-front-squat`, `ld.hip-hinge`, `ld.heighted-split-squat`, `ld.single-leg-rdl`, `ld.100-lunges`.

Three of these (`ld.assisted-pistol`, `ld.heighted-pistol`, `ld.dragon-pistol`, `ld.jumping-pistol`) are *exactly* the canonical pistol-ladder rungs this proposal leans on. They already exist as tier tables — the graduated ladders below can reference them, but to be visible they'd need tree nodes added (flagged in **Build-Out** at the end).

---

## Proposed graduated ladders

> **Legend.** *Variant/exercise* = the movement performed at that tier. *Metric* = the `TierCriterion` to encode. **NEW** = logged-exercise name (catalog string) not currently used by any `ld.` tier; **EXISTS** = name already referenced in `LdSkillTiers.table`. "first clean rep" rungs are bolded.

### 1. Pistol Squat — `ld.pistol-squat`

Canonical ladder (cited): bodyweight squat → split/BSS → single-leg step-down/box → partial (to-box) → assisted (TRX/pole) full ROM → elevated-heel → negative → **full pistol** → reps → weighted/strict. We start the ladder at the box/partial regression (BSS is its own node) and end with a weighted gate (which then hands off to `ld.weighted-pistol`).

| Tier | Variant / exercise | Metric (reps / load) | Node status |
|---|---|---|---|
| Initiate | Box / bench pistol (sit to box, stand on one leg) | 3 reps `box pistol` | **NEW** name |
| Novice | Assisted full-ROM pistol (TRX / pole / doorframe) | 5 reps `assisted pistol` | EXISTS (`ld.assisted-pistol` table) |
| Apprentice | Elevated-heel pistol (heel on small plate) OR negative-only (3–5 s eccentric) | 3 reps `negative pistol` | **NEW** name |
| **Forged** | **Full pistol squat — first clean rep** | **1 rep `pistol squat`** | EXISTS (tree node) |
| Veteran | Full pistol — rep volume | 3 reps `pistol squat` | EXISTS |
| Master | Full pistol — rep volume | 5 reps `pistol squat` | EXISTS |
| Vessel | Full pistol — high volume | 8 reps `pistol squat` | EXISTS |
| Ascendant (raw 7) | Weighted pistol entry | `exerciseBodyweightRatio(0.25, "weighted pistol")` | EXISTS (`ld.weighted-pistol`) |
| Unbound (raw 8, peak) | Heavy weighted **or** strict/dragon pistol | `exerciseBodyweightRatio(0.50, "weighted pistol")` OR 3 reps `dragon pistol` (compound OR) | EXISTS |

*Swift case tokens, top→bottom: `.initiate … .forged(pistol squat 1) … .ascendant(weighted ratio)`. Note the displayName flip — the raw-7 case is `.unbound`, raw-8 is `.ascendant`.*
Sources: MP Calisthenics, BWTA, GMB, PowerliftingTechnique (see end).

---

### 2. Shrimp Squat — `ld.shrimp-squat`

Canonical ladder (cited, VAHVA / Kensui): beginner (reduced-ROM, box under knee) → counterbalance shrimp (arms out) → standard shrimp (back foot lifts) → advanced (hold ankle, knee kisses floor) → elevated / weighted. Prereq is `ld.bulgarian-split-squat`, so the ladder starts at the reduced-ROM beginner shrimp.

| Tier | Variant / exercise | Metric (reps / load) | Node status |
|---|---|---|---|
| Initiate | Beginner shrimp — box/pad under rear knee (reduced ROM) | 3 reps `box shrimp squat` | **NEW** name |
| Novice | Counterbalance shrimp — arms reaching forward, no ankle hold | 3 reps `counterbalance shrimp` | **NEW** name |
| Apprentice | Counterbalance shrimp — volume | 5 reps `counterbalance shrimp` | **NEW** name |
| **Forged** | **Full shrimp squat — hold rear ankle, knee kisses floor, first clean rep** | **1 rep `shrimp squat`** | EXISTS (tree node) |
| Veteran | Full shrimp — volume | 3 reps `shrimp squat` | EXISTS |
| Master | Full shrimp — volume | 5 reps `shrimp squat` | EXISTS |
| Vessel | Full shrimp — high volume | 8 reps `shrimp squat` | EXISTS |
| Ascendant (raw 7) | Elevated shrimp (rear knee descends below standing surface) | 3 reps `elevated shrimp squat` | **NEW** name |
| Unbound (raw 8, peak) | Weighted shrimp (load at chest / hand) | 3 reps `weighted shrimp squat` | **NEW** name |

Sources: VAHVA Fitness, Kensui, StartBodyweight.

---

### 3. Nordic Curl — `ld.nordic-curl` (the classic eccentric → concentric ladder)

Canonical ladder (cited, Stray Dog Strength / Mirafit / E3 Rehab): band-assisted → partial ROM (top range only) → negative-only (slow eccentric, push up with hands) → **full negative to floor** → full curl with concentric → reps. This is the textbook eccentric-first hamstring ladder the prompt names. Prereq is `ld.advancing-nordic-curl` (the negative-biased on-ramp already in the tree).

| Tier | Variant / exercise | Metric (reps / load) | Node status |
|---|---|---|---|
| Initiate | Band-assisted nordic (thick band around chest) | 3 reps `band nordic curl` | **NEW** name |
| Novice | Partial-ROM nordic (top quarter, hands ready) | 5 reps `partial nordic curl` | **NEW** name |
| Apprentice | Negative-only nordic (3–5 s eccentric, push back up with hands) | 3 reps `negative nordic curl` | **NEW** name |
| **Forged** | **Full negative to floor — controlled all the way down, first clean rep** | **1 rep `nordic curl`** | EXISTS (tree node) |
| Veteran | Full nordic with hamstring-driven concentric | 2 reps `nordic curl` | EXISTS |
| Master | Full nordic — volume | 3 reps `nordic curl` | EXISTS |
| Vessel | Full nordic — volume | 5 reps `nordic curl` | EXISTS |
| Ascendant (raw 7) | Full nordic — high volume | 8 reps `nordic curl` | EXISTS |
| Unbound (raw 8, peak) | Weighted / arms-overhead nordic (loaded harder lever) | 3 reps `weighted nordic curl` | **NEW** name |

Sources: Stray Dog Strength, Mirafit, E3 Rehab, Physiopedia, Bret Contreras.

---

### 4. Weighted Pistol — `ld.weighted-pistol` (load-progression skill)

This skill is the *load extension* of the pistol. The graduated ladder is by **added load (bodyweight ratio)**, not variant — it already uses `exerciseBodyweightRatio`. The proposal keeps that shape but re-anchors the **first clean weighted rep at Forged** so the ladder reads "first loaded rep → progressively heavier" instead of starting mid-range.

| Tier | Variant / exercise | Metric (load) | Node status |
|---|---|---|---|
| Initiate | Any weighted pistol logged (light) | `variant("weighted pistol")` | EXISTS |
| Novice | Light load | `exerciseBodyweightRatio(0.10, "weighted pistol")` | EXISTS |
| Apprentice | Light-moderate | `exerciseBodyweightRatio(0.20, "weighted pistol")` | EXISTS |
| **Forged** | **First real loaded pistol** | `exerciseBodyweightRatio(0.35, "weighted pistol")` | EXISTS |
| Veteran | Moderate | `exerciseBodyweightRatio(0.50, "weighted pistol")` | EXISTS |
| Master | Heavy | `exerciseBodyweightRatio(0.65, "weighted pistol")` | EXISTS |
| Vessel | Heavy | `exerciseBodyweightRatio(0.80, "weighted pistol")` | EXISTS |
| Ascendant (raw 7) | Bodyweight on the bar | `exerciseBodyweightRatio(1.00, "weighted pistol")` | EXISTS |
| Unbound (raw 8, peak) | Super-bodyweight | `exerciseBodyweightRatio(1.25, "weighted pistol")` | EXISTS |

> This is **already implemented as-is** in `LdSkillTiers.table` — no change needed. Listed here only to complete the family. The same already-correct load pattern applies to `ld.weighted-bss`, `ld.weighted-split-squat`, `ld.weighted-sl-calf`, `ld.bw-front-squat`, `ld.goblet-20`.

---

### 5. (Supporting) Advanced Nordic Hip Hinge — `ld.advancing-nordic-curl`

This node is the nordic on-ramp (`tier 5`, rank B), and it is *also* the prereq of `ld.nordic-curl`. Its own ladder should stay a clean eccentric-depth ramp (deeper hinge → first nordic-curl-adjacent negative). It already uses `nordic curl` reps 1→12 — recommend re-pointing the low tiers to `nordic hip hinge` / `negative nordic curl` so it doesn't *duplicate* the `ld.nordic-curl` ladder on the same logged name (see Gaps).

---

## Gaps & biggest build-outs

### Data / correctness gaps found
1. **Ghost skills (no tree node).** 10 `ld.` ids have tier criteria but no `SkillNode` → they can rank silently but never appear in the tree (`ld.assisted-pistol`, `ld.heighted-pistol`, `ld.dragon-pistol`, `ld.jumping-pistol`, `ld.tempo-squat`, `ld.bw-front-squat`, `ld.hip-hinge`, `ld.heighted-split-squat`, `ld.single-leg-rdl`, `ld.100-lunges`). The pistol ladder above leans on `assisted pistol` / `dragon pistol` names that already have tables — good — but if you want them visible as nodes that's net-new tree content.
2. **Duplicate logged-exercise name.** `ld.advancing-nordic-curl` and `ld.nordic-curl` *both* gate on the `nordic curl` exercise name. A single logged "nordic curl" set advances **both** skills. The graduated ladder fixes the full nordic but the on-ramp should move off the shared name (use `negative nordic curl` / `nordic hip hinge`).
3. **Lower tiers aren't reachable pre-skill today.** Current tables make Initiate = "1 rep of the full hard skill," so a beginner can't earn even Initiate on a pistol/shrimp/nordic until they already own it. The graduated ladders fix this — low tiers become the regression the user can actually do.

### New catalog exercise names required (the real cost)
The graduated ladders introduce these logged-exercise strings (must exist in the exercise catalog for `.variant` / `.reps` to match — see `CatalogExercise.name`, space-lowercase):
`box pistol`, `negative pistol`, `box shrimp squat`, `counterbalance shrimp`, `elevated shrimp squat`, `weighted shrimp squat`, `band nordic curl`, `partial nordic curl`, `negative nordic curl`, `weighted nordic curl`. (`assisted pistol`, `dragon pistol`, `elevated pistol`/`heighted-pistol` already referenced.)

### Biggest build-outs (ranked by effort)
1. **Catalog wiring (largest).** ~10 new exercise names + their muscle/equipment metadata so they log and match. Without this the graduated tiers silently never trigger. This is the load-bearing prerequisite for everything above.
2. **Rewriting 3 tier tables** (`ld.pistol-squat`, `ld.shrimp-squat`, `ld.nordic-curl`) to the graduated/variant shape — small file edit, but must keep `#if DEBUG` invariants (each table = 9 tiers, all 9 cases present; `LdSkillTiers.table.count == 34`).
3. **Optional: surface the ghost pistol rungs as tree nodes** (`ld.assisted-pistol`, `ld.heighted-pistol`, `ld.dragon-pistol`, `ld.jumping-pistol`) so the visible tree mirrors the graduated ladder. Net-new `SkillNode`s with prereqs + form cues — the heaviest content lift, optional.
4. **De-dupe the nordic on-ramp** name collision (#2 above).

---

## Sources

- MP Calisthenics — Pistol Squat Ultimate Progression Guide: https://www.mpcalisthenics.com/tutorial/pistol-squat-the-ultimate-progression-guide
- Bodyweight Training Arena — Pistol Squat Progression: https://bodyweighttrainingarena.com/pistol-squat-progression/
- GMB — Pistol Squat Progression: https://gmb.io/pistol/
- PowerliftingTechnique — Pistol Squat Progression: https://powerliftingtechnique.com/pistol-squat-progression/
- VAHVA Fitness — How to Shrimp Squat (progressions): https://vahvafitness.com/shrimp-squat-progressions/
- Kensui — Shrimp Squat: https://kensuifitness.com/blogs/news/shrimp-squat
- StartBodyweight — Squat Progression: http://www.startbodyweight.com/p/squat-progression.html
- Stray Dog Strength — Nordic Hamstring Curl / Assisted Nordic: https://straydogstrength.com/blogs/articles/nordic-hamstring-curl
- Mirafit — Nordic Curl Progression & Regression: https://mirafit.co.uk/blog/nordic-curl-progression-and-regression/
- E3 Rehab — How to Perform Nordic Hamstring Curls: https://e3rehab.com/how-to-perform-nordic-hamstring-curls/
- Physiopedia — Nordic Hamstring Curl Exercise: https://www.physio-pedia.com/Nordic_Hamstring_Curl_Exercise
- Bret Contreras — The Nordic Ham Curl: https://bretcontreras.com/nordic-ham-curl-staple-exercise-athletes/
