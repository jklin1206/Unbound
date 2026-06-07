import Foundation

enum ProgramOverviewScreenState {
    case loading
    case noProgram
    case failed(String)
    case ready(ProgramOverviewContentState)
}

struct ProgramOverviewContentState {
    var selectedDate: Date
    var selectedDay: ProgramDay?
    var selectedResolution: ProgramOverviewDayResolution
    var week: [ProgramOverviewWeekTile]
    var primaryAction: ProgramOverviewPrimaryAction
    var activeSheet: ProgramOverviewSheet?
    var activeRoute: ProgramOverviewRoute?
    var isRefreshing: Bool

    init(
        selectedDate: Date,
        selectedDay: ProgramDay? = nil,
        selectedResolution: ProgramOverviewDayResolution = .unavailable,
        week: [ProgramOverviewWeekTile] = [],
        primaryAction: ProgramOverviewPrimaryAction = .none,
        activeSheet: ProgramOverviewSheet? = nil,
        activeRoute: ProgramOverviewRoute? = nil,
        isRefreshing: Bool = false
    ) {
        self.selectedDate = selectedDate
        self.selectedDay = selectedDay
        self.selectedResolution = selectedResolution
        self.week = week
        self.primaryAction = primaryAction
        self.activeSheet = activeSheet
        self.activeRoute = activeRoute
        self.isRefreshing = isRefreshing
    }
}

struct ProgramOverviewWeekTile: Identifiable {
    let id: String
    var date: Date
    var day: ProgramDay?
    var resolution: ProgramOverviewDayResolution
    var isToday: Bool
    var isPast: Bool
    var isCompleted: Bool

    init(
        date: Date,
        day: ProgramDay? = nil,
        resolution: ProgramOverviewDayResolution = .unavailable,
        isToday: Bool = false,
        isPast: Bool = false,
        isCompleted: Bool = false,
        calendar: Calendar = .current
    ) {
        self.date = date
        self.day = day
        self.resolution = resolution
        self.isToday = isToday
        self.isPast = isPast
        self.isCompleted = isCompleted
        self.id = Self.id(for: date, calendar: calendar)
    }

    private static func id(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }
}

struct ProgramWeekStripTile: Identifiable {
    let id: String
    var date: Date
    var status: ProgramWeekTileStatus
    var isSelected: Bool
    var isToday: Bool

    init(
        date: Date,
        status: ProgramWeekTileStatus,
        isSelected: Bool,
        isToday: Bool,
        calendar: Calendar = .current
    ) {
        self.date = date
        self.status = status
        self.isSelected = isSelected
        self.isToday = isToday

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.id = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

enum ProgramWeekTileStatus {
    case completed
    case today
    case rest
    case planned
    case locked
}

enum ProgramOverviewDayResolution {
    case generatedProgram
    case plannedWorkout
    case savedWorkout
    case customBuild
    case extraSession
    case emptySession
    case recovery
    case rest
    case unavailable
}

enum ProgramOverviewPrimaryAction {
    case loadWorkout
    case editWorkout
    case viewDetails
    case reviewAndStart
    case resumeWorkout
    case addSession
    case viewLog
    case completeRecovery
    case buildWorkout
    case none
}
