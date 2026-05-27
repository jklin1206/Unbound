# Agent C Handoff: Overall Rank Upper Trials

**Base branch:** `origin/codex/progression-overall-rank-trials`  
**Work branch:** `codex/progression-overall-rank-upper-trials`  
**Model:** GPT-5.5, extra high reasoning  
**Roadmap lane:** Phase 7  
**Simulator lane:** iPad mini (A17 Pro), iOS 26.3, `FC56466C-9963-4EC4-9841-5267D758B8F7`  
**Primary goal:** Extend Overall Rank trial coverage beyond the current early/mid ladder while preserving the same `TrainingSessionDraft -> PerformanceLog -> TrainingCompletionService` runner.

## Coordination Rules

You are not alone in the codebase. Other agents may be editing catalog, resolver, and cleanup files in parallel. Do not revert edits you did not make. Keep your changes to rank-trial code and tests.

Agents should not work on one shared branch. Start from `origin/codex/progression-overall-rank-trials`, make this branch, and let the coordinator merge.

## Own

- `UNBOUND/Services/Ranking/OverallRankTrialService.swift`
- `UNBOUNDTests/Services/OverallRankTrialServiceTests.swift`
- `UNBOUND/Views/Profile/OverallRankTrialReadinessCard.swift` only for small readiness copy/state support
- debug proof bootstraps only if needed for simulator proof

## Avoid

- `MovementCatalog.swift` except read-only use of existing definitions.
- `DailyWorkoutResolver.swift`.
- Weekly Vow files in `UNBOUND/Services/Trials/*`.
- Phase 9 legacy deletion work.
- Profile redesign beyond small trial-readiness support.

## Current Baseline

The service already covers:

- Initiate -> Novice: The Awakening
- Novice -> Apprentice: The Calibration
- Apprentice -> Forged: The Forge
- Forged -> Veteran: The Reckoning
- Veteran -> Master: The Gauntlet

Your lane should add the remaining upper-rank gates in a bounded way:

- Master -> Vessel
- Vessel -> Unbound
- Unbound -> Ascendant

If all three are too large, implement the next one fully and scaffold definitions/tests for the rest only if clean.

## Implementation Target

For each new trial:

1. Add a named `OverallRankTrialDefinition`.
2. Use MovementCatalog-backed movement IDs and rank-standard IDs.
3. Include min Overall LV, top-N attribute floor, equipment requirements, movement standards, skill standards, and performance standards.
4. Add it to `OverallRankTrialDefinitions.all`.
5. Ensure `nextTrial(after:)` selects it correctly.
6. Preserve pass/fail/idempotency behavior by performance log id.
7. Do not let passive aggregate rank advance Overall Rank.

Prefer variation. Upper trials should not all feel like the same bodyweight circuit with bigger numbers. Mix strength, carry, cardio, skill, and loaded-control standards where the catalog supports it.

## Tests

Use XcodeBuildMCP, not raw `xcodebuild`.

Before any build/test/run:

```text
Call session_show_defaults.
Confirm projectPath = /Users/jlin/Documents/toji/UNBOUND/UNBOUND.xcodeproj
Confirm scheme = UNBOUND
Set or confirm simulator = iPad mini (A17 Pro) / FC56466C-9963-4EC4-9841-5267D758B8F7
```

Focused tests:

- readiness locked/ready for every new definition
- draft -> performance log mapping for every new definition
- failing attempt records history but does not advance rank
- passing attempt advances only the target rank
- duplicate completion for the same performance log is idempotent
- all definitions are catalog-backed and reachable through `nextTrial(after:)`

Simulator proof:

- Build/run on iPad mini.
- Use or add a DEBUG-only proof seed for one new upper trial.
- Open Profile Trial Readiness, start trial, complete a passing attempt, see rank-up in reward sequence, return to Profile.
- Screenshot readiness, Workout Ready, rank-up beat, and passed state.

## Done Means

- At least one upper-rank trial is fully implemented, tested, and simulator-proven.
- Prefer all three upper definitions if scope stays clean.
- No passive rank path bypasses the trial runner.
- Roadmap Phase 7 has a dated note listing added gates and proof status.
