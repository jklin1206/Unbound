# Modularize — Arm B (fable subagents) — COMPLETE

Plan of record: /tmp/modularize-experiment/PLAN.md (frozen, shared with Arm A). Prompts identical to Arm A modulo logged amendments (AMENDMENTS.md).
Baseline: 1166 tests / 8 skipped / 1 pre-existing failing case.

## Phase 1 — logic splits
- [x] L1 session trio → Models/Sessions/ (13 files; ActiveWorkoutSession 294 via nested-types-in-extension)
- [x] L2 SkillTrainingPlan → Models/Skills/ (6 files incl. SessionLog.swift; 0 widenings)
- [x] L3 WorkoutRewardSequence → Models/Rewards/ (0 widenings — helpers colocated with caller)
- [x] L4 DailyWorkoutResolver split (7 widenings = minimum edge set)
- [x] L5 OnboardingFlowViewModel → ViewModels/Onboarding/ (0 widenings)
- [x] L6 UnboundBackdrops — LEFT WHOLE (same verdict as Arm A, seam-level evidence)

## Phase 2 — UI splits
- [x] V1 ActiveWorkout pair in ONE unit — container 1013→584 (+4 ext; 584 over budget w/ rule-grounded rationale), grid 952→413
- [x] V2 ProgramRoutineViews → 9 one-view files (root renamed ProgramRoutinesTab.swift)
- [x] V3 OnboardingContainerView 977→418
- [x] V4 SquadDetailView 956→116 (+Data/Header/Sections) — first try
- [x] V5 ProgramFocusSwitchSheet 893→165 (11 helpers kept private via grouping)
- [x] V6 RoutineSequencePlayer — Drive seam found; core exactly 450
- [x] V7 SkillSessionView → Home/SkillSession/ module + README (862→259)
- [x] V8 ClusterStaircase → Hex/Rails/RailsCG (git mv preserves history)
- [x] V9 UnboundApp 825→101 (byte-identity evidence per block)
- [x] V10 ProgramRankExerciseDetailView 797→352 (+Sections/LogControls)

## Phase 2.5 — regroups (git mv, zero content changes)
- [x] R1 42 moves + 3 READMEs · R2 40 + 4 · R3 44 + 6 · R4 51 + 4 · R5 9 + 2 (TierBloomToast stub documented) · R6 12 + 3 · R7 3 + 41-subdir Services README

## Phase 3 — docs
- [x] D1 12 service READMEs · D2 19 view-layer READMEs · D3 ARCHITECTURE.md (6 verified flows; evaluateTierCrossings wiring gap documented) + AGENTS.md section
- [x] docs/ARCHITECTURE.md deep-map paths refreshed post-move (review finding); .dd/.dd-device gitignored

## Verification (all green)
- [x] Suite = baseline exactly (1166/8/1 same case) after Phase 1, Phase 2 (FIRST-TRY compile), regroups, docs
- [x] Device-arch build SUCCEEDED
- [x] Runtime: program/skills/squad/profile screenshots verified; 3x launch gauntlet alive
- [x] Content fidelity: normalized per-unit diffs — zero substantive deviations all 16 split units

## Intentionally left whole
Same set as Arm A (UnboundBackdrops, trial mode views, content tables, DEBUG tooling, Overview/Steps/coherent service dirs) plus: ActiveWorkoutContainerView core at 584 (private non-@State deps make 450 unreachable within rules); ExerciseExplainerLibrary at 533 (single content table). WorkingWeight.swift at Models root (flagged).

## Executor defect log
- Zero compile errors at any gate (Arm A: 5 missed widenings, 3 extra build cycles — but note Arm B prompts included self-check #5, Amendment 3 asymmetry)
- Deviations: root-file rename in V2 (better-telegraphing name, flagged); widened immutable `let run` in V6 (allowed, flagged)
- Dead-code finds reported (not touched): RoutinePreviewSheet, showInviteSheet, shouldSkip, skillProgress, ghost(ei:si:), legacy OnboardingViewModel, DeckExerciseHiddenPanel, usesOriginalNodeArtwork branch

## Known gaps / risks
- Merge conflicts expected vs jlin's active redesign branch (same as Arm A)
- evaluateTierCrossings still unwired (pre-existing, now documented in ARCHITECTURE.md)
