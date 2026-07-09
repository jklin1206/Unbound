# Models/Routines

Routine ("side quest") model types: routine definitions and their built-in library, the step kinds a routine is made of, the flattened run-time representation, and the completion record persisted when one is finished.

| File | Contents |
| --- | --- |
| `Routine.swift` | `RoutineCategory`, `RoutineDef`, plus tier gating: `RoutineUnlockState` + `RoutineUnlockPolicy`. |
| `RoutineCatalog.swift` | The `RoutineLibrary` enum — built-in catalog of `RoutineDef`s (cardio / mobility / challenge / alt-circuit) plus its difficulty sorting and per-category query helpers. |
| `RoutineCompletionRecord.swift` | `RoutineCompletionRecord` — persisted record of a finished routine; `RoutineMetric` (headline metric: time / rep count / steps), `RoutinePerformanceEntry` + source enum. |
| `RoutineLibrary.swift` | `SideQuestLibrary` — the built-in catalog of `SideQuest` instances (push protocol, core circuit, morning mobility…). |
| `RoutineRun.swift` | `RoutineRunStep` (one concrete step the player walks, circuits expanded, notes filtered) and the `RoutineRun` flattener. |
| `RoutineStep.swift` | Step building blocks: `TimedStyle`, `IntervalSegment`, mobility reference types + `MobilityReferenceLibrary`, `RoutineStepVisualLibrary`. |
| `SideQuest.swift` | The SideQuest data model (Home "Daily Quest" path): `SideQuestCategory`, `SideQuestExercise`, `SideQuest`, `SideQuestLog`, `SideQuestSetLog`. |

## Where to find X

- Add/edit a built-in routine → the `RoutineLibrary` enum in `RoutineCatalog.swift`; routine defs and categories in `Routine.swift`. Built-in side quests → `SideQuestLibrary` in `RoutineLibrary.swift` (note: the `RoutineLibrary` *enum* lives in `RoutineCatalog.swift`, not `RoutineLibrary.swift`).
- Tier gating for routines (locked/unlocked + requirement copy) → `RoutineUnlockPolicy` in `Routine.swift`.
- How a routine is flattened into walkable steps → `RoutineRun.swift`.
- Step kinds, interval segments, mobility visuals → `RoutineStep.swift`.
- What is saved when a routine finishes (headline metric, performance entries) → `RoutineCompletionRecord.swift`.
