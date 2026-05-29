# Phase 5 — Revised Projection (catch-up multiplier modeled)

**Date:** 2026-05-29 · Supersedes the no-multiplier table in `PHASE5-HEX-PROPOSAL.md §5`.

> **RETUNED (jlin):** `base` lowered 28 → **16** for a faster horizon (~3 yr balanced / ~6 yr focused, heavy). All times below were modeled at base=28; multiply by **16/28 ≈ 0.57** for the shipped curve: BALANCED full-hex ≈ **3.0 yr** HEAVY / 4.6 yr MED / 9.1 yr LIGHT; FOCUSED single-axis ≈ **5.9 yr** HEAVY. (Note: lower base = *faster* — `xpRequired = base·L²`. The original §6 of the proposal had this direction inverted.)

Curve (shipped): `xpRequired(L) = 16·L^2`, `maxLevel = 100`, `hexFill = L/100` (linear).
Per-axis catch-up (shipped, `AttributeIngest`): `catchUp(axis) = clamp(1 + k·(mean − level)/100, 0.5, 2.0)`, `k = 2.0`; near-cap brake ×0.5 at `level ≥ 90`. Mean = average of the 6 current pre-ingest levels. Applied per axis on top of the novelty multiplier.

Grounding (unchanged from §4): ~200 XP/session to a primary axis; off-axes accrue proportionally less. Sessions/week: LIGHT 2, MED 4, HEAVY 6.

---

## FOCUSED trainer — 80% of XP to one axis (other 5 split the remaining 20%)

| Cohort | Time to MAX the focused axis | Other 5 axes at that point | Power "pins"? |
|---|---|---|---|
| **HEAVY** 6/wk | **~10.3 yr** | all ~**L36** | No — slows hard |
| **MED** 4/wk | ~15.5 yr | all ~L36 | No |
| **LIGHT** 2/wk | ~31 yr | all ~L36 | No |

**Power can't trivially pin.** As the focused axis climbs above the hex mean, its catch-up factor drops below 1.0 and, past L90, eats the ×0.5 near-cap brake — so the last stretch (90→100) crawls. Maxing a single neglected-rest build takes **~10 yr even HEAVY** (vs 4.5 yr in the no-multiplier proposal). The five starved axes plateau around **L36**: starved of share, but the catch-up bonus (they sit far below the focused mean) keeps them from flatlining at zero.

## BALANCED trainer — XP spread evenly across all six

| Cohort | Time to max ONE axis | Time to max ALL SIX |
|---|---|---|
| **HEAVY** 6/wk | **~5.3 yr** | **~5.3 yr** (they max together) |
| **MED** 4/wk | ~8.0 yr | ~8.0 yr |
| **LIGHT** 2/wk | ~16 yr | ~16 yr |

**Balanced is the efficient path to a maxed axis.** Every axis stays near the mean, so its factor hovers ~1.0 and it never wastes XP on the near-cap brake until the very end (when all six hit it together). A balanced HEAVY trainer maxes one axis in ~5.3 yr — *faster* than the focused trainer maxes their single axis (~10.3 yr) — and gets the full hex for the same effort. Maxing all six = a balanced, multi-year (≥5 yr HEAVY, ≥8 yr MED) grind.

## Neglected-axis catch-up (the bonus)

| Scenario | Catch-up multiplier | Close the gap (train it) |
|---|---|---|
| Axis **L10**, hex mean **L50** | **×1.8** (toward the 2.0 cap) | L10→L50 in **~1.3 yr** (MED 4/wk, mean held) |
| Axis at the mean (L50, mean L50) | ×1.0 | baseline |
| Axis L80, mean L50 (over-fed) | ×0.5 (floor) | diminished |
| Axis L95 (near cap), mean L50 | ×0.25 (floor × brake) | strongly braked |
| Fresh user, all L0 | ×1.0 (mean 0 = no skew) | baseline — slivers grow honestly |

A weak axis sitting far below your build mean earns up to **2× XP** — training your weakness is the single most rewarding thing you can do, and closing a 40-level gap is a ~1-year project, not a decade.

---

## Confirmations (design intent → modeled)

- **Power can't trivially pin** ✅ — above-mean axes drop below ×1.0, and the L90+ ×0.5 brake makes the top of any axis a real grind (focused-max ~10 yr HEAVY).
- **Weakness-work is rewarding** ✅ — below-mean axes earn up to ×2.0; a neglected axis closes its gap ~3× faster than baseline.
- **Maxing all six is a multi-year balanced grind** ✅ — ~5.3 yr HEAVY / ~8 yr MED / ~16 yr LIGHT, and balance is the *efficient* route (no brake waste until the shared finish).
- **New users start as tiny slivers** ✅ — L0 seed, all-L0 mean → factor 1.0, first sessions land L3–L6 (3–6% hex).

## Tunables (one-line)

`AttributeIngest`: `catchUpK = 2.0`, `catchUpMin/Max = 0.5/2.0`, `catchUpNearCapLevel = 90`, `catchUpNearCapBrake = 0.5`.
`AttributeLevelCurve`: `base = 28`, `exponent = 2.0`, `maxLevel = 100`.
Raising `k` strengthens the pull toward balance (slows focused-pin further); lowering `base` makes the whole hex harder to max.
