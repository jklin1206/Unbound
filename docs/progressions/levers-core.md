# Levers + Core Statics — Graduated 9-Tier Progression Proposal

**Scope:** `cl.*` (levers + core statics) and `co.*` (conditioning holds) families.
**Status:** RESEARCH + PROPOSAL ONLY. No Swift edited. Numbers below are the proposed
authoring source for the per-skill `tierCriteria` tables (`ClSkillTiers.swift`,
`CoSkillTiers.swift`).

The 9 RankTiers (from `Models/SkillTier.swift`, raw 0–8):

| ord | case | displayName | role in a hold ladder |
|---|---|---|---|
| 0 | `.initiate` | Initiate | easiest variant, short test hold |
| 1 | `.novice` | Novice | easiest variant, building |
| 2 | `.apprentice` | Apprentice | easiest variant owned / next variant entry |
| 3 | `.forged` | Forged | **first solid hold of the named variant** (anchor) |
| 4 | `.veteran` | Veteran | named variant, longer |
| 5 | `.master` | Master | named variant strong / harder variant entry |
| 6 | `.vessel` | Vessel | harder variant |
| 7 | `.unbound` | **"Ascendant"** (label) | harder variant, long |
| 8 | `.ascendant` | **"Unbound"** (peak label) | longest hold / hardest variant |

> **Label gotcha (load-bearing):** the enum case `.unbound` displays as **"Ascendant"**
> and case `.ascendant` displays as **"Unbound"** (the peak). This was a deliberate
> label-only swap (`SkillTier.swift:42-48`) so the top badge reads "Unbound". When the
> task says "Unbound = peak," that is the `.ascendant` case. All tables below are keyed
> by **case name**, so they're correct regardless of display label.

---

## CRITICAL FINDING — these ladders already exist, but as binary `.variant()` checks, not seconds

Every `cl.*` and `co.*` node **already has a fully-populated 9-tier `tierCriteria` table**
(`ClSkillTiers.swift` = 37 skills × 9 tiers, `CoSkillTiers.swift` = 10 × 9; both `#if DEBUG`
assert exactly 9 tiers each). They already cascade tuck → straddle → full. **So the
"graduated ladder" structure is shipped — what's missing is the *seconds metric*.**

Today every hold tier uses one of:
- `.variant("front lever")` — binary "did the user ever log a set named X" (no duration);
- `.compound([.variant("X"), .reps(N, exerciseName: "Y")])` — pairs the variant with a
  *rep* proxy (e.g. toes-to-bar, hanging leg raise) to fake graduation.

`TierCriterion` **does** have a `.seconds(Int)` case (`TierCriterion.swift:13`), but:

```
// TierCriterionEvaluator.swift:23
case .seconds:
    // No seconds tracking on SetLog — see file header comment.
    return false
```

**`.seconds` is dead.** `SetLog` (`WorkoutLog.swift:29`) carries only
`weightKg`, `reps`, `rpe`, `isWarmup` — **no duration field reaches the evaluator.**
Holds are logged by stuffing seconds into the `reps` slot
(`TrainingSessionAdapters.swift:161`: `reps: set.reps ?? set.holdSeconds ?? set.durationSeconds ?? 0`),
so the evaluator reads a 10-second L-sit as "10 reps." Any `.seconds(t)` criterion authored
today returns `false` forever → the user can never rank up on it.

**This is the single biggest build-out (see Gaps §).** The seconds ladders below are given
anyway, as requested — they're the target once capture lands.

---

## Canonical sourcing

OG2 charts derive from the FIG Code of Points; Steven Low's operative rule is hold-based
graduation, not a fixed standard ([stevenlow.org](https://stevenlow.org/overcoming-gravity/),
[OG2 charts PDF](https://stevenlow.org/wp-content/uploads/2017/02/OG2ChartsPrint.pdf)):

- **Test-in:** you may attempt the next harder variant once you can hold the current one
  ~3×15–20 s; you "own" the new variant when you can hold it ≥10 s.
- **Graduate-out:** once a variant is held ~3×20 s (some coaches 30 s), move to the harder one.

I anchored each ladder so **Forged = a clean first hold of the *named* variant** (≈5–10 s,
matching each node's existing `target` seconds), low tiers = the easier variant at short
seconds, peak = a long hold or the next-harder variant. Sources per skill cited inline.

Variant nomenclature used below (front/back lever): tuck → **advanced tuck** → (one-leg) →
straddle → full. The tree currently has **no advanced-tuck or one-leg node** — flagged as NEW.

---

## FRONT LEVER  — `cl.tuck-front-lever` / `cl.straddle-front-lever` / `cl.full-front-lever`

Tree nodes (existing): tuck (T4, target `hold "tuck front lever" 10s`), straddle (T5, `hold 5s`),
full (T6, `hold "front lever" 5s`). **Adv-tuck and one-leg are NOT in the tree** (gap).
Sources: [Heavyweight Cali](https://heavyweightcali.com/en/front-lever-progression/),
[The Movement Athlete](https://themovementathlete.com/front-lever-progression/),
[Berg Movement](https://www.bergmovement.com/calisthenics-blog/front-lever-progressions).

### `cl.tuck-front-lever` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | tuck FL | 3 |
| Novice | tuck FL | 5 |
| Apprentice | tuck FL | 8 |
| **Forged** | **tuck FL** | **10**  ← node target |
| Veteran | tuck FL | 15 |
| Master | advanced tuck FL | 5 |
| Vessel | advanced tuck FL | 10 |
| Ascendant *(case .unbound)* | advanced tuck FL | 15 |
| Unbound *(peak, case .ascendant)* | advanced tuck FL | 20 |

### `cl.straddle-front-lever` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | advanced tuck FL | 10 |
| Novice | one-leg FL (worst side) | 5 |
| Apprentice | straddle FL | 3 |
| **Forged** | **straddle FL** | **5**  ← node target |
| Veteran | straddle FL | 8 |
| Master | straddle FL | 12 |
| Vessel | straddle FL | 15 |
| Ascendant | straddle FL | 20 |
| Unbound *(peak)* | straddle FL | 30 |

### `cl.full-front-lever` (EXISTING node, keystone)
| tier | variant | seconds |
|---|---|---|
| Initiate | straddle FL | 10 |
| Novice | straddle FL | 15 |
| Apprentice | full FL | 3 |
| **Forged** | **full FL** | **5**  ← node target |
| Veteran | full FL | 8 |
| Master | full FL | 10 |
| Vessel | full FL | 15 |
| Ascendant | full FL | 20 |
| Unbound *(peak)* | full FL | 30 |

---

## BACK LEVER — `cl.straddle-back-lever` / `cl.full-back-lever`

Tree nodes (existing): straddle (T5, `hold "straddle back lever" 5s`, prereq `cl.skin-the-cat`),
full (T5, `hold "back lever" 5s`). **`cl.tuck-back-lever` HAS a tier table in `ClSkillTiers.swift`
(lines 243-253) but NO node in `SkillTreeContent.swift`** — orphan table / missing node (gap).
Adv-tuck and one-leg also absent.
Sources: [Calisthenics Hub](https://www.calisthenics-hub.com/guides/back-lever-tutorial),
[The Movement Athlete](https://themovementathlete.com/back-lever-workout/).

### `cl.tuck-back-lever` (NEW node — table exists, node missing)
| tier | variant | seconds |
|---|---|---|
| Initiate | german hang | 5 |
| Novice | tuck BL | 3 |
| Apprentice | tuck BL | 5 |
| **Forged** | **tuck BL** | **10** |
| Veteran | tuck BL | 15 |
| Master | advanced tuck BL | 5 |
| Vessel | advanced tuck BL | 10 |
| Ascendant | advanced tuck BL | 15 |
| Unbound *(peak)* | advanced tuck BL | 20 |

### `cl.straddle-back-lever` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | advanced tuck BL | 10 |
| Novice | one-leg BL | 5 |
| Apprentice | straddle BL | 3 |
| **Forged** | **straddle BL** | **5**  ← node target |
| Veteran | straddle BL | 8 |
| Master | straddle BL | 12 |
| Vessel | straddle BL | 15 |
| Ascendant | straddle BL | 20 |
| Unbound *(peak)* | straddle BL | 30 |

### `cl.full-back-lever` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | straddle BL | 10 |
| Novice | straddle BL | 15 |
| Apprentice | full BL | 3 |
| **Forged** | **full BL** | **5**  ← node target |
| Veteran | full BL | 8 |
| Master | full BL | 12 |
| Vessel | full BL | 15 |
| Ascendant | full BL | 20 |
| Unbound *(peak)* | full BL | 30 |

---

## L-SIT FAMILY — `cal.l-sit-10` / `cl.semi-straddle-l-sit` / `cl.straddle-l-sit` / `cl.v-sit` / `cl.vertical-l-sit`

Tree nodes (existing): base L-sit lives at **`cal.l-sit-10`** (T4, `hold "l-sit" 10s`, cal prefix →
`CalSkillTiers.swift`), then `cl.semi-straddle-l-sit` (T5, 10s), `cl.straddle-l-sit` (T6, 10s),
`cl.v-sit` (T5, 10s), `cl.vertical-l-sit` (T6, 5s). **Foot-supported and tuck L-sit are NOT
nodes** (the canonical on-ramp below them) — gap. Note the tree's order is L-sit → semi-straddle →
straddle, and a parallel V-sit → vertical-L-sit branch; the canonical literature also inserts a
*tuck L-sit* before full L-sit, which the tree skips.
Sources: [GMB](https://gmb.io/l-sit/), [Antranik](https://antranik.org/advanced-l-v-manna-progressions/),
[Heavyweight Cali](https://heavyweightcali.com/en/l-sit-progressions/).

### `cal.l-sit-10` (EXISTING node — **cal prefix → edit `CalSkillTiers.swift`, not Cl**)
| tier | variant | seconds |
|---|---|---|
| Initiate | foot-supported L-sit (one heel down) | 10 |
| Novice | tuck L-sit | 10 |
| Apprentice | one-leg L-sit | 8 |
| **Forged** | **full L-sit** | **10**  ← node target |
| Veteran | full L-sit | 15 |
| Master | full L-sit | 20 |
| Vessel | full L-sit | 30 |
| Ascendant | full L-sit | 45 |
| Unbound *(peak)* | full L-sit | 60 |

### `cl.semi-straddle-l-sit` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | full L-sit | 10 |
| Novice | full L-sit | 15 |
| Apprentice | semi-straddle L-sit | 5 |
| **Forged** | **semi-straddle L-sit** | **10**  ← node target |
| Veteran | semi-straddle L-sit | 15 |
| Master | semi-straddle L-sit | 20 |
| Vessel | straddle L-sit | 10 |
| Ascendant | straddle L-sit | 15 |
| Unbound *(peak)* | straddle L-sit | 20 |

### `cl.straddle-l-sit` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | semi-straddle L-sit | 10 |
| Novice | semi-straddle L-sit | 15 |
| Apprentice | straddle L-sit | 5 |
| **Forged** | **straddle L-sit** | **10**  ← node target |
| Veteran | straddle L-sit | 15 |
| Master | straddle L-sit | 20 |
| Vessel | straddle L-sit | 30 |
| Ascendant | straddle L-sit | 45 |
| Unbound *(peak)* | straddle L-sit | 60 |

### `cl.v-sit` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | full L-sit | 20 |
| Novice | high / "tuck" V-sit (legs ~45°) | 3 |
| Apprentice | V-sit | 3 |
| **Forged** | **V-sit** | **10**  ← node target |
| Veteran | V-sit | 15 |
| Master | V-sit | 20 |
| Vessel | V-sit | 30 |
| Ascendant | V-sit | 45 |
| Unbound *(peak)* | V-sit | 60 |

### `cl.vertical-l-sit` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | V-sit | 15 |
| Novice | V-sit | 20 |
| Apprentice | vertical L-sit | 2 |
| **Forged** | **vertical L-sit** | **5**  ← node target |
| Veteran | vertical L-sit | 8 |
| Master | vertical L-sit | 10 |
| Vessel | vertical L-sit | 15 |
| Ascendant | vertical L-sit | 20 |
| Unbound *(peak)* | vertical L-sit | 30 |

---

## SHOULDER STATIC — `cl.german-hang`

Tree node (existing): T3, `hold "german hang" 10s`, prereq `cl.tuck-front-lever`. This is a
mobility hold; tuck-front-lever (also a hold) is the tree's tuck-back-lever on-ramp. There is no
"easier german hang variant" — graduation here is purely seconds at increasing shoulder depth,
then crossing into skin-the-cat reps. Source:
[Steven Low fundamentals](https://stevenlow.org/the-fundamentals-of-bodyweight-strength-training/).

### `cl.german-hang` (EXISTING node)
| tier | variant | seconds |
|---|---|---|
| Initiate | german hang (shallow / assisted) | 5 |
| Novice | german hang | 8 |
| **Apprentice / on-ramp** | german hang | 10  ← node target |
| **Forged** | **german hang** | **15** |
| Veteran | german hang | 20 |
| Master | german hang | 30 |
| Vessel | german hang | 45 |
| Ascendant | german hang | 60 |
| Unbound *(peak)* | german hang | 90 |

> Note: `cl.skin-the-cat` (T4, reps target) and `cl.three-sixty-pulls` (T6, reps) are in the
> same chapter but are **rep/dynamic** skills, not holds — their existing rep ladders are
> correct and untouched here.

---

## `co.*` HOLD NODES — `co.dead-hang-45` / `co.dead-hang-60`

Both are duration targets (45 s / 60 s) but currently ladder on **pull-up reps**, not seconds
(`CoSkillTiers.swift:121-146`). If seconds capture lands these should become true grip-hold
ladders. Other `co.*` (carries, runs, row, bike) are load/distance/time, not static holds — out of
scope for a seconds metric; their existing `.exerciseBodyweightRatio` / `.variant` ladders stand.

### `co.dead-hang-45` (EXISTING node) — proposed seconds ladder
| tier | variant | seconds |
|---|---|---|
| Initiate | dead hang | 10 |
| Novice | dead hang | 20 |
| Apprentice | dead hang | 30 |
| **Forged** | **dead hang** | **45**  ← node target |
| Veteran | dead hang | 60 |
| Master | dead hang | 75 |
| Vessel | dead hang | 90 |
| Ascendant | dead hang | 105 |
| Unbound *(peak)* | dead hang | 120 |

### `co.dead-hang-60` (EXISTING node) — proposed seconds ladder
| tier | variant | seconds |
|---|---|---|
| Initiate | dead hang | 30 |
| Novice | dead hang | 45 |
| Apprentice | dead hang | 50 |
| **Forged** | **dead hang** | **60**  ← node target |
| Veteran | dead hang | 75 |
| Master | dead hang | 90 |
| Vessel | dead hang | 105 |
| Ascendant | dead hang | 120 |
| Unbound *(peak)* | dead hang | 150 |

---

## GAPS + BIGGEST BUILD-OUTS (ranked)

1. **[BLOCKER] Seconds capture does not exist.** `SetLog` has no duration field; the
   `.seconds` evaluator branch hard-returns `false` (`TierCriterionEvaluator.swift:23`). Every
   seconds ladder above is inert until this ships. **Required work:**
   - add `durationSeconds: Int?` to `SetLog` (`WorkoutLog.swift:29`) — needs a Codable migration
     (tolerant decode; nil for old logs);
   - persist hold seconds into that field at log time instead of cramming them into `reps`
     (`TrainingSessionAdapters.swift:161` is the current cram site);
   - implement `bestSeconds(for:in:)` and wire the `.seconds` case in `TierCriterionEvaluator`
     (and mirror in `PrereqClearer.swift:144`, `TrialsService.swift:438`, the `ProofEngine`/
     `MovementCatalog` switches that currently lump `.seconds` with weight cases).
   This is the **single biggest build-out** — it's a data-model + migration + evaluator change
   touching ~6 files, not just an authoring-table swap.

2. **Authoring swap (cheap, once #1 lands).** Replace the `.variant`/`.compound(reps proxy)`
   entries for the ~11 hold skills above with `.seconds(t)` (or `.compound([.variant(name),
   .seconds(t)])` to also pin the variant). Pure data edits in `ClSkillTiers.swift`,
   `CalSkillTiers.swift` (for `cal.l-sit-10`), `CoSkillTiers.swift`. The `#if DEBUG` count
   asserts (37 / 10 / 9-per-skill) must stay satisfied — keep all 9 tiers.

3. **Missing intermediate nodes (tree-shape gap).** Canonical progressions need variants the
   tree lacks. To honor "low tiers = easier hold variant," either (a) author them only inside the
   tier tables as `.variant("advanced tuck front lever")` etc. (no new nodes — cheapest), or
   (b) add real nodes. Missing:
   - **advanced-tuck front lever**, **one-leg front lever** — no node;
   - **tuck back lever** — **has a tier table (`ClSkillTiers.swift:243`) but no node** (orphan;
     either add the node or delete the table to keep them in sync);
   - **advanced-tuck / one-leg back lever** — no node;
   - **foot-supported L-sit**, **tuck L-sit**, **one-leg L-sit** — no nodes (the L-sit on-ramp).
   Whichever variant strings get used in tables must also exist as loggable exercises /
   `MovementProofMatcher` aliases, or `.variant("…")` never matches.

4. **`cal.l-sit-10` lives under the `cal` prefix, not `cl`.** The base L-sit ladder must be
   edited in **`CalSkillTiers.swift`**, even though the rest of the L-sit family is `cl.*`. Easy
   to miss.

5. **Display-label trap.** Author tables by **case name**. The peak hold (`.ascendant` case)
   shows as "Unbound"; `.unbound` case shows as "Ascendant." Don't let the seconds for the
   longest hold land on the wrong case.

---

## Skills covered (11 hold skills across 3 families)

- **Front lever (3):** `cl.tuck-front-lever`, `cl.straddle-front-lever`, `cl.full-front-lever`
- **Back lever (3):** `cl.tuck-back-lever` *(table-only, node missing)*, `cl.straddle-back-lever`, `cl.full-back-lever`
- **L-sit family (5):** `cal.l-sit-10`, `cl.semi-straddle-l-sit`, `cl.straddle-l-sit`, `cl.v-sit`, `cl.vertical-l-sit`
- **German hang (1):** `cl.german-hang`
- **Conditioning holds (2):** `co.dead-hang-45`, `co.dead-hang-60`

Rep/dynamic skills in the same chapters (`cl.skin-the-cat`, `cl.three-sixty-pulls`, the crunch/
sit-up/rollout/leg-raise families) keep their existing rep ladders — out of scope for a seconds
metric.
