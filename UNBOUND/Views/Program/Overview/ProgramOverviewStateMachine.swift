import Foundation

enum ProgramOverviewSheet {
    case rationale
    case savedWorkouts
    case scheduleEditor
    case focusSwitch
    case checkpoint
    case rescan
}

enum ProgramOverviewRoute {
    case dayDetail(ProgramDay)
    case workoutReady(TrainingSessionDraft)
    case activeWorkout(TrainingSessionDraft)
    case editSession(TrainingSessionDraft)
    case planSession(TrainingSessionDraft)
    case routine(RoutineDef)
    case skillDetail(nodeId: String)
}

enum ProgramOverviewAction {
    case appeared
    case refreshStarted
    case refreshFinished
    case programLoaded(ProgramOverviewContentState)
    case programMissing
    case programFailed(String)
    case selectDate(Date)
    case resolveSelectedDay(ProgramDay?, ProgramOverviewDayResolution, ProgramOverviewPrimaryAction)
    case loadWeek([ProgramOverviewWeekTile])
    case setSheet(ProgramOverviewSheet?)
    case setRoute(ProgramOverviewRoute?)
}

struct ProgramOverviewTransition {
    var shouldRefresh: Bool = false
}

struct ProgramOverviewStateMachine {
    private(set) var state: ProgramOverviewScreenState
    private let calendar: Calendar

    init(
        initialDate: Date,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.state = .ready(
            ProgramOverviewContentState(selectedDate: calendar.startOfDay(for: initialDate))
        )
    }

    mutating func send(_ action: ProgramOverviewAction) -> ProgramOverviewTransition {
        switch action {
        case .appeared:
            state = .loading
            return ProgramOverviewTransition(shouldRefresh: true)

        case .refreshStarted:
            updateContent { $0.isRefreshing = true }
            return ProgramOverviewTransition()

        case .refreshFinished:
            updateContent { $0.isRefreshing = false }
            return ProgramOverviewTransition()

        case .programLoaded(let content):
            state = .ready(content)
            return ProgramOverviewTransition()

        case .programMissing:
            state = .noProgram
            return ProgramOverviewTransition()

        case .programFailed(let message):
            state = .failed(message)
            return ProgramOverviewTransition()

        case .selectDate(let date):
            let selectedDate = calendar.startOfDay(for: date)
            updateContent { $0.selectedDate = selectedDate }
            return ProgramOverviewTransition()

        case .resolveSelectedDay(let day, let resolution, let primaryAction):
            updateContent {
                $0.selectedDay = day
                $0.selectedResolution = resolution
                $0.primaryAction = primaryAction
            }
            return ProgramOverviewTransition()

        case .loadWeek(let week):
            updateContent { $0.week = week }
            return ProgramOverviewTransition()

        case .setSheet(let sheet):
            updateContent { $0.activeSheet = sheet }
            return ProgramOverviewTransition()

        case .setRoute(let route):
            updateContent { $0.activeRoute = route }
            return ProgramOverviewTransition()
        }
    }

    private mutating func updateContent(_ mutate: (inout ProgramOverviewContentState) -> Void) {
        guard case .ready(var content) = state else { return }
        mutate(&content)
        state = .ready(content)
    }
}
