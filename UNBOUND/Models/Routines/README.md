# Models/Routines

Routine ("side quest") model types: routine definitions and their built-in library, the step kinds a routine is made of, the flattened run-time representation, and the completion record persisted when one is finished.

| File | Contents |
| --- | --- |
| `Routine.swift` | `RoutineCategory`, `RoutineDef`, the `RoutineLibrary` enum (routine definitions), plus the SideQuest data model: `SideQuestCategory`, `SideQuestExercise`, `SideQuest`, `SideQuestLog`, `SideQuestSetLog`. |
| `RoutineCompletionRecord.swift` | `RoutineCompletionRecord` — persisted record of a finished routine; `RoutineMetric` (headline metric: time / rep count / steps), `RoutinePerformanceEntry` + source enum. |
| `RoutineLibrary.swift` | `SideQuestLibrary` — the built-in catalog of `SideQuest` instances (push protocol, core circuit, morning mobility…). |
| `RoutineRun.swift` | `RoutineRunStep` (one concrete step the player walks, circuits expanded, notes filtered) and the `RoutineRun` flattener. |
| `RoutineStep.swift` | Step building blocks: `TimedStyle`, `IntervalSegment`, mobility reference types + `MobilityReferenceLibrary`, `RoutineStepVisualLibrary`. |

## Where to find X

- Add/edit a built-in routine → `SideQuestLibrary` in `RoutineLibrary.swift`; routine defs and categories in `Routine.swift` (note: the `RoutineLibrary` *enum* lives in `Routine.swift`, not `RoutineLibrary.swift`).
- How a routine is flattened into walkable steps → `RoutineRun.swift`.
- Step kinds, interval segments, mobility visuals → `RoutineStep.swift`.
- What is saved when a routine finishes (headline metric, performance entries) → `RoutineCompletionRecord.swift`.
