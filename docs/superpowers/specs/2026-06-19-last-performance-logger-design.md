# Last Performance in the Logger — Design

**Date:** 2026-06-19
**Status:** Approved design, pending implementation plan

## Goal

When logging a workout, show what you actually did **last time** for each set, and
make that last performance the starting/prefill value — so you can see your history
and aim to beat it. The program's recommended ("suggested") value stays visible as
the target.

## Decisions (locked)

1. **Show both, last drives prefill** (Option A): the set's prefill value becomes
   your last performance (falling back to the suggested value); the suggested target
   stays visible as a reference.
2. **All exercises** ("last performance", not just "last weight"): weight × reps for
   loaded lifts; reps for bodyweight; hold-seconds for isometrics.
3. **Per-set matching** (Strong/Hevy style): set 1 ↔ your last set 1, etc., matched
   by `setNumber`. Handle sessions with different set counts.

## Data source

`WorkoutLog` (Supabase collection `workoutLogs`). On completion the app writes both a
`PerformanceLog` and a compatible `WorkoutLog` (`TrainingCompletionService` →
`database.create(workoutLog, collection: "workoutLogs")`). `WorkoutLog` is what
Profile/Rank/Squad already query and carries the needed per-set shape:

- `WorkoutLog.exerciseEntries: [ExerciseLogEntry]` — `exerciseName`, `movementId?`,
  `sets: [SetLog]`, `completedAt`/`startedAt`, `skipped`.
- `SetLog` — `setNumber`, `weightKg?`, `reps`, `durationSeconds?` (holds), `isWarmup`.

## Architecture (3 isolated units)

### 1. `LastPerformanceLookup` (new — pure, testable)
Built once when the active workout opens, from the user's recent completed
`WorkoutLog`s (excluding the current session).

- Input: `[WorkoutLog]` (recent, most-recent-first) + the current session's exercises.
- Builds a map `exerciseKey -> ExerciseLogEntry` = the **most recent prior** non-skipped
  entry per exercise.
- `exerciseKey`: prefer `movementId`; fall back to a normalized `exerciseName`.
- API: `lastSet(forExerciseKey:setNumber:) -> SetLog?` (ignores warmup sets).
- No app/DB dependencies → unit-testable in isolation.

### 2. Display in `SetLogGridRow` (edit existing)
New optional inputs: `lastWeightKg`, `lastReps`, `lastHoldSeconds`/`lastDurationSeconds`,
`lastPerformedAt`.

- **Weight cell** dim value = the prefill = `last ?? suggested`. Because the cell now
  shows *last*, the program's suggested **weight** moves onto the reference line.
- **Metric cell** (reps / hold / duration / distance / calories) is unchanged: its dim
  value stays the planned suggested target (what you aim for); you log actual.
- **New reference line** (dim, under the row), formatted by `metricKind`:

```
Set 1   [ 135 ]   [ 8 ]   [ RPE ]   ◯       ← weight cell prefilled to last; target on the line
        target 140 · last 135 × 8 · 4d ago   ← new dim reference line
```

  - weighted → `target 140 · last 135 × 8 · 4d ago` (drop `target …` when suggested == last or absent)
  - reps     → `last 12 reps · 4d ago`
  - holds    → `last 30s · 4d ago`
  - no prior history for this set → render nothing (no empty line).

### 3. Prefill (edit existing) — weight field only
Where a set's starting weight initializes and where the keypad pre-seeds (currently
`set.weightKg = set.suggestedWeightKg ?? …` in `ActiveWorkoutContainerView+Intents` /
`+Keypad`), prefer last performance:

```
startingWeight = lastSet?.weightKg ?? suggestedWeightKg
```

So "confirm as planned" and the keypad start from your last weight (fallback suggested).
Reps/holds are **not** prefilled from last — their cell keeps the planned target (the
goal); last reps/holds appear only on the reference line. This keeps "last drives
prefill" scoped to the one editable number that benefits from it (load), while bodyweight
movements (no weight) simply gain the reference line.

## Data flow

```
ActiveWorkoutContainerView opens
  → fetch recent WorkoutLogs (services.database query "workoutLogs", user, by completedAt desc, limit N)
  → build LastPerformanceLookup(recentLogs, session.exercises)
  → pass lastSet(...) values down: ExerciseLogCard → SetLogGridRow (display) + into prefill seeding
```

`N` = a small recent window (e.g. last ~40 logs) — enough to cover the exercises in
one session without a heavy fetch.

## Edge cases

- **No history** (first time doing an exercise): no reference line; prefill falls back
  to suggested (current behavior).
- **Different set counts**: last session had 3 sets, today has 4 → set 4 shows no line.
- **Bodyweight / holds**: use `reps` / `durationSeconds`; no weight shown.
- **Warmup sets**: excluded from "last" matching.
- **Skipped entries**: excluded.
- **movementId missing on older logs**: fall back to normalized `exerciseName`.
- **Unit display**: reuse existing `WeightPlatePolicy` formatting + the user's weight unit.

## Out of scope (YAGNI)

- Trend/PR badges, sparkline history, "you beat last time!" celebration.
- Editing/recomputing the program's progression from last performance.
- Multi-session history (only the single most-recent prior performance).

## Testing

Unit tests for `LastPerformanceLookup`:
- movementId match wins over name; name fallback when movementId absent.
- setNumber alignment; missing later sets return nil.
- holds (`durationSeconds`) and bodyweight (`reps`) returned correctly.
- warmup + skipped excluded.
- empty history → nil.

Manual/sim: QA Lab seeded program, log a session, advance day (dev SIM panel), confirm
the next session shows last performance + prefill.

## Files touched (anticipated)

- **New:** `LastPerformanceLookup.swift` (+ test).
- **Edit:** `SetLogGridRow.swift` (display), `ExerciseLogCard.swift` (pass-through),
  `ActiveWorkoutContainerView.swift` / `+Intents` / `+Keypad` (fetch + prefill seeding).
