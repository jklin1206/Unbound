# SkillSession

Full-screen modal session logger surfaced from `SkillDetailView`'s TRAIN button — loads an AI-generated training plan for a skill, lets the user log sets per slot, and drives the finish/reward flow via `TrainingCompletionService`.

| File | Contents |
|---|---|
| `SkillSessionView.swift` | Struct declaration, stored properties, inits, computed helpers (`mainExercises`, `loggedCount`, `canFinish`), `body`, `sessionBody`, `header`, `aiBadge` |
| `SkillSessionView+WorkoutRows.swift` | Today's workout list (`todaysWorkList`, `workoutRow`, `slotsRow`, `slotChip`), logged-set summary helpers, weight formatting, accessories disclosure (`accessoriesDisclosure`, `helperRow`) |
| `SkillSessionView+FinishFlow.swift` | Loading state, summary card, generic fallback, finish bar, `finish()` async flow, `computeXP()` |
| `SkillSessionView+Helpers.swift` | Prescription lookup, `loadSession`, timer start/stop, elapsed formatter, `roundedCard` styling |
