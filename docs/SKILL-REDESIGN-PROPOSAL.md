# Skill-Tree Redesign Proposal — Two Honest Signals Per Skill

**Status:** checkpoint / design proposal. **No Swift edited.** Owner approval gate before any code.
**Date:** 2026-05-29 · **Branch:** `main` (rank refactor Phases 0–8 already shipped)

## TL;DR

The per-skill UI currently shows **four** overlapping progression scales. The most prominent one
(`LVL 1–5`) is **fake** — it advances on flat attendance XP (`+25/session`), not performance.
"Mastered" = ~24 sessions of showing up. The meaningful signal (reps/seconds → `RankTier` via
`tierCriteria`) is already computed and persisted in `UserSkillTierState.perSkill` but is buried.

**Collapse to two honest things per skill:**

| Signal | Source | Nature | Surface |
|---|---|---|---|
| **Difficulty** | `SkillNode.placementRank` (from `tier`) | intrinsic, fixed | simple star/dot rating |
| **Earned rank** | `RankTier` from `UserSkillTierState.perSkill` (via `tierCriteria`) | performance, earned | the existing `TierBadge` |

**Node lifecycle:** collapse `locked / attempting / achieved / mastered` → **`locked / proven`**.
"Proven" = unlocked / can-do; the earned `RankTier` then says *how good*.

---

## 0. The four scales today (why this is confusing)

For one node, the user can see all of these at once:

| # | Scale | Range | Driven by | Honest? |
|---|---|---|---|---|
| 1 | `SkillProgress.currentLevel` "LVL N" | 1–5 | flat `+25 XP/session` attendance | **NO — fake** |
| 2 | `NodeState` | locked/attempting/achieved/mastered | logs OR XP-leveling | partial |
| 3 | `SkillNode.rank` (`SkillRank` E–S) | E,D,C,B,A,S | content-authored difficulty | yes (but redundant w/ #5) |
| 4 | `RankTitle.derived(...)` | Initiate–Ascendant | **blend of #1 + #2 + #3** | **NO — inherits fake #1** |
| 5 | `UserSkillTierState.perSkill` `RankTier` | Initiate–Ascendant | **real reps/seconds vs `tierCriteria`** | **YES — the keeper** |

The fix keeps **#5** (real earned rank) + **`placementRank`** (intrinsic difficulty), and kills
**#1, #2 (4-state → 2-state), #3 (E–S band/copy), #4 (derived)**.

---

## 1. Audit: `tierCriteria` granularity

Source tables: `UNBOUND/Models/SkillTreeContent/Tiers/{Cal,Cl,Co,Hs,Hspu,Ld,Oah,Pl,Pp}SkillTiers.swift`.
**~196 skills × 9 tiers ≈ 1,764 threshold cells** (so "135 hand-edits" is a large undercount — rule-based
re-spacing is the only sane path).

### Representative rep ladders (current)

| Skill | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascend | Verdict |
|---|--|--|--|--|--|--|--|--|--|---|
| `pp.muscle-up` | (gates) | (gates) | (gates) | 1 | **2** | 5 | 8 | 10 | 12 | **2→3 is +1-rep granular** ✗ |
| `pp.pullup` | 1 | 2 | 3 | 5 | 7 | 8 | 10 | 11 | 12 | 7/8 and 10/11/12 too tight ✗ |
| `pp.10-pullups` | 3 | 5 | 7 | 10 | 13 | 16 | 19 | 22 | 25 | even +3 steps — fine ✓ |
| `cal.pushup` | 3 | 5 | 8 | 15 | 25 | 40 | 60 | 80 | 100 | well-spaced ✓ |
| `cal.5-dips` | 2 | 3 | 4 | 5 | 10 | 15 | 20 | 25 | 30 | 2/3/4/5 too tight ✗ |
| `cal.one-arm-pushup` | 1 | 2 | 3 | 5 | 8 | 10 | 12 | 15 | 20 | early +1s ✗ |
| `pp.ring-muscle-up` | 1 | 2 | 3 | 4 | 5 | 6 | 8 | 10 | 12 | 1..6 are +1-rep ✗ |
| `pp.one-arm-pullup` | 1 | 1 | 2 | 3 | 4 | 5 | 6 | … | … | every +1 a tier ✗ |
| `ld.glute-bridge` | 5 | 8 | 10 | 15 | 20 | 30 | 40 | 55 | 75 | well-spaced ✓ |

**Quantified:** in low-rep hard-skill ladders (muscle-up, OAP, ring-MU, clapping, archer, dips
1–5), **roughly half the tier steps are +1 rep** — i.e. "2 vs 3 muscle-ups is a whole rank." The
high-volume moves (pushup, dips upper, rows, glute-bridge) are already felt jumps.

### Holds: `.seconds` is defined but **NEVER USED**

- `TierCriterion.seconds(Int)` exists and has handlers in evaluators/UI.
- **Zero tier tables emit `.seconds(...)`** — duration is not tracked per `SetLog`. Every hold
  (`plank`, `l-sit`, `ring-support`, `iron-cross`, `maltese`, `dead-hang`) uses `.variant("name")`
  for low tiers and `.compound([.variant, .reps(...)])` for upper tiers (e.g. plank Ascendant =
  `plank` logged + 80 pushups).
- **Implication:** the "seconds ladder for holds" the brief floats can't drive earned rank today —
  there is no seconds data. A holds ladder is a **future data-capture project**, not part of this
  re-spacing. Flag for owner (Q below). Keep `.seconds` case (Codable + handlers stay).

---

## 2. Proposed re-spacing scheme (rule-based, catalog-wide)

One **felt-jump ladder per metric type**, mapped onto the 9 `RankTier`s. The rule is a function of
the move's **anchor** (the rep count that should land at `Forged` — the "first real rep / standard"
tier already annotated in every table comment as `anchor: N = Forged`).

### A. Rep ladders — pick by anchor band

> **Headline numbers — this is what the owner approves.**

| Move class (Forged anchor) | Init | Nov | App | **Forged** | Vet | Master | Vessel | Unbound | Ascend |
|---|--|--|--|--|--|--|--|--|--|
| **Hard skill** (anchor 1) | 1 | 1 | 1 | **1** | 2 | 3 | 5 | 7 | 10 |
| **Skill** (anchor 3–5) | 1 | 2 | 3 | **5** | 8 | 12 | 16 | 20 | 25 |
| **Volume** (anchor 10) | 3 | 5 | 8 | **10** | 15 | 20 | 30 | 40 | 50 |
| **High-volume** (anchor 15–20) | 5 | 8 | 12 | **15** | 25 | 40 | 60 | 80 | 100 |

Properties: geometric-ish, every step a real jump, **2→3 reps never crosses a tier** in the
hard-skill band (a muscle-up goes 1·1·1·1·2·3·5·7·10 — so 2 and 3 sit one tier apart only at the
top, and 1 fills Init→Forged). Forged always = the move's standard "you can do it" anchor.

**Selection rule (deterministic, no per-cell editing):**
```
anchor = current Forged rep value for the move (already in every table)
band   = anchor <= 1  -> Hard skill
         anchor <= 6  -> Skill
         anchor <= 12 -> Volume
         else         -> High-volume
ladder = the band row above, scaled so Forged == anchor when anchor differs slightly
```
This re-derives all rep ladders from one 4-row table + each move's existing anchor. ~95% of moves
fit a band cleanly.

### B. Weighted ladders (bw-ratio) — already well-spaced, keep

`exerciseBodyweightRatio` moves (`weighted-pullup`, `weighted-chin-up`, `weighted-dip`) climb
0.10 → 1.25× — felt jumps already. **No change.**

### C. Holds — out of scope (no data). Keep `.variant`/`.compound` as-is.

### D. Bespoke moves (do NOT auto-apply the rule — ~6–10 nodes, owner reviews)

| Node | Why bespoke |
|---|---|
| `pp.muscle-up` Init/Nov/App | objective *readiness gates* (`compound`), not reps — keep |
| `cal.iron-cross-*`, `cal.maltese`, `cal.azarian` | mythic cascades through prereq variants — keep |
| `pp.one-arm-pullup` / `pp.one-arm-chin-up` / `pp.strict-muscle-up` | once-a-decade; Init=1 is fine, top compounds |
| `cal.ninety-degree-pushup`, `cal.*-handstand-pushup` | crossover gates (planche+HSPU) — keep |
| any `.compound([...])` upper tiers | intentional multi-signal — keep |

---

## 3. Kill-list + blast radius (per symbol)

### 3a. `SkillProgress.currentLevel` / `xpInLevel` / `xpToNextLevel` (the fake LVL ladder)

| Touchpoint | File:line | Change |
|---|---|---|
| Struct def | `Models/SkillProgress.swift` | **delete struct** (or keep empty stub for decode) |
| Field in store | `Models/UserSkillProgress.swift:24` `skillProgress` | **drop field** (Codable-safe, see §5) |
| Accrual + leveling | `Services/SkillProgress/SkillProgressService.swift:218–307` `awardSessionXP` | **delete** leveling/cap/state-promotion body |
| Curve | `SkillProgressService.swift:426–429` `xpForLevel` | **delete** |
| Accessor | `SkillProgressService.swift:203–205` `currentSkillProgress` | **delete** |
| `.starter` | `SkillProgress.swift:24` | delete w/ struct |
| **Reads (LVL chip):** | | |
| ClusterCardView | `Views/Home/ClusterCardView.swift:215,232` `nowChip` "LVL N" | replace w/ `TierBadge` of earned `perSkill` tier |
| SkillDetailView | `SkillDetailView.swift:294–295,327–330,1114,1116` | title subtitle drops `· Lv N`; progress strip → % to next `RankTier` (see §4) |
| SkillSessionView | `SkillSessionView.swift:674,680,728,737` | stop feeding `currentLevel` to reward summary |
| ProgramOverviewView | `ProgramOverviewView.swift:652,684,2892,4290,4320` | drop `Lv N` from node rows |
| SettingsView debug | `SettingsView.swift:1415,2362` | `SkillProgress(currentLevel:5…)` / `.starter` seeds → delete |

> **Note:** the many other "LVL"/"LVL XP" strings (`UnboundHomeView`, `RewardCelebrationView`,
> `WorkoutRewardSequenceView`, `ProfileBuildCard`, routines `spReward`, scan `+25 LVL XP`) refer to
> **OVERALL level / attribute level**, NOT per-skill `currentLevel`. **They stay.** Only the
> per-skill `SkillProgress.currentLevel` chip dies.

**How `awardSessionXP` changes:** it currently does three jobs — (1) accrue attendance XP, (2)
level 1–5 + cap to mastered, (3) promote `NodeState`. Jobs 1–2 die. Job 3 (NodeState promotion) is
**redundant** — `recompute(after:)` + `RankService.evaluateTierCrossings` already derive state and
earned tier from logs. Net: **delete `awardSessionXP` entirely**; the 24h `lastTrainedAt` cap it
enforced was only there to throttle the fake XP, so it goes too (unless retained for a streak — owner Q).

### 3b. `mastered` + `NodeState` 4-state → `locked / proven`

| Touchpoint | File:line | Change |
|---|---|---|
| Enum | `Models/SkillTree.swift:33–38` | `enum NodeState { case locked, proven }` |
| `prereqsSatisfied` | `SkillTree.swift:247–255` | `s == .proven` (was `.achieved || .mastered`) |
| `isClusterUnlocked` | `SkillTree.swift:292–300` | `state == .proven` |
| `recompute` transitions | `SkillProgressService.swift:131–158` | drop the `threshold: 2.0` mastered branch; `achieved`→`proven`; `attempting`→`proven` is the *unlock* (prereqs met). Keep `nodeProgress` fraction. |
| seed `.attempting` | `SkillProgressService.swift:461–491` | seed `proven` for entry nodes? **NO** — entry node still needs its `target` hit. Re-define (Q): seed nothing; `proven` only on target hit. |
| `manuallyMark` | `SkillProgressService.swift:177–192` | `state: .proven` only |
| `masteredAt` / `achievedAt` | `UserSkillProgress.swift:14–15` | collapse to one `provenAt` |
| 2× / cosmetic gate | `SkillProgressService` `threshold: 2.0`, RewardComputer mastered | mastered concept removed (perf-mastered = "earned top RankTier"; owner leaned no — Q) |
| `isMastered` UI | `SkillDetailView.swift:1116`, masteredBadge | remove; top `RankTier` (Ascendant) is the mastery signal |

**Define `proven`:** the node's `target: NodeRequirement` has been met at least once (1× threshold) —
i.e. today's `.achieved`. Earned `RankTier` (from `tierCriteria`) then expresses *how good*.
`attempting` (prereqs-met-but-not-done) folds into the **`locked` visual with a "ready" affordance**,
OR a third lightweight `unlocked` display state if owner wants the "you can start this now" cue
without it being `proven` (Q).

### 3c. `SkillRank` (E–S) — replace banding/sort with `placementRank`, drop bespoke copy

`SkillRank` has ~10 consumers. Replace with `RankTier` (via `node.placementRank`):

| Consumer | File:line | Change |
|---|---|---|
| `SkillNode.rank` field | `SkillTree.swift:131,186,236,350` | remove field; use `placementRank` (already maps `tier`→`RankTier`) |
| `displaysMythic` | `SkillTree.swift:236` | `placementRank >= .vessel || isMythic` (drop `rank == .s`) |
| Staircase bands | `ClusterStaircaseView.swift:619,621,766,782,785,793,838,854–863,914,933` | re-band over `placementRank` (9 tiers, but cluster only spans a few) instead of `SkillRank.allCases` (6). Band tint via `RankTier`. |
| Card rank pill | `ClusterCardView.swift:262,266–273` | pill uses `placementRank.assetName` (badge art already exists per `RankTier`) |
| Detail header | `SkillDetailView.swift:118,295,313–322` | `rankDescription(SkillRank)` → simple star/dot from `placementRank`; subtitle drops the E–S word |
| RewardComputer | `RewardComputer.swift:51,95` `skillRank:` param + `derived()` | **delete `RankTitle.derived` (#4)** + its two call sites (`:58,:115`); reward reads earned `perSkill` tier before/after directly |
| `bandTint(for:)` | `SkillTreeSkin.swift:266–268` | take `RankTier`; `isAscendedTier`→`>= .vessel` |
| SkinPicker preview | `SkinPickerView.swift:136–138` | iterate `RankTier.allCases` (or a representative subset) |
| DisplayTree sort | `SkillDisplayTree.swift:145–146`, `ProfileView.swift:536–537` | sort by `placementRank.rawValue` |
| MovementCatalog / UnlockStandards | `MovementCatalog.swift:1598`, `SkillUnlockStandards.swift:125` | `node.rank == .s` → `placementRank >= .unbound` (or keep `tier >= 7`) |

**Dropped copy (owner's call):** `unboundLabel` (Dormant/Awakened/Forged/Sharpened/Unbound/Ascended),
`tagline`, `accentColor`, `rankDescription` (Starter…Mythic). The `RankTier` displayName + token +
badge art replace all of it. **Delete `Models/SkillRank.swift` entirely** once consumers migrate.

### 3d. `RankTitle.derived` (#4 — the hidden second fake rank)

`RewardComputer.before/after` derives a rank from `currentLevel + nodeState + skillRank`. Since
`currentLevel` dies and the real earned tier lives in `perSkill`, **delete `derived` + both call
sites** and have RewardComputer snapshot `UserSkillTierStore.perSkill[skillId]` before/after instead.

---

## 4. The skill card / staircase after the redesign

**Per node, the user sees exactly two things:**

1. **Difficulty rating** — `placementRank` rendered as **dots/stars** (e.g. ●●●○○ or ★★★).
   Fixed; never changes. (Granularity Q: 3-step coarse vs 5-step — see Q below.)
2. **Earned rank** — one of:
   - `LOCKED` (prereqs unmet) — dossier viewable, dimmed.
   - `PROVEN` chip if unlocked + target hit but no tier earned yet (`perSkill` = `.initiate`).
   - the earned `TierBadge` (`perSkill[node.id]`, Initiate→Ascendant) once `tierCriteria` are met —
     this is the headline. Optional thin "X reps to next tier" progress hint (replaces the fake XP bar).

**Concretely — node card:**
```
┌────────────────────────────────────┐
│ MUSCLE-UP            ●●●●○  (diff)  │
│ Crossover · Pull                    │
│ [ VETERAN ]  ← earned TierBadge     │
│ 2 reps · next: Master at 3          │
└────────────────────────────────────┘
```
No "LVL 4", no "Forged" word soup, no attendance bar.

**Staircase re-bands** from 6 `SkillRank` (E–S) gutter rows to the **`placementRank` grouping** —
each cluster only spans a few of the 9 `RankTier`s, so the gutter shows just those (the existing
"absent ranks collapse" logic in `computeRankBandRegions` already handles sparse banding). Visually:
fewer, more meaningful bands, all in the one canonical `RankTier` vocabulary.

---

## 5. Persistence note (Codable safety)

`UserSkillProgress` is stored as local JSON (collection `"skillProgress"`) and synced to Supabase.
**There are no production users** (pre-launch), so **no data migration is required** — but decode
must not crash on:

- **Dropping `skillProgress` (currentLevel) field:** it's `var skillProgress: [String:SkillProgress] = [:]`
  with a default — removing it just means old blobs' key is ignored on decode. Safe. If `SkillProgress`
  struct is deleted, the key vanishes from the type → unknown-key is ignored by `JSONDecoder` (Swift
  ignores unknown keys by default). **Safe.**
- **`NodeState` 4→2 cases:** `NodeState: String, Codable`. Old blobs may hold `"attempting"`,
  `"achieved"`, `"mastered"`. A raw-value `String` enum **throws** on unknown raw values → would
  crash decode. **Action:** give `NodeState` a **tolerant decoder** mapping
  `achieved|mastered → .proven`, `attempting → .locked` (mirror the `RankTier.fromToken` pattern at
  `SkillTier.swift:110–127`). Then merge `achievedAt`+`masteredAt` → `provenAt` with a tolerant
  `init(from:)` that reads either legacy key.
- **`RankTier` decode** is already tolerant (Int + String + legacy letters) — confirmed at
  `SkillTier.swift:130–151`. `perSkill` tiers survive untouched.

**Confirmed:** with a tolerant `NodeState` decoder added, dropping the fake-XP fields is Codable-safe
and needs no migration.

---

## 6. Open questions for the owner

1. **Approve the rep ladders (§2A)?** The 4-row band table is the headline:
   - Hard skill: `1·1·1·1·2·3·5·7·10`
   - Skill: `1·2·3·5·8·12·16·20·25`
   - Volume: `3·5·8·10·15·20·30·40·50`
   - High-volume: `5·8·12·15·25·40·60·80·100`
   Adjust any number now — they propagate catalog-wide via the anchor rule.
2. **Performance-"mastered" flag?** Keep a boolean "this skill is maxed" = earned top `RankTier`
   (Ascendant) on the move? You leaned **no** — confirm we just let Ascendant *be* the mastery read.
3. **Difficulty granularity — 3 dots vs 5 stars?** `placementRank` spans 9 tiers; collapse to a
   3-step (easy/hard/elite) or 5-step rating, or render all? Recommend **5** (maps cleanly to
   tier bands, more informative than 3).
4. **What does `proven` require?** Proposed: the node's existing unlock `target` hit once (= today's
   `.achieved`). Confirm — and whether a distinct lightweight `unlocked` ("ready to start") display
   is wanted vs folding it into `locked`.
5. **Holds:** confirm seconds-based earned rank is **deferred** (no duration data today); holds keep
   `.variant`/`.compound`. OK to leave the `.seconds` enum case dormant?
6. **24h `lastTrainedAt` cap:** it only throttled fake XP. Drop it, or repurpose for a "trained today"
   streak signal?

---

## Biggest risk

**`NodeState` is compared with `==` across ~dozens of services/views.** Collapsing 4→2 cases is a
wide-but-mechanical sweep; the real hazard is the **tolerant Codable decoder** — get it wrong and
every existing local `skillProgress` blob crashes on launch (no users in prod, but it'll wreck dev
devices mid-migration). Land the decoder + a round-trip decode test for legacy 4-state blobs
*before* touching any call site. Second-order risk: `awardSessionXP`/`derived` deletion must not
silently drop `NodeState` *promotion* — verify `recompute` + `evaluateTierCrossings` fully cover
unlock detection so no node gets stranded `locked` after the fake-XP promoter is gone.
