# Ascension Tier — Additive Design (sub-project #4)

**Status:** Spec.
**Branch:** New `ascension-tier-v2` off current `program-redesign` HEAD (which has #1+#2 merged).
**Supersedes:** `2026-05-07-ascension-tier-design.md` and the `ascension-tier-impl` branch's spec (those assumed permission to demolish the rank hero card, which was incorrect).
**Reference implementation:** `/Users/jlin/Documents/toji/UNBOUND-ascension-tier/` — math, tier criteria, evaluators, tests are salvageable as-is. UI integration must follow this spec, not the reference branch.

---

## Goal

Replace the legacy SubRank E-S system with a 9-tier per-skill / per-lift / aggregate rank ladder (Initiate → Ascendant). Cinematic only fires for the top 3 tiers (Vessel / Unbound / Ascendant). Everything else is a quiet TierBloomToast.

The 9 tiers:
1. Initiate
2. Novice
3. Apprentice
4. Forged
5. Veteran
6. Honed
7. **Vessel** (mythic threshold — cinematic begins)
8. **Unbound** (the brand — cinematic)
9. **Ascendant** (final climb — cinematic)

## What ships

- `SkillTier` enum (9 cases) — already exists on trunk as `RankTitle` in `SubRank.swift` (introduced in sub-project #1). Reuse the existing enum; don't create a parallel one.
- Per-skill 9-tier ladder for every node in the skill tree
- Per-lift 9-tier ladder for the major lifts (bench / squat / dead / OHP)
- Aggregate rank derived from per-skill + per-lift (single number for the Home hero)
- `TierBadge` pill chip rendering for tier display
- `TierBloomToast` for tier-up notifications (Initiate → ... → Honed crossings)
- `RankUpCinematic` updated to fire on Vessel / Unbound / Ascendant crossings (already present from #1, just thread SkillTier through it)
- One-time migration: replays existing workout logs through `TierCriteriaEvaluator` to backfill per-skill + per-lift tier state

## Hard additive constraint

The session-flow Home is preserved. These elements MUST render unchanged after this PR:
- "Move, [Name]" greeting
- Foundation/Push subhead
- TODAY STATUS card — **but** the rank chip changes from `RANK B / LV 25` to the equivalent SkillTier ("FORGED / LV 25" or similar). The CARD stays, the chip's text-source swaps.
- BEGIN SESSION CTA
- SESSION PLAN list
- COACH CUE
- WEEK PATH

What changes visually:
- Aggregate rank display on Home — letter grade ("B") → tier name ("Forged")
- Skill tree nodes — each shows its own TierBadge instead of (or replacing) the existing rank chip
- Lift detail screens — each shows TierBadge
- Profile rank surfaces

## Out of scope

- Scan redesign (#3 — separate spec)
- Trials (#5)
- Squads (#6)

---

## Architecture

### Models (most already on trunk after #1+#2)

| File | Status |
|---|---|
| `Models/SubRank.swift` | Trunk already has `RankTitle` enum with 9 cases. Reuse. May rename to `SkillTier` later (out of scope) or keep `RankTitle`. |
| `Models/SkillTier.swift` | **OPTIONAL** — only create if we want a typealias `SkillTier = RankTitle` for naming clarity. Otherwise skip. |
| `Models/TierCriterion.swift` | NEW — describes "what triggers crossing into a given tier" (e.g. "5 verified sessions of skill X at form rating ≥4"). |
| `Models/UserSkillTierState.swift` | NEW — per-skill tier state per user (current tier + progress toward next + last-evaluated timestamp). |
| `Models/LiftTierState.swift` | NEW — same shape as UserSkillTierState but per-lift. |

### Services

| File | Purpose |
|---|---|
| `Services/Ranking/TierCriteriaEvaluator.swift` | NEW. Given a workout log + current state, returns any new tier crossings. |
| `Services/Ranking/UserSkillTierStore.swift` | NEW. UserDefaults persistence. |
| `Services/Ranking/LiftTierService.swift` | NEW. Per-lift tier evaluation + persistence. |
| `Services/Ranking/RankService.swift` | MODIFY. Existing `aggregateRank(userId:)` returns SubRank. Replace return type with `RankTitle` (the 9-tier enum). |
| `Services/Ranking/SkillTierMigrationService.swift` | NEW. One-time: replays workout logs through TierCriteriaEvaluator on first launch. |

### UI components

| File | Purpose |
|---|---|
| `Views/Components/Unbound/TierBadge.swift` | NEW. Pill chip showing tier name + optional sub-progress indicator. |
| `Views/Components/Unbound/TierBloomToast.swift` | NEW. Subtle slide-in toast for tier crossings #1-#6 (Initiate through Honed). Auto-dismiss 2.5s. |
| `Views/Components/Cinematic/RankUpCinematic.swift` | MODIFY. Already accepts BuildIdentity (from #1). Add a tier param + gate so cinematic only fires when crossing into Vessel / Unbound / Ascendant. |
| `Views/Home/UnboundHomeView.swift` | MODIFY. Replace aggregate rank letter display with tier name (e.g. "FORGED" instead of "B"). Same card location, same height. |
| `Views/Home/UnboundSkillTreeTabView.swift` | MODIFY. Each skill node renders TierBadge instead of legacy rank chip. |
| `Views/Profile/ProfileView.swift` | MODIFY. Update rank display to use tier names. |

### Resources

- `Resources/SkillTierCriteria.json` — per-skill criteria for the 9-tier ladder (volume thresholds + form requirements per tier per skill).
- `Resources/LiftTierCriteria.json` — per-lift criteria.

---

## UI integration

### Home (`UnboundHomeView.swift`)
- TODAY STATUS / TRAIN / [muscle] / RANK card: chip stays in same position with same visual styling. Just the text source changes — `aggregateRank.letter` → `aggregateTier.displayName`. Card width/height/colors unchanged.
- "LV 14" / "230 / 250" XP bar: untouched.
- Session-flow modules: untouched.

### Skill tree (`UnboundSkillTreeTabView.swift` + `SkillNodeView.swift`)
- Each node's existing rank chip is replaced by `TierBadge`. Same position, same approximate footprint.
- Locked nodes still show locked state.
- A "next tier requirement" hint on tap (e.g. "5 more verified sessions to reach Veteran").

### Lift detail screens
- Existing lift detail surfaces (under Skills tab → cluster → lift drill-down) gain a TierBadge in the hero.

### Profile
- Rank journey rail: tier names instead of letter grades.
- The aggregate rank chip in the header card uses tier name.

### Cinematic
- `RankUpCinematic` already on trunk (from #1+#2). Add a `tier: RankTitle` param. Gate the cinematic to fire only when `tier == .vessel || tier == .unbound || tier == .ascendant`. Lower-tier crossings call `TierBloomToast.show(...)` instead.

---

## Deletions

- `SubRank.letter` and `SubRank.modifier` properties — keep for now (used by other UI we won't migrate in this PR). Eventually retired in a future PR.
- `LiftRank` — DELETE. Replaced by `LiftTierState`.
- `RankBadge` — DELETE. Replaced by `TierBadge`.
- `archetypeRank` parameter naming in `LocalProgramGenerator.swift` (cosmetic debt from #1) — rename to `aggregateTier: RankTitle` while we're in this area.

## Coexistence rule

`SubRank` itself stays (it's used by AttributeValue internally for per-axis ladders — that's fine, internal math, never user-facing as a letter). `SubRank.displayName` (which returns letter grade) stays for any internal call site. Replacing user-facing rank surfaces with `RankTitle` is the goal.

---

## Data flow

### Steady state
- After each workout, `WorkoutLogService.saveLog` calls (in order):
  - Existing hooks (ProgressionEngine, SkillProgress, etc.)
  - **NEW:** `TierCriteriaEvaluator.evaluate(log:userId:)` — returns any tier crossings.
  - For each crossing:
    - If `tier ∈ {vessel, unbound, ascendant}` → post `.rankUpCinematicEvent` with tier + skill/lift/aggregate context.
    - Else → post `.tierBloomToast` with tier + name.
  - Persist new state via `UserSkillTierStore.save`.

### First launch
- `SkillTierMigrationService.migrateIfNeeded(userId:)` — if no `UserSkillTierState` exists in store, replay all workout logs through evaluator to backfill. Once done, mark migration complete.

---

## Acceptance criteria

1. **Session-flow snapshot test passes.** Home modules still render after rank surface swap.
2. **All ascension-tier-impl reference tests pass.** Tier criteria evaluator tests, skill tier state tests, migration tests.
3. **Manual sim verification:**
   - Home rank chip shows tier name (e.g. "FORGED") not letter grade
   - Skill nodes show TierBadge
   - Cinematic only fires on Vessel/Unbound/Ascendant
   - TierBloomToast fires on lower crossings
4. **No `LiftRank` references** outside the deletion diff.
5. **One-time migration succeeds** on first launch with existing workout history.

---

## Architecture decisions to lock in the plan

1. **Reuse `RankTitle` enum** — already on trunk from #1+#2. Don't create a parallel `SkillTier` enum. May add a `typealias SkillTier = RankTitle` for naming, but the underlying type stays one.
2. **Aggregate algorithm** — define exactly how the aggregate tier is computed from per-skill + per-lift states. Options: max tier reached across all, weighted average by training volume, count-of-skills-at-each-tier. Pick one in the plan.
3. **Tier criteria source-of-truth** — JSON catalog (like AttributeContributions.json from #1) or hardcoded Swift constants? Reference branch's approach should win unless there's a reason to deviate.
4. **`RankUpCinematic` parameterization** — does it accept a `SkillTierAdvance` struct (skill + from + to) or fire separately per skill / per lift / per aggregate? Pick clearest API.
5. **Migration replay performance** — for users with hundreds of logs, the migration could be slow. Batch it? Run on background queue? Show a loading indicator? Pick approach.

---

## Related memory
- [[feedback_unbound_additive_not_redesign]] — preserve session-flow
- [[feedback_unbound_cinematic_asymmetry]] — cinematic only for top tiers
- [[project_unbound_rank_redesign_2026_05_07]] — original spec for 9-tier
- [[feedback_verify_visual_diff_before_claiming_additive]] — screenshot Home before/after
- [[project_unbound_home_vs_profile_boundary]] — Home=LIVE, Profile=ARCHIVE
