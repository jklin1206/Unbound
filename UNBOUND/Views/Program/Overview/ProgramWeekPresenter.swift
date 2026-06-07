import Foundation

struct ProgramWeekPresentation {
    let rangeLabel: String
    let tiles: [ProgramWeekStripTile]
}

@MainActor
struct ProgramWeekPresenter {
    let today: Date
    let selectedDate: Date
    let weekOffset: Int
    let dayResolver: ProgramOverviewDayResolver
    let calendar: Calendar

    init(
        today: Date,
        selectedDate: Date,
        weekOffset: Int,
        dayResolver: ProgramOverviewDayResolver,
        calendar: Calendar = .current
    ) {
        self.today = calendar.startOfDay(for: today)
        self.selectedDate = calendar.startOfDay(for: selectedDate)
        self.weekOffset = weekOffset
        self.dayResolver = dayResolver
        self.calendar = calendar
    }

    var weekStart: Date {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        let components = weekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let base = weekCalendar.date(from: components) ?? today
        return weekCalendar.date(byAdding: .day, value: weekOffset * 7, to: base) ?? base
    }

    func dates() -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    func presentation(
        for program: TrainingProgram,
        isCompleted: (ProgramDay) -> Bool
    ) -> ProgramWeekPresentation {
        let dates = dates()
        let tiles = dates.map { date in
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let isPast = date < today && !isToday
            let day = dayResolver.day(for: date, in: program)
            return ProgramWeekStripTile(
                date: date,
                status: Self.status(
                    for: day,
                    isToday: isToday,
                    isPast: isPast,
                    isCompleted: day.map(isCompleted) ?? false
                ),
                isSelected: calendar.isDate(selectedDate, inSameDayAs: date),
                isToday: isToday,
                calendar: calendar
            )
        }

        return ProgramWeekPresentation(
            rangeLabel: Self.rangeLabel(from: dates.first ?? today, to: dates.last ?? today),
            tiles: tiles
        )
    }

    static func status(
        for day: ProgramDay?,
        isToday: Bool,
        isPast: Bool,
        isCompleted: Bool
    ) -> ProgramWeekTileStatus {
        if day?.isRestDay == true { return .rest }
        if isCompleted { return .completed }
        if isToday { return .today }
        if isPast { return .locked }
        return .planned
    }

    static func rangeLabel(from startDate: Date, to endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startDate).uppercased()) - \(formatter.string(from: endDate).uppercased())"
    }
}
