# Program/Routines

The ROUTINES sub-tab of the Program screen: a carousel of routine challenge cards plus the completion flow and small supporting pieces (badges, dots, press style, travel overlay). The routine *players* themselves live in `UNBOUND/Views/Routine/`.

## Files

| File | What it is |
|---|---|
| `ProgramRoutinesTab.swift` | `ProgramRoutinesTab` — the sub-tab's root view. |
| `RoutineChallengeCard.swift` | `RoutineChallengeCard` — one card in the routine challenge carousel. |
| `RoutineChallengeDots.swift` | `RoutineChallengeDots` — carousel page-dot indicator. |
| `RoutineChallengePressStyle.swift` | `RoutineChallengePressStyle` — ButtonStyle for card presses. |
| `RoutineCompletionFlow.swift` | `RoutineCompletionFlow` — post-routine completion sequence. |
| `RoutineDifficultyBadge.swift` | `RoutineDifficultyBadge` — difficulty label badge. |
| `RoutinePreviewSheet.swift` | `private struct RoutinePreviewSheet` — routine preview sheet (file-private; no external references found). |
| `RoutineTravelOverlay.swift` | `RoutineTravelOverlay` — travel-mode overlay. |
| `RoutineViewHelpers.swift` | `RoutineDef` extension — step-preview helpers for routine views. |

## Where to find X

- **The routines tab layout** → `ProgramRoutinesTab.swift`.
- **Card visuals in the carousel** → `RoutineChallengeCard.swift` (+ dots / press style / difficulty badge files).
- **What happens when a routine finishes** → `RoutineCompletionFlow.swift`.
- **Actually playing a routine** → `UNBOUND/Views/Routine/RoutineSequencePlayer.swift` (not in this folder).
