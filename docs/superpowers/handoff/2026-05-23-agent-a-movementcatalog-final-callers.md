# Agent A Handoff: MovementCatalog Final Callers

**Base branch:** `origin/codex/progression-overall-rank-trials`  
**Work branch:** `codex/progression-movementcatalog-final-callers`  
**Model:** GPT-5.5, extra high reasoning  
**Roadmap lane:** Phase 5  
**Simulator lane:** iPhone 17, iOS 26.3, `810087B3-226D-4398-8ABD-9FF61E642E1D`  
**Primary goal:** Finish the next high-value slice of `MovementCatalog` caller migration without touching resolver modifiers, Overall Rank trial definitions, or Phase 9 deletion work.

## Coordination Rules

You are not alone in the codebase. Other agents may be editing resolver, trial, and cleanup files in parallel. Do not revert edits you did not make. Keep your write set narrow and report every changed file.

Agents should not work on one shared branch. Start from `origin/codex/progression-overall-rank-trials`, make this branch, and leave merge/reconciliation to the coordinator.

## Own

- `UNBOUND/Models/MovementCatalog.swift`
- movement resolution helpers used by progression/rank/body/attribute code
- `UNBOUND/Services/Progression/ProgressionEngine.swift`
- focused catalog/progression tests:
  - `UNBOUNDTests/Services/Progression/ProgressionEngineBehaviorTests.swift`
  - catalog validation tests that already mention `MovementCatalog`
  - only minimal tests elsewhere if required by this lane

## Avoid

- `UNBOUND/Services/ProgramGeneration/DailyWorkoutResolver.swift` and `ProgramScheduler.swift` unless read-only.
- `UNBOUND/Services/Ranking/OverallRankTrialService.swift` unless read-only.
- `UNBOUND/Services/Trials/*` Weekly Vow implementation unless read-only.
- `WorkoutLoggingViewModel`, `WorkoutLogService`, and deletion/quarantine work owned by Agent D.
- UI redesigns and broad asset changes.

## Implementation Target

Make one more meaningful caller group stop depending on `ExerciseCatalog` or string-only metadata.

Start with:

1. `rg -n "ExerciseCatalog|legacy|rankStandardMovementId|variantOfMovementId|attributeWeights|bodyRegions" UNBOUND UNBOUNDTests`
2. Identify callers that are still using `ExerciseCatalog` for progression/rank/body/attribute decisions.
3. Replace those callers with `MovementCatalog.definition(for:)`, `canonicalExercise(named:)`, resolved `rankStandardMovementId`, logger metadata, attribute weights, and body regions.
4. Keep compatibility shims for old saved logs, but make new progression decisions flow from `MovementCatalog`.
5. Add a short dated note under Phase 5 of the roadmap with exactly what migrated and what remains.

Good candidates:

- remaining progression/rank fallback callers
- body-map or attribute contribution paths that can resolve through catalog identity
- tests still asserting against `ExerciseCatalog` when `MovementCatalog` should be authoritative

## Tests

Use XcodeBuildMCP, not raw `xcodebuild`.

Before any build/test/run:

```text
Call session_show_defaults.
Confirm projectPath = /Users/jlin/Documents/toji/UNBOUND/UNBOUND.xcodeproj
Confirm scheme = UNBOUND
Set or confirm simulator = iPhone 17 / 810087B3-226D-4398-8ABD-9FF61E642E1D
```

Focused tests to run:

- `ProgressionEngineBehaviorTests`
- Movement catalog validation/final-state query tests
- any catalog tests changed by this work
- a small progression receipt or program-aware logging test if the migrated caller affects completion output

Simulator proof:

- Build/run on iPhone 17.
- Use Program or a focused debug route only if your caller migration affects visible completion behavior.
- Capture proof that a migrated movement still logs with the expected rank standard and receipt metadata.

## Done Means

- At least one remaining progression/rank/body/attribute caller group now reads from `MovementCatalog`.
- Compatibility with old `ExerciseCatalog` names is preserved where old data requires it.
- Focused simulator tests pass.
- Roadmap Phase 5 has an honest dated note.

