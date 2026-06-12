## Models/Routines

Side-quest routines (cardio, mobility, challenge circuits): the library of available routines, their step definitions, and the runtime/completion records that track a user's progress through them.

| File | Purpose |
|------|---------|
| `Routine.swift` | `RoutineCategory` enum and `SideQuest` (alias Routine) struct — category, steps, and display metadata for one routine |
| `RoutineStep.swift` | `RoutineStep` — individual segment types (timed interval, rep target, checklist, circuit, note) with `TimedStyle` (work/rest) |
| `RoutineLibrary.swift` | `SideQuestLibrary` — static catalog of all built-in routines (push protocol, pull protocol, mobility flows, etc.) |
| `RoutineRun.swift` | `RoutineRunStep` — the flattened, player-facing step list for an active routine execution (circuits expanded, notes filtered) |
| `RoutineCompletionRecord.swift` | Completion record — headline metric (time, rep count, or steps done/total), elapsed seconds, and per-routine history |

### Where to find X

- **Add a new built-in routine** → `RoutineLibrary.swift` (add to `SideQuestLibrary.all`) + `Routine.swift` (if a new category is needed)
- **Add a new step type** → `RoutineStep.swift`
- **Change what headline metric a routine reports** → `RoutineCompletionRecord.swift`
- **Understand how circuits are expanded at runtime** → `RoutineRun.swift`
