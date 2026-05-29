# Rank Vocabulary Consolidation — design + plan

**Date:** 2026-05-29
**Status:** proposed (audit complete, awaiting go on Phase 1)
**Why:** the app has accumulated several overlapping "how good / how hard are you" scales. They confuse users and make the trial-gate redesign impossible to define (no single "tier" currency). This consolidates everything onto **one 9-tier ladder**.

---

## The maze today (from the audit)

| Scale | Steps | Role | Surfaced to user? | Verdict |
|---|---|---|---|---|
| **SubRank** `E−…S+` | 18 (ord 0–17) | internal threshold currency: lift ranks, attribute sub-ranks, aggregate, family tiers; gates realization/peaking, badges, rank-up detection | **No** — every UI projects it through `.title`; the letter grade reaches users in **zero** places (only debug logs) | Visible scale already dead; internal currency load-bearing (~9 gates) |
| **RankTitle** `Initiate…Ascendant` | 9 (String, 1–9) | overall-rank trials, attribute rank titles, **the canonical 9 colors/cosmetics** | Yes | Keep (becomes the unified ladder) |
| **SkillTier** `Initiate…Ascendant` | 9 (Int, 0–8, Comparable) | per-skill/-movement/-lift earned tier; XP-crossing math; trial skill gates | Yes | **Same nine names as RankTitle** — pure duplication |
| **MovementDifficulty** `beginner…elite` | 4 | LV multiplier (VelocityService) + search sort penalty | **No** | Mostly heuristic/keyword/defaulted — untrustworthy, but freely re-ratable |
| **Per-skill TierCriterion tables** | 9/movement | hand-authored thresholds per movement | indirectly (skill tree) | The valuable asset — but calibrated *within* each move |
| **MovementTierStandard** | 9/template | rankTemplate-derived ladders | indirectly | Normalized within template, flat across movements |
| **AttributeLevelCurve / OverallLevelCurve** | numeric | XP→level (+ the 0–100 attribute score) | Yes | Pacing metric — keep, distinct axis from "rank" |

**Two structural problems:**
1. **Duplicate ladder.** `RankTitle` (String) and `SkillTier` (Int) are the *same nine names* with duplicated displayName/art/colors, kept in sync by hand via bridges (`asSkillTier`/`rankTitle`). Maintenance footgun; the cosmetic store even mixes Int and String keys for "the same tier."
2. **Tiers aren't cross-comparable.** Per-skill tiers are calibrated "elite *for that move*" — `pushup`-Ascendant = **100 reps**, `maltese`-Ascendant = one of the hardest holds on earth, **same badge.** There is **no per-movement difficulty anchor** placing a movement on a shared scale. (And `MovementDifficulty`, the only intrinsic-difficulty signal, has no mapping to the 9-tier ladder at all.)

---

## Target model: one ladder, three jobs

**`RankTier` — a single 9-step enum (Initiate → Ascendant)** is the *only* "how good / how hard" language. It does three jobs:
1. **Movement/skill difficulty** — where a movement sits on the shared ladder (its intrinsic hardness anchor + how far you've taken it). This is what the **skill tree's 9 layers** display.
2. **Earned rank** — your tier in a skill/lift/attribute and your overall rank.
3. **Gate currency** — trial gates read "N movements at RankTier ≥ X" against one consistent scale.

- **E−…S+ retires as a visible/ças currency.** It's already invisible; `StrengthStandards` interpolation stays internally but **outputs `RankTier`**, not SubRank. The ~9 logic gates re-express against `RankTier` (the existing 2:1 binning already aligns SubRank 9/12 → Veteran/Vessel).
- **`RankTitle` + `SkillTier` merge into `RankTier`.**
- **`MovementDifficulty` is replaced** by each movement's **anchor on `RankTier`** (curated, not heuristic).
- **Numeric levels (attribute/overall XP) stay** — they're the *pacing* axis (time/effort), orthogonal to rank, and remain the trial's third lever.

### The cross-movement normalization (the real design work)
A movement's **shared-ladder tier = f(intrinsic difficulty anchor, within-movement progress)**. Concretely: each movement gets a **floor and ceiling** on `RankTier`. An easy movement (pushup) is anchored low and **caps low** — 100 pushups can't reach shared-Ascendant; a hard movement (planche) is anchored high and its early progress already lands mid-ladder. This is the "difficulty × progress" rule we want: a hard movement at low within-progress can outweigh an easy movement maxed out. The per-skill TierCriterion tables supply the *within-movement shape*; the anchor supplies the missing *cross-movement zero-point*.
- **Lifts:** anchor by **relative load** (the StrengthStandards ratio), not the movement's difficulty class — a 2.5× bench is elite even though "bench" is a beginner-class movement.
- **Skills/bodyweight:** anchor by **curated intrinsic difficulty**.

---

## Phased plan (each phase ends green; council + UserDefaults round-trip test per the data-layer rule)

**Phase 1 — Merge `RankTitle` + `SkillTier` → `RankTier`.** Mechanical (~1 day). One Int-backed, Comparable enum with a `String token` (for `rank_title_*`/`avatar_frame_*` asset names) and a **tolerant `init(from:)`** that decodes legacy Int blobs (`perSkill`, cosmetic highest) *and* legacy String blobs (trial progress, incl. `"honed"→master`) — so **no on-disk migration**. Collapse the parallel `SubRank.title`/`SubRank.asSkillTier` maps. Repoint ~20 files. No Supabase change (these live only in UserDefaults).

**Phase 2 — Confirm E−S is internal-only; delete the vestigial bits.** ✅ DONE.
The audit corrected this phase's original plan in two ways:
1. **The user-facing goal was already met by Phase 1.** The E−S letter grade is surfaced in **zero** UI — every display projects through `.title` (now a `RankTier`). So there is no visible E−S to "retire."
2. **SubRank's 18 steps are load-bearing**, not dead: they are the engine's fine-grained computation currency for StrengthStandards interpolation, per-lift PR detection, and **attribute rank-up cadence** (`AttributeService`/`AttributeIngest` fire rank-ups on `SubRank.ordinal`, ~2× as often as the 9 `RankTier` bands would). The realization/peaking/badge gates compare `SubRank.ordinal` to thresholds (`bMinus`/`aMinus`/letter) whose boundaries don't sit on `RankTier` band edges.

Therefore Phase 2 did NOT collapse SubRank or re-express the gates (doing so would *coarsen rank-up cadence and shift gate boundaries* — a **product decision**, folded into Phase 3). What Phase 2 did: deleted the genuinely-dead vestigial code (`rankTitleName`, `peakSubRank`/`peakRankTitle`, `usesHolographicShimmer`, `ProfileView.aggregateRank`), fixed the misleading `SubRank.displayName` comment, and scoped `SubRank` as **INTERNAL-ONLY** in code. Net: one user-facing ladder (`RankTier`); `SubRank` is now clearly an invisible engine detail.

**Open product decision (Phase 3 input):** do we *want* rank-ups on the fine 18-step cadence (more frequent, smaller) or the 9-step cadence (rarer, bigger)? If the latter, SubRank can be fully retired then; if the former, it stays as the engine's precision layer permanently. Not a cleanup call — it changes game feel.

**Phase 3 — Curate per-movement difficulty anchors + surface the 9 layers.** Replace heuristic `MovementDifficulty` with a curated `RankTier` floor/ceiling per movement; implement the shared-ladder normalization (difficulty × progress). Surface difficulty in the skill tree (the 9 layers). **This is the content/balance pass** — the part that needs your judgment on placements.

**Phase 4 — Define the trial gates on the unified ladder.** Now "N movements at tier X" is well-defined and cross-fair, the attribute floors + overall-level pacing lever from our earlier design slot in cleanly. (This is the work that was blocked.)

---

## Risk / notes
- No server schema touched — every scale lives in UserDefaults only. Migration = a tolerant decoder, not a data rewrite.
- Phases 1–2 are mechanical/low-risk and immediately reduce confusion. Phase 3 is the judgment-heavy one (it's effectively the difficulty re-rating of the whole catalog). Phase 4 is the original trial-gate goal.
- Surfacing E−S retirement: zero user-visible change (it's already invisible) — purely internal cleanup.
