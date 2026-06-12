# Modularize — Arm A (delegate tiering: sonnet/opus) — COMPLETE

Plan of record: /tmp/modularize-experiment/PLAN.md (frozen, shared with Arm B)
Baseline: 1166 tests / 8 skipped / 1 pre-existing failing case (MovementResolverTests.testProgressionVariantVisualsAreNotExactDuplicateAssets).

## Phase 1 — logic splits
- [x] L1 session trio → Models/Sessions/ (ActiveWorkoutSession kept 692 — nested types referenced as AWS.X from 17+ sites)
- [x] L2 SkillTrainingPlan → Models/Skills/
- [x] L3 WorkoutRewardSequence → Models/Rewards/
- [x] L4 DailyWorkoutResolver split in place
- [x] L5 OnboardingFlowViewModel → ViewModels/Onboarding/
- [x] L6 UnboundBackdrops — LEFT WHOLE (single-concern backdrop+legibility pipeline; splitting = 8 pointless widenings)

## Phase 2 — UI splits
- [x] V1 WorkoutLogGridView 952→235 (+DeckOfProofDrawStage 496 — cohesive component, accepted over budget)
- [x] V1b ActiveWorkoutContainerView 1013→626 (+3 extension files)
- [x] V2 ProgramRoutineViews 984→105 (one view per file)
- [x] V3 OnboardingContainerView 977→419
- [x] V4 SquadDetailView 956→116 (+Sections/Components/Actions; needed Amendment 1)
- [x] V5 ProgramFocusSwitchSheet 893→426 (+Models/Helpers)
- [x] V6 RoutineSequencePlayer — cards extracted; player FSM LEFT WHOLE at 698 (single tightly-coupled state machine)
- [x] V7 SkillSessionView → Views/Home/SkillSession/ module (862→336 + 3 ext + README)
- [x] V8 ClusterStaircaseHexAndRails → Hex/Rails/RailsCG
- [x] V9 UnboundApp 825→101 (opus; byte-identity verified per block)
- [x] V10 ProgramRankExerciseDetailView 797→110 (+Hero/Log/Data)

## Phase 2.5 — regroups (all git mv, zero content changes)
- [x] R1 Models → Sessions/Movements/Skills (42 moves)
- [x] R2 Models → Ranking/Standards/Squads/Body (40 moves)
- [x] R3 Models → Rewards/Program/Routines/Trials/Core + SVGPathParser→Utilities (44 moves)
- [x] R4 Views/Home → Dashboard/SkillTree/SkillDetail/SkillSession (51 moves; Home root now pure subdirs)
- [x] R5 Components/Unbound → WorkoutReward/ (9 moves; TierBloomToast untouched)
- [x] R6 Views/Program → SessionEditor/ + WorkoutReady/ (12 moves)
- [x] R7 Services → TrainingCompletion/ + Notifications/ (3 moves)

## Phase 3 — docs
- [x] D1 12 Services subdir READMEs
- [x] D2 19 Views/ViewModels/Utilities READMEs
- [x] D3 ARCHITECTURE.md (6 verified flows) + AGENTS.md navigation section (repo has no CLAUDE.md)

## Verification (all green)
- [x] Suite = baseline exactly (1166/8/1 same case) after Phase 1, 2, 2.5+3
- [x] Device-arch build (generic/platform=iOS) SUCCEEDED
- [x] Runtime: program/skills/squad/profile screenshots verified on iPhone 17 Pro sim; 3x launch gauntlet alive
- [x] Content fidelity: normalized line-diff per unit — only imports/extension wrappers/MARK deltas

## Intentionally left whole
- UnboundBackdrops (1015) — one backdrop+legibility pipeline
- ActiveWorkoutSession (692) — nested types are public API surface
- RoutinePlayerView FSM (698) — single coupled state machine
- DeckOfProofDrawStage (496) — one cohesive animated component
- 5 RankTrials mode views, OverallRankTrialDefinitions, MovementCatalog content tables, DevBuildBootstrapper+*, ProgramCommandDock, CoachActionsRow, Views/Program/Overview/, Views/Onboarding/Steps/, Services/ProgramGeneration + Services/Squads dirs (single-concern)
- WorkingWeight.swift at Models root (straddles Sessions/Standards — flagged in Models/README.md)

## Defects found by orchestrator gates (executor misses)
- 5 missed `private` widenings across V1b/V4/V7 (requestComplete, currentUserId, currentSeason, weightUnitRaw, services) — 3 extra build cycles
- L1 renamed private helper positive()→positiveValue() (contract deviation, behavior-neutral)
- V4 added ~20 new MARK labels (annotation-only deviation)
- README-as-bundle-resource collision → project.yml `**/README.md` exclude (Amendment 2)

## Known gaps / risks
- Merge conflicts expected vs jlin's active redesign branch (Views/Home, Profile, Rewards churn) — git mv rename detection mitigates
- docs/ARCHITECTURE.md (pre-existing deep map) cites pre-move paths — future refresh
