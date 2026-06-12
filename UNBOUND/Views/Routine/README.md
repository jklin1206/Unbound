# Views/Routine

Step-sequence routine player for pre-set `RoutineDef` routines. Advances through instruction/timed/interval/repTarget steps without set logging; records a `RoutineCompletionRecord` on finish. Not to be confused with `Views/Program/Routines/` which owns the browse/challenge UI.

| File | Purpose |
|------|---------|
| `RoutinePlayerView.swift` | `RoutinePlayerView` — full-screen step player: current step display, timed reference, step advance, completion record on finish |
| `RoutineSequencePlayer.swift` | `SideQuestPlayerView` — side-quest flavored player: exercise + rest-timer loop, set counter, LOG SET button, completion summary |
| `RoutineSequencePlayer+Cards.swift` | `RoutineExerciseVisualCard` — exercise visual card used inside the sequence player |

## Where to find X

| Task | File |
|------|------|
| Change how a routine step advances or displays | `RoutinePlayerView.swift` |
| Modify the side-quest rest-timer or set-log flow | `RoutineSequencePlayer.swift` |
| Edit the exercise visual card inside the player | `RoutineSequencePlayer+Cards.swift` |
