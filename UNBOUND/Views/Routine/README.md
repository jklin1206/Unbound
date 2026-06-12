# Views/Routine

Standalone routine players (side-quest workouts and pre-set step-sequence routines) plus their exercise reference cards. The Routines *browsing tab* lives in `UNBOUND/Views/Program/Routines/`.

Naming caution: the type names and file names are crossed — `RoutinePlayerView.swift` declares `SideQuestPlayerView`, while `RoutineSequencePlayer.swift` declares `RoutinePlayerView`.

## Files

| File | What it is |
|---|---|
| `RoutinePlayerView.swift` | `SideQuestPlayerView` — full-screen side-quest player with a two-stage loop: exercising (set counter, dots, cue, rep stepper, LOG SET) → full-screen rest ring → repeat. |
| `RoutineSequencePlayer.swift` | `RoutinePlayerView` — step-sequence player for pre-set routines; no set logging; faces: instruction / timed / interval / repTarget / complete. |
| `RoutineSequencePlayer+Drive.swift` | Extension: step advancement, timers, and performance capture for the sequence player. |
| `RoutineReferenceCards.swift` | `RoutineExerciseVisualCard` + `MobilityReferenceCard` — visual reference cards shown during play. |

## Where to find X

- **Timed-step / interval advancement logic** → `RoutineSequencePlayer+Drive.swift`.
- **Set logging during a side quest** → `RoutinePlayerView.swift` (`SideQuestPlayerView`).
- **Exercise demo visuals in players** → `RoutineReferenceCards.swift`.
- **Picking which routine to play** → `UNBOUND/Views/Program/Routines/ProgramRoutinesTab.swift`.
