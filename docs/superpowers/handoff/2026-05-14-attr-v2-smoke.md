# Attribute System + BuildIdentity (Additive) — Final Smoke

Sub-projects #1 + #2 shipped on branch `attr-system-v2`. Ready for merge into `program-redesign`.

## Test summary

- **206 tests executed, 5 failures (all pre-existing — unrelated to attribute system).**
  - `SkillClusterUnlockTests.testClusterUnlockedWhenKeystoneAchieved` — pre-existing
  - `SkillProgressXPTests.test_atLv5_partialXP_masteredOnceBarFills_thenCaps` — 4 assertions, pre-existing
- All attribute-system tests pass (Drift, Ingest, Profile, Key, Value, Contribution, BuildIdentity, Catalog, ProfileBuildCard snapshots).
- New tests added: `UnboundHomeViewSessionFlowTests` (smoke render check).

## Verification

### Build
- `xcodebuild build` — BUILD SUCCEEDED on iPhone 17 simulator.

### Session-flow Home preserved
- "Move, [Name]" greeting visible
- Foundation/Push subhead visible
- TODAY STATUS / TRAIN / RANK card visible
- BEGIN SESSION button visible
- SESSION PLAN list visible with exercises + RPE chips
- COACH CUE card visible
- WEEK PATH chips visible
- HomeBuildChipCard slotted in additively below contextualStack

### Build chip navigation
- Tapping `HomeBuildChipCard` on Home posts `.requestNavigateToProfileTab` notification → `HomeTabView` switches to Profile tab (tag 3). Manually verified after rebuild.

### Profile
- `ProfileBuildCard` renders (full hex + buildName + per-axis grid)
- Existing identity surfaces preserved: headerCard, heatmapPlaceholder, PhotoCalendarView, badgesCard, settingsLink

### Onboarding
- Step04_PickArchetype removed from flow
- Step_BuildSeed inserted; +15 prefill on chosen axes
- Step_Arc03_Path archetype rotation gallery removed
- Step_Verdict copy generalized

### Scan
- ScanBuildDeltaCard appears in ScanPayoffView behind ≥2-scan gate
- Existing scan flow otherwise untouched

## Known follow-ups (non-blocking)

1. **`LocalProgramGenerator` parameter naming.** The function param `archetypeRank: SubRank` is unfortunately named (it's a SubRank value, not an Archetype). Cosmetic debt — rename to `aggregateRank` in a future PR.
2. **Pre-existing test failures.** `SkillClusterUnlockTests` + `SkillProgressXPTests` failures exist on `program-redesign` HEAD before this PR. Unrelated to attribute system; investigate separately.
3. **Cosmetic stale comment** in `UnboundHomeView.swift` header (lines 17, 20) still references the old 4-stat grid + StatScoreService. Cleanup is one commit's work.

## Architecture decisions documented

- **`SubRank.displayName` semantic** — kept as letter-grade ("E-", "B+", "S"). New parallel `rankTitleName` returns title text ("Initiate", "Veteran", etc.). Spec required this to avoid silently shifting existing UI.
- **`statScore` slot in ServiceContainer** — initially kept alongside `attribute` slot (Phase 6) for transitional builds; fully removed in Phase 17.
- **Badge rename** — `archetype_chosen` → `first_build_identity_resolved`. No migration table because no production users.
- **`UserProfile.preferredArchetype`** — deleted (no Codable preservation needed; no users).

## What changes vs trunk

- Files deleted: 9 (StatScore.swift, StatScoreService.swift, Archetype.swift, ArchetypeSpawnPoints.swift, 5 archetype view files)
- Files added: ~22 (6 models, 5 services, AttributeContributions.json, 7 UI components, 3 test files)
- Files modified: ~50+ (consumers migrated to BuildIdentity/AttributeService)
- Net commit count: ~26 commits on `attr-system-v2` past `program-redesign` HEAD

## Memory updates

- [[feedback_unbound_additive_not_redesign]] — reinforced by this PR's session-flow preservation
- [[feedback_verify_visual_diff_before_claiming_additive]] — added 2026-05-13 after Squads sub-project lesson; now applied here
- [[project_unbound_home_vs_profile_boundary]] — Home=LIVE, Profile=ARCHIVE — Build chip on Home navigates to Profile per this principle
