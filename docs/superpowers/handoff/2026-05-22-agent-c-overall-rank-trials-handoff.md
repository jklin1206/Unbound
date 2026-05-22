# Agent C Handoff: Trial Readiness + Overall Rank Trial Runner

**Source roadmap:** `docs/superpowers/handoff/2026-05-21-unified-workout-progression-migration-roadmap.md`  
**Roadmap lane:** Phase 7, with small Phase 6 receipt integration if needed  
**Branch:** `codex/progression-overall-rank-trials`  
**Simulator lane:** iPad mini (A17 Pro), iOS 26.3, simulator id `FC56466C-9963-4EC4-9841-5267D758B8F7`  
**Primary goal:** Build the Overall Rank gate: Trial Readiness, named trial unlock state, and a trial runner that advances Overall Rank only when the named trial is passed.

## Start Here

You are one of three parallel agents. Work only the Overall Rank trial lane. Do not rename the weekly `Trial*` system to Weekly Vows; Agent B owns that. Do not migrate broad `MovementCatalog` callers; Agent A owns that. You may read catalog metadata and add narrow query helpers only if trial readiness requires them.

Before editing, make this an explicit goal in the roadmap:

- Add a dated note under Phase 7 saying this branch is implementing Trial Readiness and the Overall Rank gate.
- Track whether the runner is service-only, UI-visible, or fully simulator-proven.

## Why This Lane Exists

The roadmap says Overall Rank should stop being a passive computed label. A user should meet requirements, unlock a named trial, attempt it, and advance Overall Rank only if the trial is passed. Failed trials should log history and rewards for performed work, but not grant the rank.

## Ownership

Own these areas:

- new service/model files for `TrialReadinessService`, rank-trial definitions, requirements, and attempt state
- profile progression/rank surfaces only where needed to show readiness
- trial runner entry point and draft construction
- `TrainingSessionDraft -> PerformanceLog -> TrainingCompletionService` integration for trial attempts
- tests for readiness, pass/fail, and no-rank-advance-without-pass

Avoid these areas unless absolutely required:

- weekly `Trial*`/Weekly Vow rename work
- broad `MovementCatalog` migration
- Home weekly rhythm cards
- squad weekly honors
- large visual redesigns of Profile

## Product Contract

Overall Rank trials are rank gates, not weekly events.

Minimum behavior:

- locked: user lacks requirements
- ready: user meets requirements and can start the named trial
- attempted: attempt history exists
- passed: rank advances
- failed: history/receipt exists, rank does not advance

Readiness should consider:

- movement standards at target tier
- skill standards at target tier
- top-N attribute floor
- minimum Overall LV
- path/equipment-aware variation where data exists

## Implementation Shape

1. Add readiness service:
   - Pure, testable evaluator first.
   - Inputs should be explicit state snapshots, not hidden global reads where avoidable.
   - Output should explain missing requirements for UI.

2. Add trial definitions:
   - Named by target rank/tier.
   - Build one V1 trial enough to prove the pipeline.
   - Keep path/equipment variants simple and deterministic.

3. Add runner path:
   - Create a `TrainingSessionDraft`.
   - Complete into `PerformanceLog`.
   - Finish through `TrainingCompletionService`.
   - Record pass/fail separately from normal completion rewards.

4. Gate rank advance:
   - No Overall Rank advance from aggregate stats alone.
   - Passing the named trial advances rank.
   - Failed attempts do not advance rank.

5. Add Profile readiness UI:
   - Keep it small: readiness card, missing requirements, start button when ready.
   - Avoid a full redesign.

6. Update the roadmap with proof status and gaps.

## Testing Requirements

Use XcodeBuildMCP, not raw `xcodebuild`, for simulator testing.

Simulator assignment:

```text
iPad mini (A17 Pro)
simulator id: FC56466C-9963-4EC4-9841-5267D758B8F7
iOS 26.3
```

If the simulator is shut down, either ask the coordinator to boot it or use XcodeBuildMCP simulator tooling if available in your session. Before any build/run/test, call `session_show_defaults` and make sure your active defaults target this simulator, project `/Users/jlin/Documents/toji/UNBOUND/UNBOUND.xcodeproj`, scheme `UNBOUND`, configuration `Debug`, bundle id `com.unboundapp.ios`.

Focused tests to add/run:

- readiness locked when movement/skill/attribute/LV requirements are missing
- readiness becomes ready when requirements are met
- failed trial logs attempt and receipt but does not advance Overall Rank
- passed trial advances Overall Rank exactly once
- duplicate completion/attempt id does not double-advance rank
- trial runner draft maps to valid `PerformanceLog` blocks

Simulator proof:

- Launch Profile, preferably with a DEBUG bootstrap flag or seeded state that makes one trial ready.
- Show Trial Readiness card in locked and/or ready state.
- Start the trial runner from Profile.
- Complete a pass path and verify the reward sequence.
- Verify Overall Rank advances only after pass.
- Capture screenshots of readiness, runner, receipt, and rank advanced state.

## Acceptance Criteria

- `TrialReadinessService` exists and is unit-tested.
- At least one named Overall Rank trial can be unlocked, run, passed, and failed in tests.
- Rank does not advance without a passing trial.
- Trial attempts use `TrainingSessionDraft`, `PerformanceLog`, and `TrainingCompletionService`.
- Profile exposes a minimal readiness/start surface.
- Roadmap Phase 7 is updated with what is simulator-proven and what remains.

## Branch / Merge Guidance

Work on `codex/progression-overall-rank-trials`, not the same branch as the other agents. This branch should avoid renaming existing weekly `Trial*` files. If Agent B lands first and renames weekly types, adapt to the new Weekly Vow names while preserving the Overall Rank trial vocabulary in this branch.
