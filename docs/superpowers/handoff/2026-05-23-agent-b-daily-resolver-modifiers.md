# Agent B Handoff: Daily Resolver Modifiers

**Base branch:** `origin/codex/progression-overall-rank-trials`  
**Work branch:** `codex/progression-daily-resolver-modifiers`  
**Model:** GPT-5.5, extra high reasoning  
**Roadmap lane:** Phase 8  
**Simulator lane:** iPhone 16e, iOS 26.3, `280AE372-B5CE-4700-8108-A0666B407CC8`  
**Primary goal:** Expand `DailyWorkoutResolver` from scheduled-skill tapering into deterministic daily modifiers for travel/equipment, deload, trial prep, and user movement constraints.

## Coordination Rules

You are not alone in the codebase. Other agents may be editing catalog, trial, and cleanup files in parallel. Do not revert edits you did not make. Keep your branch focused.

Agents should not work on one shared branch. Start from `origin/codex/progression-overall-rank-trials`, make this branch, and let the coordinator merge.

## Own

- `UNBOUND/Services/ProgramGeneration/DailyWorkoutResolver.swift`
- `UNBOUND/Services/ProgramGeneration/ProgramScheduler.swift` only if scheduling support is needed
- small model/helper types colocated with the resolver if they keep the API clean
- `UNBOUNDTests/Services/ProgramGeneration/DailyWorkoutResolverTests.swift`
- narrow adapter tests only if draft output changes

## Avoid

- Editing `MovementCatalog.swift` unless a tiny missing read helper is unavoidable. Prefer using existing metadata.
- Overall Rank trial definitions and trial runner behavior.
- Weekly Vow completion logic.
- Legacy deletion/quarantine work.
- UI redesigns.

## Implementation Target

Keep generated monthly plans stable, but let today's draft adapt through deterministic modifiers.

Implement a focused V1 context, for example:

```swift
struct DailyWorkoutModifierContext {
    var availableEquipment: Set<MovementEquipment>?
    var deloadFactor: Double?
    var trialPrepMovementIds: [String]
    var avoidedMovementIds: Set<String>
}
```

The exact shape can differ if the local code suggests a better pattern. The important part is that normal cases do not require AI or program regeneration.

Prioritized behavior:

1. Equipment/travel mode substitutes incompatible exercises using `MovementCatalog` same-slot alternatives.
2. Deload lowers sets/intensity cleanly without removing the session identity.
3. Trial prep can add or bias a missing requirement block without wrecking the base plan.
4. Avoided/unavailable movements are swapped if a compatible same-slot alternative exists.
5. Scheduled skill tapering continues to work exactly as before.

## Tests

Use XcodeBuildMCP, not raw `xcodebuild`.

Before any build/test/run:

```text
Call session_show_defaults.
Confirm projectPath = /Users/jlin/Documents/toji/UNBOUND/UNBOUND.xcodeproj
Confirm scheme = UNBOUND
Set or confirm simulator = iPhone 16e / 280AE372-B5CE-4700-8108-A0666B407CC8
```

Focused tests to add/update:

- Add pull-up or handstand skill mid-month inserts skill work and keeps the base plan stable.
- Dumbbells-only travel mode substitutes incompatible gym movements.
- Deload reduces volume/intensity and adds an explanatory note.
- Trial prep nudges toward a missing standard.
- Avoided movement swaps to a same-slot compatible alternative.
- Existing scheduled-skill removal/preservation tests still pass.

Simulator proof:

- Build/run on iPhone 16e.
- Open Program, route to Workout Ready with at least one modifier active.
- Verify Workout Ready shows substituted/tapered/added blocks and still starts.
- Screenshot Workout Ready and, if you complete it, the unified receipt.

## Done Means

- `DailyWorkoutResolver` accepts a deterministic modifier context or equivalent.
- At least two new modifier classes are implemented and tested, with equipment/travel preferred as one.
- Existing scheduled skill behavior remains green.
- Roadmap Phase 8 has a dated note with implemented modifiers and remaining gaps.

