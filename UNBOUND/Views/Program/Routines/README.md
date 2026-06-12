# Program/Routines

Side-mission routines tab within the Program screen: browse/challenge cards, preview sheet, completion flow, and supporting UI components. Not to be confused with `Views/Routine/` which owns the step-sequence player.

| File | Purpose |
|------|---------|
| `ProgramRoutineViews.swift` | `ProgramRoutinesTab` — the full routines sub-tab with challenge library section and per-category rows |
| `RoutineChallengeCard.swift` | Challenge routine card with completion gating via `RoutineHistoryStore.canComplete` |
| `RoutinePreviewSheet.swift` | Bottom-sheet preview of a `RoutineDef`: step list and Begin CTA |
| `RoutineCompletionFlow.swift` | Completion flow: starts the player, awards via `WorkoutRewardSequenceSummary` |
| `RoutineTravelOverlay.swift` | Full-screen "in transit" overlay shown while a routine loads |
| `RoutineDifficultyBadge.swift` | Tier-tinted difficulty badge chip used on routine cards |
| `RoutineHelpers.swift` | Free functions `routineStepPreview(_:)` and `routineStepShortLabel(_:)` for formatting step descriptions |

## Where to find X

| Task | File |
|------|------|
| Change how challenge routine cards look | `RoutineChallengeCard.swift` |
| Edit the routine preview sheet content | `RoutinePreviewSheet.swift` |
| Modify the completion / reward wiring | `RoutineCompletionFlow.swift` |
| Adjust step description formatting | `RoutineHelpers.swift` |
| Change the difficulty badge appearance | `RoutineDifficultyBadge.swift` |
