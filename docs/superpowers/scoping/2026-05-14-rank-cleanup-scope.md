# Rank Cleanup Follow-ups — Scoping Doc

Two deferred items from sub-project #4 (Ascension Tier). This doc estimates effort + risk so we can decide ordering.

---

## Follow-up A: Delete LiftRank + RankBadge

### LiftRank — 39 call sites across 16 files

**Files** (by category):

**Models (5):** `LiftRank.swift` (delete), `BodyRegion.swift`, `RankState.swift`, `AttributeKey.swift`, `SkillTier.swift`, `ScanContext.swift`

**ViewModels (1):** `SkillTreeViewModel.swift`

**Views (4):** `UnboundHomeView.swift`, `ExpandedBodyMapView.swift`, `MuscleDetailSheet.swift`, `ProfileView.swift`

**Settings (1):** `SettingsView.swift`

**Services (5):** `RankService.swift`, `RankServiceProtocol.swift`, `MuscleRankCalculator.swift`, `ScanContextBuilder.swift`, `AttributeCatalog.swift`

**Migration story per caller type:**
- Model files referencing `LiftRank` as a field — change to `SkillTier` field, migrate stored data shape (Codable break — acceptable since no production users).
- Service files using `LiftRank` for math/ranking — replace with `SkillTier` calls via `LiftTierService.shared`.
- Views displaying lift ranks — swap `RankBadge(rank: liftRank)` → `TierBadge(tier: liftTier)`.

**Risk level:** Medium. Lots of files but each migration is shallow. Likely 1-2 hour focused pass.

### RankBadge — 13 call sites across 8 files

**Files:** `MuscleGroupTier.swift`, `UnboundHomeView.swift`, `ExpandedBodyMapView.swift`, `MuscleDetailSheet.swift`, `BodyTierView.swift`, `SkillTreeView.swift`, `Step29_SocialProof.swift`, `Step_Paywall.swift`

**Migration:** `RankBadge(rank: SubRank, ...)` → `TierBadge(tier: SkillTier, ...)`. Some sites pass a SubRank derived from per-muscle/per-region data — need to first compute the equivalent SkillTier, then pass it. Onboarding step files (`Step29_SocialProof`, `Step_Paywall`) likely use the badge for visual decoration; might be OK to keep showing SubRank → tier-style display via a small adapter.

**Risk level:** Lower than LiftRank. Surface-level UI swaps mostly.

### Combined estimated effort

- **~4 hours** for both, single focused pass.
- Done as one PR (`rank-cleanup-v1` branch) to keep diff coherent.

### Risk callouts

- `RankState.swift` and `BodyRegion.swift` are touched by many other systems — verify nothing else breaks after their LiftRank field is gone.
- `Step_Paywall.swift` and `Step29_SocialProof.swift` are onboarding screens — they need to compile but UX impact is low.

---

## Follow-up B: Cinematic visual bridge → native SkillTierAdvance rendering

### Current state

`RankUpCinematicPresenter` accepts `.skillTierAdvanced` notifications and gates correctly (only flagship Vessel/Unbound/Ascendant fire). BUT it synthesizes a `RankAdvance` (SubRank-shaped) to feed the existing cinematic view internals. The cinematic STILL displays SubRank labels (`.c → .sPlus`) instead of SkillTier names ("Honed → Vessel").

### What needs rewriting

**Files:**
- `Views/Components/Cinematic/RankUpCinematic.swift` (342 lines)
  - `advance: RankAdvance` property → `advance: SkillTierAdvance`
  - Internal layout reads SubRank fields (`fromRank.letter`, `toRank.displayName`) — swap to SkillTier accessors
  - Particle/animation triggers tied to SubRank ordinal — re-tune for SkillTier rawValue (or simplify since gate only fires for top 3 anyway)
- `Views/Components/Cinematic/RankUpShareCard.swift` (193 lines)
  - Same swap: `RankAdvance` → `SkillTierAdvance`
  - Asset references for rank tier images: `rank_tier_<letter>` → `rank_title_<tier>` (RankTitle's `assetName` pattern from `SubRank.swift`)
- `RankUpCinematicPresenter` — delete the bridge synth code, just pass `pendingTier` straight through.

**Open questions:**
1. Does the share card need a new visual treatment for tier-named ranks, or just swap text?
2. The cinematic's particle direction/intensity depends on rank delta (e.g. "you jumped 2 letters"). Translate to "you jumped 2 tiers"? Or fixed intensity since gate already filters to top 3?
3. Existing RankAdvance code paths (attribute system, lift-level rank-ups) ALSO use this cinematic. If we change the param type, those paths break. Need to either:
   - Keep RankAdvance support alongside SkillTierAdvance (two paths)
   - Migrate attribute / lift rank-ups to also emit SkillTierAdvance

### Estimated effort

- **~2-3 hours** if we keep both code paths (additive)
- **~4-5 hours** if we fully migrate attribute + lift rank-ups too (more thorough)

### Risk

Low. Cinematic is isolated. Hardest part is asset coordination (do we have `rank_title_vessel` art? `rank_title_unbound`? `rank_title_ascendant`? Or do we reuse SubRank assets?).

---

## Recommendation

Do them in ONE combined PR (`rank-cleanup-v1`):
1. First — delete LiftRank + RankBadge (Follow-up A)
2. Then — rewrite cinematic (Follow-up B) on the now-clean foundation

Total: ~6-8 hours focused work. After this lands, the legacy rank system is fully decomissioned and only SkillTier remains user-facing.

Alternative: do them separately if you want smaller PRs. A then B as two sequential PRs.

## What to NOT do

- Don't migrate `SubRank.swift` itself — internal AttributeValue math from #1 still uses it. Internal-only references stay.
- Don't touch scan flow rank surfaces (that's #3's territory).
- Don't change cinematic asset bundles unless we have replacement art ready.
