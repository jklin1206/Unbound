# ONE METRIC — Progression Cleanup Plan

**Date:** 2026-05-29 · **Supersedes:** `RANK-VOCABULARY-CONSOLIDATION.md`
**Mandate (from jlin):** the app measures "how good are you at a movement/skill" ~16 different ways. Collapse to **ONE rank metric.** Every phase **deletes the old code and its wiring in the same change** — no parked "safety nets" (git is the safety net). Each phase ends with an extensive test pass, a stated completion metric, and a **push to prod**.

## The only metrics allowed to exist
| Axis | What it answers | Owner | Everything else = DELETE |
|---|---|---|---|
| **Rank** | how good am I at this movement/skill | **`RankTier`** (Initiate→Ascendant, 9; tier 0 = Initiate) | SubRank, SkillRank, MuscleGroupTier-rank, LiftTierCriteria, MovementTierStandard, per-skill 9-tier ladders, `node.levels` |
| **LVL** | how much have I played (time/effort) | **one AP-derived `OverallLevel`**, labeled **"LVL"** everywhere | `unbound.gains` counter |
| **Streak** | consistency | `SessionXPService` streak | (keep — genuinely separate) |
| **Attributes (hex)** | balance across 6 axes | one number per axis (xp→level), **scales from tiny→full over time** | the 0–100 score, peak-subrank, the duplicate titles |
| **Recovery / muscle status** | how trained/recovered a muscle is (NOT a rank) | `MuscleHeatGroup` (recovery/status) | `MuscleGroupTier` (the E–S muscle *rank*) |

Anything not in this table that scores a movement/skill is deleted.

---

## How a movement/skill is ranked (the one model)
**Per-movement rank** = your achievement on that move, via its natural metric → one `RankTier`. The metric depends on the movement template:
- **Loaded** (bench, squat, lateral raise, every weighted move) → **load ÷ bodyweight** ratio. Every weighted movement gets a standard, not just the 5 barbell lifts.
- **Bodyweight-rep** (pushup, pull-up, dip, bodyweight squat) → **reps** ladder (e.g. pushup 5/8/15/25/40/60/80/100 → Novice…Ascendant). *This is the "rank within the bodyweight" — keep it.*
- **Hold** (plank, L-sit, dead hang, planche progressions) → **seconds** ladder (e.g. 60s L-sit = Ascendant).
- **Cardio + carries → UNRANKED for now** (cardio is just cardio; carries are awkward to rank). They still earn XP, just no rank badge.
- **Stretches / pure mobility → unranked.**

The reps/seconds ladders are the existing per-movement `tierCriteria` tables — they are **the rank standard for bodyweight movements** (the analog of load÷bw for weighted ones). We keep them.

**Cross-movement fairness** (100 pushups ≠ a novice planche): solved by the **overall accumulation weighting each movement's rank by the movement's difficulty** (Phase 7), NOT by flattening the per-move ladders. A maxed pushup is a real "Ascendant pushup" badge; an easy move just contributes less to your *overall* rank than a hard one.

**Tree placement** (`tier 0–8`) is used for **unlock ordering** + as the **difficulty weight** in the overall accumulation — not as a third competing rank field.

**One rank field per movement.** The redundant *separate* scales (`SkillLevel` Lv1–5, `MovementDifficulty` as its own axis, `SkillRank`, `NodeState`-as-a-ladder) die; the metric ladder is the rank.

---

## Design decisions — RESOLVED
1. **AP → "% to next rank" (Phase 6).** Kill the AP *currency*. A movement's within-rank progress is a **derived % fill between your current rank and the next bodyweight threshold** — no stored points, no name collision with attributes. Plateau = the bar sits (honest); LVL + attributes + other movements still move. LVL is re-sourced from total work/sessions; attributes from what you train.
2. **Standards = public dataset (Phase 3).** Curate bodyweight-relative ratio standards for all weighted movements from a **public strength-standards dataset** (StrengthLevel-style), normalized to `RankTier`.
3. **Hex = auto-rescale + maxable (Phase 5).** The hex **auto-rescales as you level** so there's always visible room to grow (starts as tiny slivers), **but has a real ceiling you can eventually max** — growth *and* a satisfying "maxed it" payoff.

---

## Phases (each: Goal · Build · DELETE · Done-when · Push)

### Phase 0 — 🔥 FIRE 1: logging actually records
**Goal:** a logged workout persists skill tiers, ranks, and progression — today the canonical `complete()` path drops all of it and the cascade that does it (`saveLog`) is never called.
**Build:** re-home the orphaned services into `TrainingCompletionService.complete()`: ProgressionEngine ingest (→ revives AutoDeloadService), skill recompute, rank evaluation, skill-tier persistence, trials capstone, session/streak, skins, sessionLogged badges. Persist the `ProofEngine` result (against the real prior state + real bodyweight, not `.empty`/70kg). **Integrity:** harden movement resolution and **surface an "unmatched — won't count" state** so a free-text/unrecognized logged exercise can't silently fail to count toward rank/skill/XP.
**DELETE:** the dead `WorkoutLogServiceProtocol.saveLog` cascade and `recordProgressionForLegacyWorkout` once their logic is re-homed; the `WorkoutLoggingViewModel` preview-only detour. No parallel path survives.
**Done-when:** a live logged workout → skill node flips to proven + tier persists + rank fires (verified by re-reading the tree, not the reward screen); an unrecognized exercise shows the unmatched state instead of silently vanishing. Full suite green + council + live rollback test (data-layer).
**Push.**

### Phase 1 — 🔥 FIRE 2: one LVL
**Goal:** the level the user sees == the AP-derived `OverallLevel`.
**Build:** surface `OverallLevelProgress.level` on Home + Profile. Standardize the label to **"LVL"** everywhere.
**DELETE:** `unbound.gains` UserDefaults counter + every read/write + the `+30/session` increment.
**Done-when:** Home/Profile level == LV from the engine; grep finds zero `unbound.gains`. Suite green.
**Push.**

### Phase 2 — one rank ladder (kill the letter scales)
**Goal:** `RankTier` is the only "how good" scale; no E–S anywhere.
**Build:** make `StrengthStandards` output `RankTier` directly (bodyweight-relative). Convert the realization/peaking/badge/rank-up gates from `SubRank.ordinal` to `RankTier`. Reframe the muscle heatmap as **recovery/status** only (keep `MuscleHeatGroup`).
**DELETE:** `SubRank.swift` (whole 18-step scale + `RankAdvance` letter usage), `SkillRank.swift` + `SkillNode.rank`, `MuscleGroupTier`/`MuscleGroupTierState`/`MuscleGroupTierCalculator` (the muscle *rank*), and all their wiring/UI.
**Done-when:** grep finds zero `SubRank`/`SkillRank`/`MuscleGroupTier`; ranks still compute on `RankTier`; rank-up cadence now 9-step (accepted). Suite green.
**Push.**

### Phase 3 — rank every movement by its template metric
**Goal:** every rankable movement returns one `RankTier`, by the right metric for its template.
**Build:** a ranking method per template, all normalized to `RankTier`:
- **Loaded** → bodyweight-relative ratio standards for all weighted movements (curated from a public strength-standards dataset). One `RankTier`, identical in library and engine.
- **Bodyweight-rep** → reps ladder (the kept `tierCriteria`).
- **Hold** → seconds ladder (the kept `tierCriteria`; calibrate so elite feats like 60s L-sit = Ascendant).
- **Cardio + carries** → explicitly **unranked** (earn XP only).
**DELETE:** `LiftTierCriteria` (absolute kg — replaced by ratio) and the dead `MovementTierStandard`/`MovementStandardLadder`/`tierStandards(for:)`; repoint the library + profile + settings readers onto the one path.
**Done-when:** library rank == engine rank for a sampled set across templates; a lateral raise (loaded), a pushup (reps), and an L-sit (seconds) all return a rank; cardio/carry return unranked; grep finds zero `LiftTierCriteria`/`MovementTierStandard`. Suite green.
**Push.**

### Phase 4 — skill tree: placement = difficulty weight + unlock order
**Goal:** the tree carries one difficulty number per node (for unlock order + accumulation weighting) — without re-introducing a competing rank scale. **The reps/seconds `tierCriteria` ladders STAY** (Phase 3 keeps them as the per-movement rank standard); this phase is about the *tree structure*, not deleting the ladders.
**Build:** `SkillNode.placementRank` from `tier` (`tier 0–8 = Initiate→Ascendant`); reconcile the ~10–25 nodes where `tier` disagrees with prereq depth so difficulty is monotonic down each chain; `NodeState` → locked/proven only (not a parallel ladder).
**DELETE:** `SkillLevel`/`node.levels` (the dead Lv1–5 XP ladder, grants no XP), `MovementDifficulty` as a *separate* difficulty axis (folded into `placementRank`), and `SkillTreeContent.swift.new` (stale 336 KB dupe). **Do NOT delete the reps/seconds `tierCriteria`** — they're the bodyweight rank.
**Done-when:** each node has one difficulty (`placementRank`) + its metric ladder (the rank); no `SkillLevel`/`MovementDifficulty`-as-axis; the `.new` dupe is gone. Suite green.
**Push.**

### Phase 5 — attributes: one number + slow, hard-to-max hex
**Goal:** the hex is one number per axis, starts as tiny slivers, and is **genuinely hard to max** — the main worry today is it fills up fast because there's no real limit. It must grow slowly so a full hex is a real long-term achievement, not a week-one occurrence.
**Build:** collapse `AttributeValue` to a single source (XP→level→`RankTier` title); calibrate the XP→attribute-level **curve so it's steep/slow at the top** (each higher level costs much more XP), starting tiny and rescaling so there's always visible room, with a real ceiling that takes serious sustained training to reach.
**DELETE:** the 0–100 `current`/`peak` score scale, `subRank`/`peakSubRank` on attributes, and the duplicate `rankTitle` vs `levelRankTitle` (keep one).
**Done-when:** new-user hex = small slivers; a simulated heavy-training cohort takes a long, believable time to approach max (no fast-fill); one number behind each axis. Suite green.
**Push.**

### Phase 6 — rename AP → XP; split its jobs cleanly
**Goal:** kill the confusing "AP" name; one clearly-named **XP** currency (effort) + a derived **"% to next rank"** bar (ability). They never collide.
**Build:**
- **XP** = the existing reps×weight work math (keep it — volume × intensity × difficulty, velocity-weighted) **+ the under-trained multipliers** (e.g. neglected regions earn more, the existing novelty multiplier). XP does two things with the same points: **LVL** = total XP; **hex** = the same XP split across the trained axes via each movement's `attributeWeights` (multi-factor — explosiveness fed by many movements). Surface "+X XP" in the reward flow / the right log area.
- **"% to next rank"** = **derived** (current best vs the next threshold on the movement's metric ladder) — computed, not stored, no currency.
**DELETE:** the name/label **"AP"** and "Ascension Points" everywhere; the per-movement AP *ledger* as a rank input (rank comes from the metric ladders now). The work-math survives **as XP** (renamed), never as "attribute points."
**Done-when:** grep finds zero user-facing "AP"/"Ascension Points"; "+X XP" shows on logging; movement detail reads "X% to next rank"; LVL + hex both fed by XP. Suite green.
**Push.**

### Phase 7 — overall rank = accumulation + Ascension ceremony
**Decision (council, 2 rounds):** overall rank is **accumulation** of your per-movement ranks, **weighted by each movement's difficulty** (a hard move counts more than an easy one — this is the cross-movement fairness) and by your build (`buildIdentity`), friends-flex only. **No prestige score — top rank is Ascendant, full stop.** Accumulation makes you **eligible** for the next rank; **clearing that rank's named Ascension boss-workout is the ceremony that claims it** (provisional/"pending" rank until cleared, infinitely retryable, scaled gym/home/no-gym loadouts are all legit clears). The Ascension events are themed **conditioning gauntlets** (completion under fatigue), NOT PR/standard tests — they stay; they're the signature ("I cleared The Tower → Master"). Ceremonies are **tiered**: light/near-auto at low ranks, the epic gauntlets reserved for milestone ranks. Top rank → the existing **cosmetics** (frames/backgrounds), not a new prestige system.
**Eligibility for the next overall rank = TWO fair gates, then the ceremony:**
1. **Build-weighted accumulation** (`aggregateRank`, weighted via `buildIdentity`) crosses the tier — *elite in your build*, NOT the hardest individual skills. The single hardest feats (one-arm pull-up, full planche) are aspirational *individual* badges, never overall-rank requirements; a powerlifter reaches Ascendant via bodyweight-relative lifts, a calisthenics athlete via skills.
2. **`minOverallLevel`** — a fair effort/time floor (XP can't be rushed). This is what prevents a strong newcomer from hitting a top rank day-1: they may have the *ability* instantly, but not the *tenure*.

Then the **Ascension ceremony** claims it. Top rank (Ascendant) → the existing cosmetics.
**Build:** `aggregateRank` (already the displayed rank) becomes the source of truth, **difficulty-weighted** (per-move difficulty) + build-weighted, on `RankTier`, with honest decay (reuse `isStale`). Wire eligibility (accumulation + LVL) → Ascension event → provisional→confirmed rank. Wire `RankCosmetics` to the new rank.
**DELETE:** the **omni-max requirements** only — `topAttributeFloor`/`topAttributeCount`/`skillStandards`/`skillPathGroups` + the attribute/skill parts of `TrialReadinessService` (forced all-around conformity, no real consumers). **KEEP** `minOverallLevel` as the effort gate. Keep the event station/loadout definitions + runner. The parallel `highestPassedRank` scalar reconciles into the one rank.
**Done-when:** a single grep proves only `RankTier` ranks movements/skills; eligibility+ceremony flow works; the attribute-floor/skill-gate apparatus is gone. Suite green.
**Push.**

### Phase 8 — documentation + file-structure architecture
**Goal:** after the metric is unified, the docs and file layout are clean enough that a future traversal references **one map** and can never re-discover the maze. One subsystem → one current doc.
**Build:** the target docs tree below (a single map + one source-of-truth doc per subsystem + short decision records). Group the scattered model files into subsystem folders so related types sit together (e.g. `Models/Ranking/`, `Models/Skills/`, `Models/Attributes/`).
**DELETE:** every superseded design doc that still describes the old multi-ladder / AP / E–S world — so it can't mislead future me: `RANK-VOCABULARY-CONSOLIDATION.md`, the rank/AP sections of `PROGRESSION.md` + `PROGRESSION-AGENT.md`, and the stale `superpowers/specs`+`plans` that spec replaced systems. (git history is the archive — we delete, not stash.)
**Done-when:** `docs/ARCHITECTURE.md` maps every subsystem to exactly one current doc; grep for dead scale names (`SubRank`, `SkillRank`, `MuscleGroupTier`, `LiftTierCriteria`, "AP") finds nothing in code *or* docs; a newcomer can answer "how does ranking work" from one file. Suite green.
**Push.**

---

## Target documentation architecture
The single entry point is `docs/ARCHITECTURE.md` — a one-screen map ("to understand X → read `architecture/X.md`", plus where each key type lives in code). Then one source-of-truth doc per subsystem:

```
docs/
  ARCHITECTURE.md         ← THE MAP / index. Start here. Subsystem → doc → code location.
  architecture/
    ranking.md            ← RankTier = the one ladder; weighted moves (bw-relative) +
                            skills (tree placement) earn rank; the "% to next rank" bar.
    skills.md             ← skill tree: placement = rank, one unlock gate per node.
    movements.md          ← exercise catalog + bodyweight-relative standards (public dataset).
    progression.md        ← program / arc / checkpoint / auto-deload engine.
    logging.md            ← the ONE ingest path (complete()) and what a logged set updates.
    levels.md             ← LVL (overall level) + streak.
    attributes.md         ← the hex: one number/axis, grow-from-tiny, maxable.
    recovery.md           ← MuscleHeatGroup recovery/status (explicitly NOT a rank).
  decisions/              ← one short ADR per locked call (bw-relative · delete-SubRank ·
                            AP→%-to-next-rank · tier0=Initiate · one-LVL · hex-rescale).
```
Kept as the "why" record (not architecture): the teardown deck (`unbound-rank-ladders-teardown.html`) and this plan. Everything else describing the old model is deleted.

## Cross-cutting facts
- **Onboarding:** everyone starts at **Initiate, LVL 0.** No calibration-placement — a strong newcomer climbs *fast* (their first heavy logged sets rank those movements high) but still starts at zero, and overall rank is gated by the LVL/time floor so nobody rushes to the top day-1.
- **No data migration:** there are no users yet. When we delete a scale, no migration/backfill is needed — clean slate.
- **Council + live rollback test** (per `data-layer-needs-council-and-live-test`) is required on the **persistence-touching phases — 0, 2, 7** — not just unit tests.

## Standing rule (all phases)
When we change how something works, the **previous implementation and its wiring are deleted in the same commit** — and the phase **updates its `architecture/*.md` and deletes any doc it supersedes** in that same change. No "leave it for safety." If we regret it, we `git revert`. Every phase: extensive tests, a stated completion metric, push to prod.
