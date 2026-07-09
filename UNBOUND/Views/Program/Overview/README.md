# Program/Overview

The PROGRAM tab's main surface: week strip + selected-day card + command dock, plus the state machine, resolvers, presenters, and coordinators that decide what each day shows and what the primary action does. The root `ProgramOverviewView` struct itself lives one level up in `UNBOUND/Views/Program/ProgramOverviewView.swift`; the `ProgramOverviewView+*.swift` files here are extensions of it.

## Files

| File | What it is |
|---|---|
| `DayLoadoutPickerSheet.swift` | `DayLoadoutPickerRequest` + `DayLoadoutPickerSheet` — day-side loadout picker: swap one of the user's saved loadouts onto the selected day. |
| `ProgramBlockCompleteView.swift` | `ProgramBlockCompleteView` — compact end-of-block card shown in the day-card slot while the next block builds. |
| `ProgramBlockRolloverCoordinator.swift` | `ProgramBlockRolloverContext` + `ProgramBlockRolloverCoordinator` — logic for rolling a finished block into the next one. |
| `ProgramCommandDock.swift` | `ProgramCommandDock` bottom action dock (Plan + Setup tiles). |
| `ProgramDayActionRow.swift` | `ProgramDayActionRow` — the action row rendered for a day. |
| `ProgramDayPreviewResolver.swift` | `ProgramDayPreviewResolver` — derives day-preview content. |
| `ProgramDayPreviewViews.swift` | Day-preview subviews: `ProgramModifierSummaryRail`, `ProgramWaveAdjustmentPanel`, `ProgramWorkoutExerciseList`. |
| `ProgramDevSimulationViews.swift` | DEBUG-only day simulator / dynamic-scenario rail cards. |
| `ProgramFocusSwitchCoordinator.swift` | `ProgramFocusSwitchCoordinator` — logic for switching program focus. |
| `ProgramMidBlockProposalCard.swift` | `ProgramMidBlockProposalCard` — mid-block change proposal card. |
| `ProgramMonthPlannerView.swift` | `ProgramMonthPlannerView` — the Plan calendar: month grid with per-day split tags (`ProgramPlannerDayInfo`) + day workout picker. |
| `ProgramOverviewChrome.swift` | Screen chrome: top bar, tab selector, loading / no-program / error states, subscription banner, recovery-completion overlay. |
| `ProgramOverviewDayActionResolver.swift` | Pure resolver mapping day input → primary-action state (`ProgramOverviewDayActionInput/State/Resolver`). |
| `ProgramOverviewDayResolver.swift` | `ProgramOverviewDayResolver` (@MainActor) — resolves which day is selected/shown. |
| `ProgramOverviewState.swift` | Value types for the screen: screen/content state, week tiles, day resolution, primary action enums. |
| `ProgramOverviewStateMachine.swift` | `ProgramOverviewStateMachine` + sheet/route/action enums — the screen's navigation state machine. |
| `ProgramOverviewView+ControlsAndFocus.swift` | Extension: controls row + focus handling. |
| `ProgramOverviewView+DevSimulation.swift` | Extension: DEBUG simulation hooks. |
| `ProgramOverviewView+Helpers.swift` | Extension: misc helpers. |
| `ProgramOverviewView+Planning.swift` | Extension: planning (month planner / schedule) glue. |
| `ProgramOverviewView+ProgramTab.swift` | Extension: the PROGRAM tab body composition. |
| `ProgramOverviewView+RefreshAndCheckpoint.swift` | Extension: refresh + checkpoint flow wiring. |
| `ProgramOverviewView+Routines.swift` | Extension: routines tab glue. |
| `ProgramOverviewView+SkillHelpers.swift` | Extension: skill-focus helpers. |
| `ProgramOverviewView+TrainingContext.swift` | Extension: training-context derivation. |
| `ProgramOverviewView+WeekAndDay.swift` | Extension: week strip + day card composition. |
| `ProgramOverviewView+WorkoutRouting.swift` | Extension: routing into workout launch. |
| `ProgramPlanningCoordinator.swift` | `ProgramPlanningCoordinator` (@MainActor) — planning/scheduling coordination logic. |
| `ProgramSelectedDayCard.swift` | `ProgramSelectedDayCard` container + metric model + day badge state. |
| `ProgramSelectedDayPresenter.swift` | `ProgramSelectedDayPresenter` — builds `ProgramSelectedDayPresentation` for the day card. |
| `ProgramSkillFocusResolver.swift` | `ProgramSkillFocusResolver` — resolves the skill focus for the program. |
| `ProgramWeekPresenter.swift` | `ProgramWeekPresenter` — builds `ProgramWeekPresentation` for the week strip. |
| `ProgramWeekStrip.swift` | `ProgramWeekStrip` — the horizontal week tile strip view. |
| `ProgramWorkoutLaunchCoordinator.swift` | `ProgramWorkoutLaunchCoordinator` + `ProgramWorkoutDraftResolver` — turns a day into a launchable workout draft. |

## Where to find X

- **What the START button does for a given day** → `ProgramOverviewDayActionResolver.swift` (state) and `ProgramWorkoutLaunchCoordinator.swift` (launch).
- **Sheet/route navigation for the screen** → `ProgramOverviewStateMachine.swift`.
- **Week strip rendering / which week tile is shown** → `ProgramWeekStrip.swift` + `ProgramWeekPresenter.swift`.
- **Selected-day card content** → `ProgramSelectedDayCard.swift` + `ProgramSelectedDayPresenter.swift` + `ProgramDayPreviewViews.swift`.
- **Loading / empty / error chrome** → `ProgramOverviewChrome.swift`.
- **Block finished → next block** → `ProgramBlockRolloverCoordinator.swift` + `ProgramBlockCompleteView.swift`.
