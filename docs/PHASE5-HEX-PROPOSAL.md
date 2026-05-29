# Phase 5 — Attributes Hex: One Number, Slow & Maxable

**Date:** 2026-05-29 · **Status:** PROPOSAL (no Swift edited) · **Plan:** `ONE-METRIC-CLEANUP-PLAN.md` Phase 5

Owner decisions being implemented:
1. Hex **maxes out in YEARS** — a full hex is a long-term achievement, not week-one.
2. Fills **faster the harder/more often you train** (rate scales with volume).
3. Starts as **tiny slivers**, grows, with a **real ceiling you can eventually max**.
4. **ONE number per axis** — collapse the duplicate scales.

---

## 1. Current state (map)

| Concept | Where | Notes |
|---|---|---|
| 6 axes | `AttributeKey.swift` | power · vitality · control · endurance · mobility · explosiveness (`vitality` ← legacy `agility`) |
| The model | `AttributeValue.swift` | holds **three** progression fields: `current` (0–100), `peak` (0–100), `xp` (permanent) |
| The curve | `AttributeLevelCurve` (in `AttributeValue.swift`) | `attrBase=100, exponent=1.5, softCapLevel=100, cappedXPPerLevel=1500`. `level(xp)=floor((xp/100)^(1/1.5))` |
| Overall LVL curve (for contrast) | `OverallLevelCurve` (in `MovementProgress.swift`) | `lvBase=250, exponent=1.5, softCapLevel=100, cappedXPPerLevel=3750` — same shape, bigger pool |
| Hex render value | `AttributeLevelCurve.hexDisplayValue` | `92·(min(L,100)/100)^0.9` + asymptotic prestige push to 99.9 — **never a clean 100** |
| XP earned | `AttributeIngest.xpDeltas` | session AP × movement `attributeWeights` (sum to 1.0) → fans into per-axis xp |
| Legacy score earned | `AttributeIngest.applyDeltas` / `applyXPDeltas` | **also** bumps `current`/`peak` in parallel via `legacyScoreXPScale=50` / `apXPToDisplayScoreScale` bridge |
| Rank (two of them) | `AttributeValue.rankTier`/`rankTitle` **vs** `levelRankTitle` | `rankTitle` = `current/100·8` → `RankTier`; `levelRankTitle` = `level` → `RankTier`. **Two ranks off two scales.** |

**Type note (Phase 1/2 already done):** `RankTier`, `RankTitle`, `SkillTier` are now ONE type — `RankTitle`/`SkillTier` are `typealias`es of `RankTier` (`SkillTier.swift:158-159`). `peakSubRank` is already gone (zero hits). So Phase 5's "collapse" is about the **0–100 score scale**, not the rank enum.

### The actual problem (it's the display + the duplicate scale, not the XP curve)

The XP curve is fine at the very top. The fast-fill feel comes from **two** things:

1. **`hexDisplayValue` front-loads.** `92·(L/100)^0.9` is near-linear, so the bar shows ~big numbers early and never reaches a clean "maxed":

   | Level | Hex shows |
   |---|---|
   | L10 | 12 / 100 |
   | L25 | 26 / 100 |
   | L50 | 49 / 100 |
   | L65 | 62 / 100 |
   | L100 | **92** / 100 (then asymptotes toward 99.9, never 100) |

2. **A whole parallel 0–100 `current`/`peak` scale runs alongside `xp`.** `current` decays (`AttributeDrift`), caps at 100, and drives a *second* rank (`rankTier`/`rankTitle`) plus the hex `peakHexChartValues` ghost. Two sources of truth = the "16 ways to measure" smell this whole cleanup targets.

**Time-to-look-full under the CURRENT system** (primary axis, ~200 XP/session — see §4 for derivation):

| Cohort | Hex hits 50% bar | Hex "looks full" (≥85) |
|---|---|---|
| LIGHT 2/wk | 90 wk | 4.2 yr |
| MED 4/wk | 45 wk | 2.1 yr |
| HEAVY 6/wk | 30 wk | 1.4 yr |

A heavy trainer's hex looks full in ~1.4 yr — the owner's "fills up fast" worry — and it never cleanly *maxes*. We make max slower, the early bar tinier, and the ceiling real.

---

## 2. Proposed curve

**One scale per axis: `xp → level → fill%`. Fill % = `level / MAX`. No display trick.**

```
AttributeLevelCurve (proposed):
    maxLevel       = 100          // clean, reachable ceiling (no softcap tail)
    base           = 28           // cheap first levels → tiny visible slivers
    exponent       = 2.0          // quadratic steepening → real top cliff

    xpRequired(L)  = base · L^exponent              (clamped at L = maxLevel)
    level(xp)      = min(maxLevel, floor((xp/base)^(1/exponent)))
    hexFill(L)     = L / maxLevel                   // 0…1, replaces hexDisplayValue
```

| Level | Cumulative XP | Hex fill | This level cost |
|---|---|---|---|
| L1 | 28 | 1% | 28 |
| L5 | 702 | 5% | 253 |
| L10 | 2,808 | 10% | 534 |
| L25 | 17,550 | 25% | 1,376 |
| L50 | 70,200 | 50% | 2,780 |
| L75 | 157,950 | 75% | 4,184 |
| L90 | 227,448 | 90% | 5,026 |
| **L100** | **280,800** | **100% (MAXED)** | 5,588 |

- **Tiny slivers early:** L1 costs 28 XP; first session lands a new user at L3–L6 (3–6% hex).
- **Real top cliff:** the last level costs **5,588 XP — 200× the first level (28)**. Climbing 99→100 is its own grind.
- **Clean max:** L100 = 100% = a true "maxed it" payoff (the asymptotic 99.9 fudge dies).
- **Total to max one axis ≈ 280,800 XP** ≈ 4.5 years of heavy training on that axis (§5).

### "Fills faster with more training" — already falls out, no extra multiplier

XP is **volume-driven**: `xpRequired` is fixed, but XP *earned* = session AP fanned across axes, and session AP scales with sets × reps × load × RPE (`MovementProgressService.rawAP`). More/harder sessions → more AP → more XP → faster fill. **No rate multiplier is needed** — volume already is the rate. (The existing novelty / under-trained-region multipliers in `xpDeltas` still apply on top, which is correct and Phase-6 territory.)

---

## 3. The collapse — what dies, what re-points

### DELETE (the duplicate 0–100 scale)
| Symbol | File | Why |
|---|---|---|
| `AttributeValue.current` | `AttributeValue.swift` | the decaying 0–100 score — replaced by `xp`-derived level |
| `AttributeValue.peak` | `AttributeValue.swift` | lifetime-peak of the 0–100 score — `xp` never decays, so peak == current ability |
| `AttributeValue.rankTier` (`current/100·8`) | `AttributeValue.swift:121-123` | rank off the dead scale |
| `AttributeValue.rankTitle` (the `AttributeValue` one) | `AttributeValue.swift:125` | duplicate title; **keep `levelRankTitle`, rename it `rankTitle`** |
| `AttributeValue.floor`, `recentBelowLifetimePeak` | `AttributeValue.swift` | peak-relative drift helpers |
| `hexDisplayValue`, `hexPrestigeGlow`, `hexChartValue`, `hexPrestigeGlow` | `AttributeValue.swift` / `AttributeLevelCurve` | replaced by `hexFill(level)`; prestige-glow tied to softcap tail dies |
| `legacyScoreXPScale`, `xpAwarded(forScoreDelta:)`, `legacyXP(forScore:)`, `forScoreDelta` | `AttributeLevelCurve` | the score↔xp bridge — gone once score is gone |
| `apXPToDisplayScoreScale` + `current`/`peak` writes | `AttributeIngest.swift:30,137-139,183-188` | the parallel score bump in both apply paths |
| `softCapLevel`, `cappedXPPerLevel`, the softcap branch | `AttributeLevelCurve` | replaced by hard `maxLevel=100` clamp |
| `AttributeProfile.rankTitles`, `peakHexChartValues`, `prestigeGlowValues` | `AttributeProfile.swift:33-59` | peak/score-derived; keep `hexChartValues` (now from `hexFill`) + `levelRankTitles` |
| `current`/`peak` in `AttributeDrift.project` | `AttributeDrift.swift` | **drift logic deletes entirely** — `xp` doesn't decay; "stale" becomes a recency flag off `lastContributionAt` only (no peak comparison) |
| `peak`/`current` args in `AttributeValue.init`, `zero`, `applySeed`, `applyBoost`, `CodingKeys`, custom Codable | `AttributeValue.swift`, `AttributeService.swift` | seed/boost set `xp` directly instead |

### RE-POINT (call sites that read the dead fields → read `level`/`hexFill`/`xp`)
Grep-confirmed consumers of `.current`/`.peak`/`rankTitle`/`levelRankTitle`:

| Call site | Change |
|---|---|
| `Views/Components/MuscleRadarChart.swift:26-33` | `data.map { $0.current/100 }` → `hexFill(level)` |
| `Views/Components/AttributeHex.swift:133,148` | drop the `legacyXP(forScore:)` fallback; read `level` |
| `Views/Profile/ProfileBuildCard.swift:176-185` | "RECENT"/"PEAK"/"SCORE" chips → "LVL"/"% to next"; uses `levelRankTitle`→`rankTitle` |
| `Views/Profile/BuildAttributeCell.swift:17,31` | `levelRankTitle` → renamed `rankTitle` |
| `Views/Home/HomeBuildChipCard.swift:12`, `ProfileBuildCard.swift:21` | `profile.hexChartValues` (now `hexFill`-based — no view change) |
| `Views/Scan/ScanPayoffView.swift:78`, `ScanBuildDeltaCard.swift:59-63` | `.current` deltas → `level` (or `xp`) deltas |
| `Services/Scan/ScanCheckpointService.swift:71-72` | before/after `.current` → before/after `level` |
| `Models/AttributeProfile.swift:80-124` (`dominant`/`weakest`/`isBalanced`/`buildIdentity`) | swap `.peak` comparisons → `.level` (or `.xp`) |
| `Services/Ranking/OverallRankTrialService.swift:1919` | `.peak` map → `.level` |
| `Settings/SettingsView.swift:1048`, `Onboarding/Step_Verdict.swift:507,891,1301` | `.current` / `legacyXP(forScore:)` debug + verdict → `level` from `xp` |
| `AttributeService.applyBoost` / `applySeed` | set `xp = xpRequired(seedLevel)` instead of `current=peak=15` |
| `AttributeProgressionReward.previousScore/currentScore` | drop (keep `previousLevel`/`currentLevel`/`xp`) |
| `AttributeRankUpEvent.fromSubRank/toSubRank`, `Level.subRank` | collapse to one tier crossing off `level`→`rankTitle` (no sub-rank concept survives) |

**Net:** `AttributeValue` goes from `{peak, current, xp, lastContributionAt}` → `{xp, lastContributionAt}`. One number per axis. `level`, `rankTitle` (the kept one), `hexFill`, `progressToNextLevel` all derive from `xp`.

---

## 4. Per-session XP — how the projection is grounded

From `MovementProgressService.rawAP`: `AP/set = baseAP(10) · metric · intensity · rpe · quality · variation`, quantized to whole points.
- `metric = log1p(reps)` → a 10-rep working set ≈ `10 · 2.40 · 1.0 · (RPE8→1.10) ≈ 26 AP/set`.
- A held position (60s) ≈ 26 AP; a heavy 5-rep ≈ 20 AP.

Session AP (working sets only):

| Session size | Working sets | Total session AP |
|---|---|---|
| Short | 9 | ~240 |
| Typical | 15 | ~400 |
| Big | 24 | ~630 |

Movement `attributeWeights` **sum to 1.0** (verified across all 181 catalog exercises), so **total attribute XP added per session ≈ total session AP**, split across the 2–4 axes the session trains. A **primary** axis (e.g. `control` on a calisthenics day, `power` on a heavy lift day) typically captures 50–65% of the session → **~200 XP/session to the primary axis** (conservative-mid; a 400-AP session × 50% = 200). This is the figure used below. Off-axes accrue slower, which is the intended hex *shape*.

---

## 5. Projection table (the headline)

**Primary axis, proposed curve, ~200 XP/primary-axis/session:**

| Cohort | After Week 1 | 25% (L25) | 50% (L50) | 75% (L75) | **MAX (L100)** |
|---|---|---|---|---|---|
| **LIGHT** 2/wk | L3 · 3% sliver | 10.1 mo | 3.4 yr | 7.6 yr | **13.5 yr** |
| **MED** 4/wk | L5 · 5% sliver | 5.1 mo | 1.7 yr | 3.8 yr | **6.8 yr** |
| **HEAVY** 6/wk | L6 · 6% sliver | 3.4 mo | 1.1 yr | 2.5 yr | **4.5 yr** |

Confirms the owner's headline:
- **Heavy trainer approaches MAX in a believable multi-year window (~4.5 yr).**
- **Light trainer much longer (~13.5 yr)** — a maxed hex is genuinely rare.
- **Nobody maxes in weeks** — even heavy is 25% after ~3 months.
- **New users start as tiny slivers** (3–6% after week 1).

> A real athlete only fully maxes the 1–2 axes their training emphasizes. Maxing all six = a balanced, decade-deep training history — exactly the "full hex is a long-term achievement" the owner wants. (Cross-axis fairness / aggregate rank is Phase 7, not here.)

---

## 6. Open questions for the owner

1. **Target heavy-max horizon — 4.5 yr right?** Curve tuned to it (`base=28, exp=2.0`). Want it harsher (~6 yr → `base≈21`) or softer (~3 yr → `base≈42`)? One-line change.
2. **Decay: keep or drop?** Proposal **drops** the peak-relative `current` decay (xp is permanent — rank is never lost, matching the model comment's intent). The "stale" honest-signal can stay as a pure recency flag (idle > N days) **without** a peak comparison. Confirm you're OK losing the visible "recalibrating / recent-below-peak" UI, or keep a lightweight recency dimming.
3. **Primary-capture % (50–65%).** If real sessions concentrate harder on one axis (e.g. 80%), max comes sooner; if spread thinner, later. Worth validating against a few real `AttributeContributions.json` movements once live data exists.
4. **Onboarding seed.** Today `applySeed` sets `current=peak=15` (≈ a mid sliver). Under xp-only, seed should set `xp = xpRequired(seedLevel)`. What seed level — L0 (true zero, per the plan's "everyone starts Initiate/LVL0") or a small head-start (L3–5)?
5. **`hexFill` linear vs eased.** Fill = `L/MAX` is honest/linear. If you want the *visual* hex to feel more rewarding early without lying about progress, an optional `pow(L/MAX, 0.85)` ease is available — but that reintroduces a display-vs-truth gap, so default is **linear**.

---

## Summary (6 lines)

1. **Current problem:** a parallel 0–100 `current`/`peak` score runs alongside permanent `xp` (two ranks, two scales), and `hexDisplayValue` front-loads + caps at 92/99.9 so a heavy trainer *looks* full in ~1.4 yr and never cleanly maxes.
2. **Proposed curve:** one scale per axis — `xpRequired(L)=28·L^2.0`, `maxLevel=100`, `hexFill=L/100`; total to max ≈ 280,800 XP, last level (5,588 XP) is 200× the first (28).
3. **Time-to-max:** LIGHT ≈ 13.5 yr, MED ≈ 6.8 yr, HEAVY ≈ 4.5 yr; new users sit at 3–6% (tiny slivers) after week 1; nobody maxes in weeks.
4. **Faster-with-volume** falls out for free — XP is session-AP-driven, no extra multiplier needed.
5. **Deleted:** `current`/`peak`, `rankTier`/`AttributeValue.rankTitle` (keep `levelRankTitle`→renamed `rankTitle`), `hexDisplayValue`/prestige-glow, `legacyScoreXPScale`/`xpAwarded`/`legacyXP`/`apXPToDisplayScoreScale`, the softcap branch, peak-relative drift; `AttributeValue` collapses to `{xp, lastContributionAt}`.
6. **Open questions:** confirm 4.5-yr heavy-max horizon, whether to drop decay, the seed level, and linear-vs-eased fill.
