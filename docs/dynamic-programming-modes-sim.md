# Dynamic Programming Modes Sim

This branch adds a first production slice for dynamic training setup:

- Generated modes: Calisthenics, Lifting, Hybrid, Machines.
- Manual mode: Freeform opens the planner and does not regenerate the block.
- Temporary scopes: Today and This Week resolve the current block through daily equipment/style modifiers instead of rebuilding it.
- Pending scope: Next Block queues the chosen setup for rollover generation and clears after it is consumed.
- User-owned workouts: scheduled saved/freeform workouts persist the exact `TrainingSessionDraft` and are protected from daily modifiers, wave adjustments, and arc rollover load bias.
- Clear controls: the focus sheet exposes active Today/Week overrides and queued Next Block records separately, so clearing one does not wipe the other.
- Dev scenarios: DEBUG Dev Player Tools can seed dynamic programming states without re-running onboarding.

## Manual App Flows

1. Program -> Training Setup -> Change Setup.
2. Pick Calisthenics, Lifting, Hybrid, or Machines.
3. Select the literal equipment available.
4. For Calisthenics/Hybrid, pick ability level.
5. Pick the scope:
   - Today: applies only to the selected day.
   - Week: applies through the current calendar week.
   - Next Block: queues the next block without changing this one.
   - Active Block: rebuilds now and updates the profile setup.
6. Tap Apply Today, Apply Week, Queue Next Block, or Rebuild Block.
7. Reopen Change Setup. If a Today/Week override or Next Block queue exists, use Clear/Cancel from the Active rail.

Freeform:

1. Program -> Training Setup -> Change Setup.
2. Pick Freeform.
3. Tap Open Freeform.
4. Build the workout, save it, and schedule it.
5. Reopen the scheduled day from Program or Home. It should launch from the exact saved draft.

## One-Tap Dev Scenarios

Open Settings -> Dev Player Tools -> Program + Scan Sandbox:

- Dynamic: 1 Skill + Lifting
- Dynamic: 6 Skills + Hybrid
- Dynamic: Week Bands Calis
- Dynamic: Next Block Lifting
- Dynamic: Freeform Protected

Launch directly into Program with a seeded scenario:

```zsh
xcrun simctl launch 810087B3-226D-4398-8ABD-9FF61E642E1D com.unboundapp.ios \
  --unbound-open-program \
  --unbound-dev-dynamic-program calis-week-bands
```

Valid scenario args: `one-skill-lifting`, `six-skill-hybrid`, `calis-week-bands`, `next-block-lifting`, `freeform-protected`.

## Focused Test Command

```zsh
cd /Users/jlin/Documents/toji/UNBOUND
xcodebuild test \
  -project UNBOUND.xcodeproj \
  -scheme UNBOUND \
  -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' \
  -derivedDataPath .derivedData-dynamic-modes \
  -test-timeouts-enabled NO \
  -only-testing:UNBOUNDTests/SplitLookupTests \
  -only-testing:UNBOUNDTests/ProgramTrainingContextStoreTests \
  -only-testing:UNBOUNDTests/SavedWorkoutSchedulerTests \
  -only-testing:UNBOUNDTests/ArcGeneratorTests \
  -only-testing:UNBOUNDTests/WaveAdjusterTests \
  -only-testing:UNBOUNDTests/DailyWorkoutResolverTests
```

Expected result: 47 tests pass.

## Broader QA Ideas

- Switch from full-gym lifting to calisthenics with pull-up bar only; verify no barbell/machine exercises in the rebuilt block.
- Switch back to lifting with barbell/dumbbells/bench; verify calisthenics-only equipment does not leak into the resolved lifting context.
- Switch to Week + calisthenics/bands; verify the Program card tile changes to `WEEK`, visible exercise rows substitute gym work, and the base block stays intact.
- Queue Next Block + lifting; verify the setup tile changes to `NEXT`, the current block stays unchanged, then rollover generation uses the queued setup.
- Open Change Setup with both a Week override and a Next Block queue; verify Clear and Cancel appear as separate actions.
- Build a freeform workout with strength, cardio, and carry blocks; schedule it; verify the scheduled day keeps all block kinds.
- Trigger wave 2, active-block rebuild, or next arc; verify scheduled freeform/saved days remain user-owned.

## Current Boundary

This slice wires active-block rebuilds, freeform/manual protection, local temporary context persistence, daily modifier resolution, and pending next-block rollover input. The remaining product decision is whether a consumed Next Block queue should also become the user's new ongoing profile preference after rollover, or stay a one-block override.
