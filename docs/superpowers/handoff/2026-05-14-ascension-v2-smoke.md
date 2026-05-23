# Ascension Tier (Additive) — Final Smoke

Sub-project #4 shipped on `ascension-tier-v2`. Ready for merge into `program-redesign`.

## Test summary

- **261 tests, 5 pre-existing failures (unrelated).** Up from 206 baseline (#1+#2 merged trunk). 55 new tests added.
- All new tier-related tests pass:
  - `SkillTierTests`, `TierCriterionTests`, `UserSkillTierStateTests`, `LiftTierCriteriaTests`
  - Per-cluster tier table tests: Cal / Cl / Co / Hs / Hspu / Ld / Oah / Pl / Pp
  - `TierCriterionEvaluatorTests`, `UserSkillTierStoreTests`, `SkillTierMigrationTests`
- Pre-existing failures: `SkillClusterUnlockTests`, `SkillProgressXPTests` — same as before, unrelated to ascension tier.

## What ships

- **9-tier ladder** (Initiate → Novice → Apprentice → Forged → Veteran → Honed → Vessel → Unbound → Ascendant) as standalone `SkillTier` enum (Int rawValue, Comparable).
- **Per-skill tier state** stored in `UserSkillTierStore` (UserDefaults JSON cache).
- **Per-lift tier state** in `LiftTierService` (4 lifts: bench / squat / deadlift / OHP).
- **Aggregate tier** = max across all per-skill + per-lift.
- **Cinematic gate**: only Vessel / Unbound / Ascendant crossings trigger `RankUpCinematic`. Lower crossings render `TierBloomToast`.
- **One-time migration** replays existing workout logs into per-skill tier state on first launch.
- **Workout hook**: each saveLog evaluates crossings + posts `.skillTierAdvanced` notifications.
- **TierBadge** wired into skill tree node chips + skill detail view (additive — old `rankPill` still shown alongside).
- **Home aggregate rank chip** text-source swap: letter grade "B" → tier name "INITIATE" / "FORGED" / etc.
- **Profile**: aggregate tier name + per-skill ascension surface.

## Session-flow Home preserved

Confirmed in sim screenshot `/tmp/asc-v2-p10-home.png`:
- UNBOUND V-TAPER wordmark
- 21 DAYS streak chip
- "Move, Dev" greeting
- "Foundation · Legs is ready..." subhead
- TODAY STATUS / TRAIN / LEGS card with INITIATE / LV 25 (tier name not letter grade)
- BEGIN SESSION button
- SESSION PLAN: Front squat + Goblet squat (RPE 7 chips)
- COACH CUE
- 21 DAY STREAK / WEEK PATH at bottom
- HomeBuildChipCard (from #1) preserved
- Tab bar: Home / Program / Skills / Profile

## Known follow-ups

1. **LiftRank + RankBadge deletion deferred** — 15+ and 12+ callers respectively across many views (SkillTreeViewModel, UnboundHomeView, ExpandedBodyMapView, MuscleDetailSheet, ProfileView, SettingsView, BodyTierView, OnboardingPaywall, etc.). View-by-view migration to `TierBadge` is its own follow-up PR.

2. **Cinematic visual bridge** — `RankUpCinematicPresenter` accepts the new `.skillTierAdvanced` notification and gates correctly (only flagship tiers fire), but synthesizes a `RankAdvance` (SubRank) for the existing cinematic view internals. Display still shows SubRank labels (`.c → .sPlus`-style) rather than SkillTier names ("Honed → Vessel"). Follow-up: rewrite cinematic view to render `SkillTierAdvance` directly.

3. **TierBloomToast for MuscleGroupTier** — old version was replaced by SkillTier-based version. Project.yml excludes the dead stub. Future cleanup: remove the stub file entirely.

## Architecture decisions locked

- **`SkillTier` is a standalone Int-rawValue enum** (not typealias to RankTitle). Required for arithmetic + ordinal-aware code (criterion evaluation, migration, aggregate max). RankTitle (String) coexists for internal AttributeValue math from #1.
- **Aggregate algorithm**: simple max across all per-skill + per-lift tier values. TODO(future): weighted by training volume.
- **Tier criteria source**: Swift constants in per-cluster `*SkillTiers.swift` files (no JSON catalog). Each cluster's tier table is parsed via `SkillTreeContent.tierCriteriaTable(for:)` routing by `skillId` prefix.
- **`bestWeight(in:)`** in TierCriterionEvaluator requires callers to pre-filter history to the relevant exercise — documented in code comments.
- **Notification name**: `.skillTierAdvanced` (existing in `SkillTier.swift` since Phase 2.1) — not `.skillTierAdvance` as spec suggested.

## Memory references
- [[feedback_unbound_additive_not_redesign]] — session-flow preserved
- [[feedback_unbound_cinematic_asymmetry]] — only top 3 tiers cinematic
- [[project_unbound_rank_redesign_2026_05_07]] — original 9-tier spec
- [[feedback_verify_visual_diff_before_claiming_additive]] — sim screenshot confirmed
- [[project_unbound_home_vs_profile_boundary]] — preserved
