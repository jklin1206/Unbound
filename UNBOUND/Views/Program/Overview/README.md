# Program/Overview

The main Program tab surface: week-strip calendar, selected-day card, training-context controls, and all sheet/routing coordination for launching workouts, switching focus, planning, and block rollover.

| File | Purpose |
|------|---------|
| `ProgramOverviewState.swift` | State types: `ProgramOverviewScreenState`, `ProgramOverviewContentState`, sheet/route/action enums |
| `ProgramOverviewStateMachine.swift` | Enums `ProgramOverviewSheet`, `ProgramOverviewRoute`, `ProgramOverviewAction` driving the overview FSM |
| `ProgramOverviewView+ProgramTab.swift` | Root `programTab` body — dispatches on `ProgramSurfaceState` to loading/error/blockComplete/ready layouts |
| `ProgramOverviewView+WeekAndDay.swift` | Week-strip + selected-day card rendering |
| `ProgramOverviewView+ControlsAndFocus.swift` | Training-context chip row and focus-override affordances |
| `ProgramOverviewView+WorkoutRouting.swift` | Navigation to `WorkoutReady`, `ActiveWorkout`, `SessionEditor`, `DayDetail` |
| `ProgramOverviewView+Planning.swift` | Saved-workout scheduling sheet wiring |
| `ProgramOverviewView+Routines.swift` | Routines tab embed and routing |
| `ProgramOverviewView+SkillHelpers.swift` | Skill-node context helpers used by the day card |
| `ProgramOverviewView+TrainingContext.swift` | Training-context override resolution |
| `ProgramOverviewView+RefreshAndCheckpoint.swift` | Pull-to-refresh and checkpoint sheet logic |
| `ProgramOverviewView+Helpers.swift` | Shared formatting/utility helpers for the overview |
| `ProgramOverviewView+DevSimulation.swift` | DEBUG-only dev-simulation controls wiring |
| `ProgramOverviewChrome.swift` | Top-level chrome wrapper (nav bar, empty/loading/error states) |
| `ProgramWeekStrip.swift` | Horizontal week tile strip with prev/next navigation |
| `ProgramWeekPresenter.swift` | Converts `ProgramDay` array to `ProgramWeekStripTile` display models |
| `ProgramSelectedDayCard.swift` | Composite card: header label, title, badge, hero tint, metrics, skill nodes |
| `ProgramSelectedDayPresenter.swift` | Maps selected `ProgramDay` + draft to `ProgramSelectedDayCard` inputs |
| `ProgramDayPreviewViews.swift` | Exercise-preview rows inside the day card |
| `ProgramDayPreviewResolver.swift` | Resolves a preview `Workout` from a `ProgramDay` and optional draft |
| `ProgramDayActionRow.swift` | Primary CTA row below the day card (Begin / Quick Log / etc.) |
| `ProgramCommandDock.swift` | Setup-tile row (style, equipment, context overrides) |
| `ProgramOverviewDayResolver.swift` | Determines the `ProgramOverviewDayResolution` for a given date |
| `ProgramOverviewDayActionResolver.swift` | Picks the correct `ProgramOverviewPrimaryAction` for a resolved day |
| `ProgramSkillFocusResolver.swift` | Resolves which skill nodes are relevant for the current day |
| `ProgramFocusSwitchCoordinator.swift` | Logic for computing the effective training style and equipment override |
| `ProgramWorkoutLaunchCoordinator.swift` | Decides whether a tap routes to `DayDetail` or a `TrainingSessionDraft` |
| `ProgramPlanningCoordinator.swift` | Applies saved workouts to program days or schedule occurrences |
| `ProgramBlockRolloverCoordinator.swift` | Loads block-rollover context and proposals for end-of-block state |
| `ProgramBlockCompleteView.swift` | Full block-complete surface: arc summary, delta report, next-block CTA |
| `ProgramMidBlockProposalCard.swift` | Inline card offering a mid-block program adjustment proposal |
| `ProgramDevSimulationViews.swift` | DEBUG-only scenario controls for simulating arc/wave states |

## Where to find X

| Task | File |
|------|------|
| Change what happens when the user taps "Begin Workout" | `ProgramWorkoutLaunchCoordinator.swift` + `ProgramOverviewView+WorkoutRouting.swift` |
| Modify the week strip tile appearance or navigation | `ProgramWeekStrip.swift` + `ProgramWeekPresenter.swift` |
| Add or adjust the training-context override flow | `ProgramFocusSwitchCoordinator.swift` + `ProgramOverviewView+ControlsAndFocus.swift` |
| Edit the end-of-block summary screen | `ProgramBlockCompleteView.swift` + `ProgramBlockRolloverCoordinator.swift` |
| Understand day state (rest / training / missing / loading) | `ProgramOverviewState.swift` + `ProgramOverviewDayResolver.swift` |
| Adjust the primary CTA label or logic | `ProgramOverviewDayActionResolver.swift` + `ProgramDayActionRow.swift` |
