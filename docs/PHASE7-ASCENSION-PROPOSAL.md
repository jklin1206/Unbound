# Phase 7 — Overall Rank = Accumulation + Ascension Ceremony

**Date:** 2026-05-29 · **Status:** PROPOSAL (checkpoint, no Swift edits) · **Owner sign-off needed**
**Parent:** `docs/ONE-METRIC-CLEANUP-PLAN.md` (Phase 7)

Overall rank = **build-weighted accumulation** of your per-movement `RankTier`s → makes you *eligible* → the **Ascension ceremony** claims it. Two fair gates (accumulation + `minOverallLevel`), then a tiered ceremony. Top rank → existing cosmetics. The omni-max attribute/skill conformity gates get deleted; the gauntlet station/loadout system + runner stay.

---

## 1. Current State (mapped)

### `aggregateRank` today (`RankService.swift:221`)
```swift
func aggregateRank(userId:) async -> RankTier {
    guard let mean = await familyTierRawValueMean(userId:) else { return .initiate }
    return RankTier.nearest(for: mean)   // mean of family-tier rawValues, unweighted
}
```
- Input = **mean of per-family progression-tier rawValues** (`ProgressionStateStore.allFamilyStates → unlockedTier`), mapped through `StrengthStandards.subRank(forFamilyTier:)`.
- **Not difficulty-weighted, not build-weighted, no decay.** A flat average. Returns `RankTier` (Phase 2 done).
- Consumers: `SkillTreeViewModel.aggregateRank` (line 39), `UnboundHomeView` (the displayed rank badge + "next rank momentum"), `UnboundSkillTreeTabView:162`.
- Per-movement ranks (the real signal) live in `computeLiftRank` / `computeTier` and are **not currently fed into the aggregate** — the aggregate uses the coarser family-tier state instead. This is the gap Phase 7 closes.

### Inputs available for the new model
| Input | Source | Use |
|---|---|---|
| Per-movement `RankTier` | `RankService.computeLiftRank` (loaded/rep/hold) + `computeTier` (skills) | the values being accumulated |
| Per-movement difficulty | `SkillNode.tier` (Int 1–7) for tree moves; `StrengthStandards` ratio band for lifts | difficulty **weight** |
| `buildIdentity` | `AttributeProfile.buildIdentity` (`primary`/`secondary`/`shape`) | build **weight** |
| `attributeWeights` per move | `MovementCatalog.attributeWeights` (`[AttributeKey: Double]`) | maps a move → which build axes it serves |
| `isStale` | `AttributeValue.isStale` / per-move `lastContributionAt` | honest **decay** |
| `minOverallLevel` | `OverallRankTrialDefinition.minOverallLevel` | tenure gate (KEEP) |

### `OverallRankTrialService.swift` (2580 lines) — the Ascension apparatus
- **`OverallRankTrialDefinition`**: `targetRank` (RankTier), `minOverallLevel`, `topAttributeCount`, `topAttributeFloor`, `movementStandards` (legacy AP floors), `skillStandards` (hard-AND skill gates), `skillPathGroups` ("any N of"), `performanceStandards`, `loadoutVariants`.
- **8 ceremonies**, one per crossing (`OverallRankTrialDefinitions.all`):

  | id (target) | format | est min | minOverallLevel | topAttr |
  |---|---|---|---|---|
  | foundationProof → novice | daily100 | 14 | 1 | 2@20 |
  | calibration → apprentice | operatorScreen | 20 | 8 | 0 |
  | forge → forged | finisher | 30 | 15 | 1@58 |
  | reckoning → veteran | fixedDeck | 42 | 22 | 2@68 |
  | gauntlet → master | tower | 50 | 40 | 3@78 |
  | crucible → vessel | bossRush | 58 | 55 | 4@84 |
  | threshold → unbound (displays "Ascendant") | raid | 65 | 72 | 5@90 |
  | ascension → ascendant (displays "Unbound") | finalExam | 75 | 90 | 6@95 |

- **Station/loadout system** (KEEP): `TrialStation` × `TrialLoadoutVariant` (`noGymField`/`homeKit`/`gymHybrid`), `loadPercentOfBodyweight`, `capSeconds`, per-station `movementOptions` with equipment fallback. `RankTrialLoadoutResolver` picks the variant from owned equipment. `OverallRankTrialRunner` drafts → completes → `evaluateDetailed` (clean-rep / form-break / time-cap checks) → records attempt → posts `.overallRankTrialCompleted`.
- **Conditioning gauntlets, not PR tests** — completion under fatigue, infinitely retryable, scaled by loadout. This spirit stays.

### `TrialReadinessService` (`:1760`) — eligibility
`requirementLines` builds: **overall-level** (KEEP), **top-attributes** (DELETE — omni-max floor), **movementStandards AP floors** (DELETE — AP is gone post-Phase-6, these are dead minimumAP numbers), **skillStandards** hard-AND (DELETE), **skillPathGroups** any-N (DELETE for eligibility — fairness now lives in build-weighting), **equipment** (KEEP — loadout resolution). Status = `.locked` until `allMet`, then `.ready`, then `.attempted`/`.failed`/`.passed`.

### `highestPassedRank` (`OverallRankTrialProgress:1567`)
Parallel scalar persisted in UserDefaults. `record()` bumps it when a passing attempt's `targetRank` exceeds it. `currentRank` reads it. **This IS the confirmed overall rank** — it must reconcile with `aggregateRank` (see §5).

### `RankCosmetics` (`RankCosmetics.swift`)
Static lookup `RankTier → avatar_frame_<token>` / `profile_bg_<token>`. `equipped(highestRank:)` returns the tier. Per-user "highest reached" persisted in UserDefaults. No prestige system — already exactly what Phase 7 wants. Just needs to be fed the **confirmed** overall rank.

---

## 2. Proposed `aggregateRank` model

**Overall rank = build-weighted, difficulty-weighted mean of per-movement `RankTier`s, with honest decay, mapped to one `RankTier`.**

### Formula
For each ranked movement `m` the user has trained:
```
score(m)   = ranktier(m).rawValue            // 0…8, from computeLiftRank / computeTier
weight(m)  = difficultyWeight(m) × buildWeight(m) × freshness(m)

overallRaw = Σ [ score(m) × weight(m) ] / Σ weight(m)      // weighted mean, 0…8
aggregateRank = RankTier.nearest(for: overallRaw)
```

| Factor | Definition | Rationale |
|---|---|---|
| `difficultyWeight(m)` | `1 + (difficulty/8)` → range **1.0–2.0**, where difficulty = `SkillNode.tier` (skills) or the move's ratio-band ordinal (lifts). | A hard move counts up to 2×; an easy move ~1×. This is the cross-movement fairness — 100 pushups ≠ a novice planche. |
| `buildWeight(m)` | `1.0` baseline; `+0.5` if the move's top `attributeWeights` axis == `buildIdentity.primary`; `+0.25` if == `.secondary`. Cap **1.75**. `balancedAthlete`/`hybridAthlete` → flat `1.0` everywhere (no axis to favor). | A powerlifter's lifts count more *for them*; a calisthenics athlete's skills count more *for them*. Same rank reachable by different paths. |
| `freshness(m)` | `1.0` if trained within grace window; decays toward a **floor of 0.5** as the move goes stale (reuse `isStale` / `AttributeDrift.graceDays`). Never zero — rank is dampened, never erased. | Honest decay without punishing a layoff into oblivion. Matches the attribute `isStale` philosophy (flag, don't delete). |

### Aggregation choice: weighted **mean**, not max
- Today's aggregate is an unweighted mean of family tiers. Keep **mean** (so one maxed lift can't carry you), but weight it. A specialist's few heavy/on-build moves pull the mean up via their high weight; junk-volume easy moves can't.
- **Coverage guard:** require a minimum number of weighted movements (e.g. ≥ 4 ranked moves) before the mean counts above Forged, so day-1 single-lift spikes don't inflate overall rank. Below that, cap the contribution. (Open question — see §6.)

### What is NOT in overall rank
- The **single hardest feats** (one-arm pull-up, full planche, 60s L-sit = Ascendant on that move) are **aspirational individual badges** — they show as a maxed per-movement `RankTier` and earn cosmetics/flex, but are **never** an overall-rank *requirement*. A powerlifter reaches the top via bodyweight-relative lifts; a calisthenics athlete via skills. The build-weighting is what makes both routes legitimate.

### Implementation note
`aggregateRank(userId:)` stops reading `familyTierRawValueMean` and instead pulls per-movement ranks (the values `computeLiftRank`/`computeTier` already produce) + their difficulty + the profile's `buildIdentity` + per-move freshness. Same signature, same `RankTier` return — all consumers (`SkillTreeViewModel`, `UnboundHomeView`) are untouched.

---

## 3. Eligibility = TWO fair gates, then the ceremony

```
eligible(forNextRank) =
    aggregateRank ≥ nextRank          // (a) build-weighted accumulation crosses the tier
 && overallLevel  ≥ nextRank.minOverallLevel   // (b) tenure floor (KEEP)
```
- **(a)** is *elite in your build*, not the hardest individual skills.
- **(b)** `minOverallLevel` is the XP-derived tenure floor — prevents a strong newcomer from hitting a top rank day-1 (they may have the ability instantly, not the tenure).
- When both true → readiness `.ready` → the Ascension ceremony unlocks. Rank stays **provisional** (`aggregateRank` shows it as "pending"/eligible) until the ceremony is cleared, which **confirms** it (writes `highestPassedRank`).

This is a **two-line** `TrialReadinessService` after deletion: overall-level gate + the eligibility-from-aggregate check + equipment resolution. Everything else in `requirementLines` is deleted.

---

## 4. The SIMPLE Ascension ceremony (B5 — key deliverable)

**Principle:** the ceremony is the *act of claiming* a rank you've already earned by accumulation. It should feel ceremonial, not be a second grind. So: **tiered ceremonies** — light/near-auto at low ranks, epic gauntlets reserved for the crown tiers.

### Three ceremony tiers

| Ceremony tier | What it is | Provisional → Confirmed |
|---|---|---|
| **Auto-confirm** | No workout. The moment eligibility (a)+(b) is met, the rank **auto-confirms** with a short cinematic/toast. Early progression is never blocked by a heavy session. | Instant on eligibility. |
| **Benchmark** | One short qualifying session — a single ~10–15 min benchmark (the existing `daily100`/`operatorScreen` style, scaled by loadout). Complete it (clean reps, under time cap) → confirmed. Infinitely retryable. | On first clean completion. |
| **Gauntlet** | The epic themed conditioning gauntlet (Tower / Boss Rush / Raid / Final Exam). The signature moment — "I cleared The Tower → Master." Scaled gym/home/no-gym, infinitely retryable. | On first pass. |

### Rank-by-rank ceremony table (proposed)

| Crossing | Display name | Ceremony tier | Existing definition reused | Why |
|---|---|---|---|---|
| Initiate → Novice | — | **Auto-confirm** | (retire `foundationProof` as a gate; keep its session as optional content) | Week-one. Never gate first progress on a workout. |
| Novice → Apprentice | — | **Auto-confirm** | (retire `calibration` gate) | Still early; accumulation alone is honest here. |
| Apprentice → Forged | The Finisher | **Benchmark** | `forge` (finisher), trimmed to one short round | First "prove it" moment, but light. |
| Forged → Veteran | Deck of Proof | **Benchmark** | `reckoning` (fixedDeck), scaled down | First *named* tier — a real but short benchmark. |
| Veteran → Master | **The Tower** | **Gauntlet** | `gauntlet` (tower) | Milestone. The epic gauntlet earns its place. |
| Master → Vessel | **Boss Rush** | **Gauntlet** | `crucible` (bossRush) | Crown tier (`deservesCinematic`). |
| Vessel → "Ascendant" (ordinal 7) | **Threshold Raid** | **Gauntlet** | `threshold` (raid) | Crown tier. |
| "Ascendant" → "Unbound" (ordinal 8, peak) | **Final Exam** | **Gauntlet** | `ascension` (finalExam) | The peak. The hardest ceremony in the app. |

> Crown tiers = `RankTier.deservesCinematic` (Vessel/ordinal-6 and up) → gauntlet. Forged/Veteran → benchmark. Novice/Apprentice → auto-confirm. This mapping is a **derived property of the target rank**, not new config — `ceremonyTier(for: targetRank)` is a small switch.

### Provisional → Confirmed mechanics
1. Accumulation + LVL cross → `aggregateRank` reports the next tier as **provisional** (eligible, pending ceremony). UI shows "Eligible — claim your rank."
2. Auto-confirm tiers: confirm immediately, fire the rank-up cinematic, write `highestPassedRank`.
3. Benchmark/Gauntlet tiers: the existing `OverallRankTrialRunner` drafts the (loadout-resolved) session; on a clean pass `record()` writes `highestPassedRank` and posts `.overallRankTrialCompleted`. Same flow as today, just fewer ceremony tiers do real workouts.
4. If the user later decays below the tier, the **confirmed** `highestPassedRank` is retained (you don't lose a claimed rank), but `aggregateRank` display can show the honest current accumulation — see §5 reconciliation.

This is shippable: it **reuses the entire station/loadout/runner stack** and only changes (a) which crossings require a session and (b) the eligibility check that gates them.

---

## 5. Top rank → cosmetics; `highestPassedRank` reconciliation

- **Cosmetics:** wire `RankCosmetics.equipped(highestRank:)` to the **confirmed** overall rank (`highestPassedRank`). Top tier ("Unbound") unlocks the existing crown frames/backgrounds. No new prestige system.
- **Reconciliation — one rank, two fields collapse:**
  - `aggregateRank` = your **live, honest** build-weighted accumulation (can move up *and* down with decay). This is what gates eligibility and what Home shows as your current standing.
  - `highestPassedRank` = the **confirmed/claimed** rank (monotonic — a ceremony you cleared is yours). Drives cosmetics + the badge you "own."
  - Rule: **confirmed rank = min(highestPassedRank, …)?** No — keep it simple: **confirmed rank = `highestPassedRank`** (claimed is permanent); **eligibility for the *next* rank = `aggregateRank` ≥ next**. So the single displayed rank = `highestPassedRank`; the "progress toward next" bar = `aggregateRank` vs next threshold. The two stop being parallel competing scalars: one is "claimed," one is "current ability."
  - (Open question §6: do we ever *display* a decay below claimed rank, or only dampen the next-rank progress? Recommend the latter — never visibly demote a claimed rank.)

---

## 6. DELETE plan (omni-max only)

### Symbols to delete
| Symbol | File | Note |
|---|---|---|
| `topAttributeCount` | `OverallRankTrialService.swift` (struct field, init, CodingKeys, decode, every definition arg) | omni-max attribute floor |
| `topAttributeFloor` | same | omni-max attribute floor |
| `skillStandards` | `OverallRankTrialDefinition` (field + `OverallRankTrialSkillStandard` struct + `skillStandard()` helper) | hard-AND skill conformity |
| `skillPathGroups` | `OverallRankTrialDefinition` (+ `OverallRankTrialSkillGroup` struct) | any-N skill gate — fairness now lives in build-weighting |
| `movementStandards` + `OverallRankTrialMovementStandard` + `minimumAP` | `OverallRankTrialService.swift` | dead AP floors (AP killed in Phase 6); not a gate anymore |
| `.attributes` / `.skill` / `.movement` cases of `OverallRankTrialRequirementKind` | same | only `.overallLevel` + `.equipment` survive |
| top-attributes + movement + skill + skillGroup blocks in `requirementLines` | `TrialReadinessService` | the attribute/skill eligibility apparatus |
| attribute/skill plumbing in `OverallRankTrialReadinessInput` (`movementProgress`, `skillTiers`, `attributeProfile`) | `OverallRankTrialService.swift` + `readiness()` loader + `OverallRankTrialReadinessCard.swift` | only `overallLevel` + `equipment` are read post-delete |
| `OverallRankTrialSkillGateTests` / `OverallRankTrialPeakGateTests` | `UNBOUNDTests/Services/` | test the deleted gates |

### KEEP
- `minOverallLevel` (the tenure gate).
- Entire station/loadout system: `TrialStation`, `TrialLoadoutVariant`, `TrialMovementOption`, `RankTrialLoadoutResolver`, all `*Stations(loadout:)` builders, `loadPercentOfBodyweight`, `capSeconds`.
- `OverallRankTrialRunner` (draft / complete / `evaluateDetailed` / record).
- `performanceStandards` (the actual in-session targets the gauntlet checks).
- `RankCosmetics` (rewire input only).

### Reconcile
- `highestPassedRank` → the one confirmed rank (§5). `OverallRankTrialProgress.currentRank` stays as its reader.

### Grep that proves it's gone
```bash
grep -rn "topAttributeFloor\|topAttributeCount\|skillStandards\|skillPathGroups\|minimumAP\|OverallRankTrialSkillStandard\|OverallRankTrialSkillGroup\|OverallRankTrialMovementStandard" --include="*.swift" UNBOUND/ UNBOUNDTests/
# → expected: zero matches
grep -rn "minOverallLevel" --include="*.swift" UNBOUND/   # → still present (kept)
```

---

## 7. Open questions for the owner

1. **`minOverallLevel` per tier** — keep the current ladder (1/8/15/22/40/55/72/90) or recalibrate now that two early crossings become auto-confirm? (Auto-confirm tiers still respect the LVL floor — that's what keeps day-1 rushers out.)
2. **Ceremony tier split** — confirm the proposed cut: Novice/Apprentice = auto-confirm, Forged/Veteran = benchmark, Vessel+ (`deservesCinematic`) = gauntlet. Or push the gauntlet line up/down a tier?
3. **Decay aggressiveness** — `freshness` floor of 0.5 and reuse of `AttributeDrift.graceDays`? Or a gentler/steeper curve? And: never visibly demote a *claimed* rank (recommended), only dampen next-rank progress — confirm.
4. **Coverage guard** — minimum ranked-movement count (proposed ≥ 4) before the weighted mean can exceed Forged, to stop single-lift day-1 spikes. Right threshold?
5. **buildWeight magnitude** — primary +0.5 / secondary +0.25 (cap 1.75). Strong enough to make paths feel distinct, not so strong it lets a one-axis specialist coast?
6. **Benchmark ceremony content** — reuse `forge`/`reckoning` definitions trimmed, or author two short purpose-built benchmarks? (Reuse is less work and already loadout-scaled.)
