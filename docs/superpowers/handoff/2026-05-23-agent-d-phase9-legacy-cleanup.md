# Agent D Handoff: Phase 9 Legacy Cleanup

**Base branch:** `origin/codex/progression-overall-rank-trials`  
**Work branch:** `codex/progression-phase9-legacy-cleanup`  
**Model:** GPT-5.5, extra high reasoning  
**Roadmap lane:** Phase 9, with light Phase 1/6 proof support  
**Simulator lane:** iPhone 17 Pro Max, iOS 26.3, `E3395E63-B8C9-43D9-B088-8C54B0E97076`  
**Primary goal:** Audit, quarantine, and delete only proven legacy completion paths so no hidden old pipeline can award AP, XP, skill XP, rank progress, rewards, or trial progress differently from `TrainingCompletionService`.

## Coordination Rules

You are not alone in the codebase. Other agents may be editing catalog, resolver, and trial files in parallel. Do not revert edits you did not make. Treat broad local dirt as user/coordinator work unless it is directly in your owned files.

Agents should not work on one shared branch. Start from `origin/codex/progression-overall-rank-trials`, make this branch, and let the coordinator merge.

## Own

- `UNBOUND/ViewModels/WorkoutLoggingViewModel.swift`
- legacy completion callers that still save `WorkoutLog` or `SessionLog` directly
- compatibility adapters in `TrainingSessionAdapters` only if needed
- `UNBOUND/Services/WorkoutLog/*` only for quarantine markers or compatibility checks
- focused tests:
  - `UNBOUNDTests/Models/ProgramAwareLoggingTests.swift`
  - `UNBOUNDTests/Services/TrainingSessionDraftStoreTests.swift`
  - adapter/idempotency tests around legacy log compatibility

## Avoid

- MovementCatalog caller migration beyond read-only audit.
- Daily resolver modifier work.
- Adding new rank trial definitions.
- Weekly Vow product behavior.
- Deleting old UI or services just because they look stale. Delete only when no route references them and tests prove compatibility.

## Implementation Target

This lane is deliberately conservative. Phase 9 is not a bonfire.

Start with an audit:

```text
rg -n "saveLog\\(|WorkoutLogService|SupabaseWorkoutLogService|SessionLog|recordProgressionForLegacyWorkout|previewProgression|MIGRATION\\(Phase 9\\)" UNBOUND UNBOUNDTests
```

Classify every hit:

- canonical unified route
- compatibility history write
- old direct side-effect path that can still award progression
- read-only history/rendering path
- test/mock only

Then implement one safe cleanup:

1. Add `MIGRATION(Phase 9)` quarantine comments to any direct-save path that must remain.
2. Remove or redirect one old side-effect path only if the replacement route is already simulator- or test-proven.
3. Add an idempotency/compatibility test proving old logs still render or adapt, while new progression writes go through `TrainingCompletionService`.
4. Update the roadmap Phase 9 with a dated audit table and the exact deletion/quarantine result.

Good candidates:

- direct old progression side effects after `WorkoutLogService.saveLog`
- duplicate reward summary builders that are no longer reachable
- compatibility adapters that can be made read-only
- tests that should assert "legacy save does not perform progression math itself"

## Tests

Use XcodeBuildMCP, not raw `xcodebuild`.

Before any build/test/run:

```text
Call session_show_defaults.
Confirm projectPath = /Users/jlin/Documents/toji/UNBOUND/UNBOUND.xcodeproj
Confirm scheme = UNBOUND
Set or confirm simulator = iPhone 17 Pro Max / E3395E63-B8C9-43D9-B088-8C54B0E97076
```

Focused tests:

- `ProgramAwareLoggingTests`
- `TrainingSessionDraftStoreTests`
- completion-service idempotency tests
- any test around `WorkoutLog` / `SessionLog` compatibility touched by cleanup

Simulator proof:

- Build/run on iPhone 17 Pro Max.
- Exercise one legacy-compatible route if it remains reachable, then finish through the unified reward receipt.
- Confirm no duplicate receipt, no double-save, no second rank/progression award.

## Done Means

- Phase 9 has a concrete audit, not just a vague "cleanup later."
- At least one old side-effect path is deleted, redirected, or explicitly quarantined with a test.
- Existing old history compatibility is preserved.
- No hidden old pipeline can award progression differently in the touched route.

