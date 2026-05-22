# Agent B Handoff: Weekly Vows Migration

**Source roadmap:** `docs/superpowers/handoff/2026-05-21-unified-workout-progression-migration-roadmap.md`  
**Roadmap lane:** Phase 6A  
**Branch:** `codex/progression-weekly-vows`  
**Simulator lane:** iPhone 17, iOS 26.3, simulator id `810087B3-226D-4398-8ABD-9FF61E642E1D`  
**Primary goal:** Rename and migrate the current weekly `Trial*` / challenge concept into optional Weekly Vows: Ember, Overdrive, and Apex. Reserve the word "Trial" for Overall Rank gates only.

## Start Here

You are one of three parallel agents. Work only the weekly vow lane. Do not implement Overall Rank trial readiness, do not change `MovementCatalog` caller ownership beyond reading metadata, and do not delete compatibility types until tests prove the migration.

Before editing, make this an explicit goal in the roadmap:

- Add a dated note under Phase 6A saying this branch is migrating weekly `Trial*` concepts to Weekly Vows.
- Track old names that remain as temporary adapters.

## Why This Lane Exists

The roadmap says Weekly Vows are not started and current app code still uses `Trial*` for a weekly opt-in system. That creates product confusion because "Trial" must mean an Overall Rank gate. This lane should leave users thinking: a Vow is optional weekly spice; a Trial is how rank advances.

## Ownership

Own these areas:

- weekly trial/vow models currently named like `Trial`, `TrialCard`, `TrialTheme`, `TrialsState`, `WeeklyHonor`
- `UNBOUND/Services/Trials/*` only for the weekly system rename/adapters
- weekly cards, picker, active card, toasts, and Home weekly rhythm surfaces
- tests currently named `TrialGeneratorTests`, `TrialsServiceTests`, `TrialsStoreTests`, `TrialThemeTests`, `TrialCardKindTests`, `WeeklyHonorTests`

Avoid these areas unless absolutely required:

- `MovementCatalog` caller migration
- new Overall Rank `TrialReadinessService`
- profile rank gate UI
- training completion internals, except to route Vow completion through the existing unified pipeline if a small path already exists

## Product Vocabulary

Use these user-facing concepts:

- **Weekly Vow:** the weekly optional event system
- **Ember:** rest-day / low-day vow, recovery-safe, 8-12 minutes, RPE 3-5
- **Overdrive:** after-workout finisher, 6-12 minutes, RPE 7-8
- **Apex:** dedicated weekend event, 20-45 minutes, RPE 8-9

Do not use "Trial" or "Challenge" in user-facing weekly copy.

## Implementation Shape

1. Introduce `WeeklyVow` naming:
   - Prefer new types or typealiases that let old persistence decode safely.
   - Keep old `Trial*` names only as temporary adapters where changing all call sites would create unnecessary conflict.

2. Rename visible UI:
   - Picker prompt/cards
   - active weekly status card
   - completion/toast copy
   - profile/history/squad references if they refer to the weekly system

3. Keep completion unified:
   - Vow work should route through `TrainingSessionDraft -> PerformanceLog -> TrainingCompletionService -> WorkoutRewardSequenceView` when implemented in this lane.
   - Award normal AP/attribute/body/skill/LV rewards from actual work.
   - Do not award flat attribute XP just because a vow was cleared.

4. Preserve old data:
   - Existing weekly selections should decode.
   - Store migration must be idempotent.
   - Tests should prove old saved state still loads.

5. Update the roadmap with exactly which old names remain and why.

## Testing Requirements

Use XcodeBuildMCP, not raw `xcodebuild`, for simulator testing.

Simulator assignment:

```text
iPhone 17
simulator id: 810087B3-226D-4398-8ABD-9FF61E642E1D
iOS 26.3
```

If the simulator is shut down, either ask the coordinator to boot it or use XcodeBuildMCP simulator tooling if available in your session. Before any build/run/test, call `session_show_defaults` and make sure your active defaults target this simulator, project `/Users/jlin/Documents/toji/UNBOUND/UNBOUND.xcodeproj`, scheme `UNBOUND`, configuration `Debug`, bundle id `com.unboundapp.ios`.

Focused tests to run or adapt:

- weekly/vow generator tests
- weekly/vow service tests
- weekly/vow store migration tests
- weekly honor tests if the squad/profile strip refers to weekly completion
- copy regression test or UI assertion proving no weekly user-facing copy says "Trial"

Simulator proof:

- Launch Home.
- Open the weekly vow picker.
- Select one vow type.
- Verify Home shows the active Weekly Vow with Ember/Overdrive/Apex vocabulary.
- If completion is in scope, complete the vow through the unified reward sequence and capture receipt proof.
- Capture screenshots of picker, active vow card, and any completion/receipt proof.

## Acceptance Criteria

- Weekly user-facing surfaces no longer say "Trial" or "Challenge."
- Ember / Overdrive / Apex are represented clearly in model and UI.
- Existing weekly state decodes through adapters or migration.
- Tests prove generation, persistence, and no-trial-copy behavior.
- Roadmap Phase 6A is updated with completed work and remaining adapters.

## Branch / Merge Guidance

Work on `codex/progression-weekly-vows`, not the same branch as the other agents. This branch may touch files with `Trial*` names; keep changes scoped to the weekly system so Agent C can build Overall Rank trials in separate files without semantic collision.
