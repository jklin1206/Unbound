# Major Modularity Refactor — Plan & Log

**Branch:** `claude/major-modularity-refactor` (isolated worktree off `origin/main` @ f85e8a75)
**Goal:** No mega-files (a file doing >2–3 things is too much), clear directional file names, and a
per-directory README.md navigation layer so even a small model (Haiku-class) can find any task
without reading whole files.

## Ground rules for every split

1. **Pure reorganization — zero behavior change.** Code moves verbatim. No renames of public
   symbols, no logic edits, no "improvements".
2. **Every new file keeps the full `import` block** of the original (subagents historically drop
   `import Foundation`).
3. **Access control:** if a `private`/`fileprivate` symbol is used by code moving to another file,
   either keep that cohesive group together in one file or promote to `internal` — never break
   compilation to satisfy a line target.
4. Naming: extensions of a primary type → `<Type>+<Aspect>.swift`; extracted standalone types →
   `<TypeName>.swift`. Names must state direction (what the file is *for*), not vague grab-bags.
5. Soft target ≤400 lines/file, hard cap 500. But cohesion beats line count — never shred a single
   coherent responsibility across files just to hit a number.
6. New files live beside the original (same directory) unless a domain subdirectory already exists.
7. The original file keeps the primary type and its core declaration.

## Exclusions (jlin's active branch `claude/premium-home-profile-redesign` touches these)

- `Views/Home/HomeChromeViews.swift`, `Views/Home/HomeDashboardSections.swift`,
  `Views/Home/UnboundHomeView+Controls.swift`, `Views/Profile/ProfileView.swift`,
  `Models/RankCosmetics.swift`, `Utilities/Extensions/View+UnboundStyle.swift`
  → skipped to avoid merge pain; revisit after his branch lands.

## Phases

- **Phase 1 — Mega-file splits** (waves of ~6 files, one subagent per file; gate per wave:
  `xcodegen generate` → sim build (pipefail + BUILD SUCCEEDED grep) → targeted tests → commit).
- **Phase 2 — Directional renames** (selective: only files whose names hide what they do).
- **Phase 3 — README.md navigation layer** in every significant source directory: purpose,
  file-by-file one-liners, entry points, conventions, cross-links. Root `docs/FILE_STRUCTURE.md`
  refreshed; `AGENTS.md` points at the convention.
- **Phase 4 — Final gates**: device-arch build (`generic/platform=iOS CODE_SIGNING_ALLOWED=NO`),
  full test suite, PR.

## Wave roster (app files ≥ ~640 lines, largest first, exclusions removed)

| Wave | Files |
|---|---|
| 1 | UnboundBackdrops 1015 · ActiveWorkoutContainerView 1013 · ProgramRoutineViews 984 · TrainingSessionDraft 983 · OnboardingContainerView 977 · DevBuildBootstrapper+ProgramScenarios 959 |
| 2 | SquadDetailView 956 · WorkoutLogGridView 952 · ActiveWorkoutSession 944 · FinalExamTrialModeView 910 · ProgramFocusSwitchSheet 893 · SkillTrainingPlan 874 |
| 3 | RoutineSequencePlayer 864 · SkillSessionView 862 · ClusterStaircaseHexAndRails 860 · BossRushTrialModeView 831 · UnboundApp 825 · WorkoutRewardSequence 814 |
| 4 | ThresholdRaidTrialModeView 812 · Daily100TrialModeView 800 · OnboardingFlowViewModel 800 · DailyWorkoutResolver 799 · ProgramRankExerciseDetailView 797 · OverallRankTrialDefinitions 794 |
| 5 | TrainingSessionAdapters 780 · DevPlayerToolsView 767 · ProgramCommandDock 757 · CoachActionsRow 736 · DevBuildBootstrapper+ProofState 729 · MovementCatalog+Classification 727 |
| 6 | ProgramRankProofAndRulerViews 712 · WorkoutRewardHeroComponents 705 · RoutinePlayerView 699 · SkillGuideLibrary+PullPush 696 · CoachModesStrip 694 · BodyLoadHeatmapView 687 |
| 7 | WorkoutDetailView 684 · ShopItem 676 · Step_Paywall 662 · FinisherTrialModeView 658 · Routine 658 · SetLoggerSheet 656 · SkillGraphConcept 639 · RankTrialDemoRecorderView 638 |

Test mega-files (MovementResolverTests 1051, UNBOUNDTests.swift 974, …) are a later pass —
app code first.

## Execution log

- 2026-06-11: plan written; worktree created; no other agents active in this checkout
  (cwd check: only /tmp/unbound-banners session elsewhere). Prior stale `codex/refactor-*`
  branches (2026-05-31) noted — superseded by current main; not merged.
