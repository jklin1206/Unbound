# Agent A Handoff: MovementCatalog Caller Migration

**Source roadmap:** `docs/superpowers/handoff/2026-05-21-unified-workout-progression-migration-roadmap.md`  
**Roadmap lane:** Phase 5, with light Phase 8 support  
**Branch:** `codex/progression-movementcatalog-migration`  
**Simulator lane:** iPhone 16e, iOS 26.3, simulator id `280AE372-B5CE-4700-8108-A0666B407CC8`  
**Primary goal:** Make `MovementCatalog` the source of truth for program generation, substitutions, logging defaults, AP/rank rollups, attributes, and body regions wherever this can be done without redesigning UI.

## Start Here

You are one of three parallel agents. Work only this lane. Do not rename Weekly Trials, do not build Overall Rank trials, and do not redesign Workout Ready or rewards unless a tiny compatibility fix is required by this lane.

Before editing, make this an explicit goal in the roadmap:

- Add a short dated note under Phase 5 saying this branch is migrating callers from legacy `ExerciseCatalog` / ad hoc exercise metadata to `MovementCatalog`.
- Keep the roadmap honest: mark only the caller groups you actually migrate and prove.

## Why This Lane Exists

The progression roadmap says `MovementCatalog` is partial: validation tests pass, but callers still need replacement. The app is only truly unified when program generation, substitutions, logging, AP, ranks, attributes, body map, and trials all read movement metadata from one source.

## Ownership

Own these areas:

- `UNBOUND/Models/MovementCatalog.swift`
- movement proof / movement resolution models such as `MovementProofMatcher`
- program generation and resolver callers that select or substitute exercises
- training adapters that resolve logger/default metrics from movement metadata
- movement/rank/body/attribute services that still use duplicated exercise metadata
- focused tests under `UNBOUNDTests` for movement catalog validation and migrated callers

Avoid these areas unless absolutely required:

- `UNBOUND/Services/Trials/*` weekly trial/vow naming
- trial readiness / overall rank gate models
- major SwiftUI redesigns
- unrelated dirty or untracked files

## Implementation Shape

1. Inventory callers:
   - Search for `ExerciseCatalog`, `.legacyExercises`, hard-coded exercise slot/category maps, string-based movement matching, and direct movement-name ranking logic.
   - Split findings into caller groups: program generation, settings/preferences, training adapters/logging, movement progression/rank/body map.

2. Migrate a narrow but meaningful slice:
   - Prefer replacing callers with `MovementCatalog.definition(for:)`, resolved standards, logger mode, default metric, attribute weights, and body regions.
   - Keep compatibility shims only where old saved logs still require them.
   - Do not delete old APIs until no caller needs them.

3. Add regression coverage:
   - Program generator never picks a push movement for a pull slot.
   - Variant chains resolve deterministically to a ranked standard.
   - Logger defaults come from `MovementCatalog`.
   - Attribute/body metadata is not dropped for migrated completions.

4. Update the roadmap with exactly what changed and what remains.

## Testing Requirements

Use XcodeBuildMCP, not raw `xcodebuild`, for simulator testing.

First action for simulator work:

```text
Call session_show_defaults. Confirm:
projectPath = /Users/jlin/Documents/toji/UNBOUND/UNBOUND.xcodeproj
scheme = UNBOUND
configuration = Debug
simulator = iPhone 16e
bundleId = com.unboundapp.ios
```

Focused tests to run or adapt:

- `MovementCatalog` validation / final-state query tests
- `DailyWorkoutResolverTests`
- adapter tests that cover `TrainingSessionDraft -> PerformanceLog`
- movement/rank/body/attribute progression tests touched by the migration

Simulator proof:

- Build/run on iPhone 16e.
- Open Program with the existing debug route if useful: `--unbound-open-program`.
- Start a Program Workout Ready path with generated strength work.
- Verify selected movements, logger defaults, and resulting receipt still behave normally.
- Capture at least one screenshot of Program/Workout Ready and one reward or receipt screen if the lane reaches completion UI.

## Acceptance Criteria

- At least one major caller group no longer depends on legacy exercise metadata.
- New or updated tests prove catalog identity, logger metadata, rank standard, attribute weights, and body regions survive the migrated path.
- Existing Program -> Workout Ready -> Active Workout path still builds and runs on the assigned simulator.
- Roadmap Phase 5 is updated with completed and remaining caller groups.

## Branch / Merge Guidance

Work on `codex/progression-movementcatalog-migration`, not the same branch as the other agents. This branch should merge before trial-readiness work depends deeply on catalog metadata. If another branch changes touched call sites, preserve both contracts and keep `MovementCatalog` as the final source of truth.
