import Foundation

/// Pure helpers for determining where we are in the current generated program.
///
/// Used by the home UI to show "days remaining" and by the rollover flow
/// to detect when to prompt a Checkpoint / generate the next Arc. Normal
/// Arcs are 28 days; first-run Calibration Week stays 7 days.
///
/// This scheduler does only one thing: map the active arc start date to the
/// current day number. Legacy programs without arcs still use `program.createdAt`.
enum BlockRolloverScheduler {

    /// True if the current program has run its full declared duration.
    static func shouldRollover(program: TrainingProgram, now: Date = Date()) -> Bool {
        daysRemaining(program: program, now: now) == 0
    }

    /// Days left in the current Arc or Calibration Week, clamped to [0, durationDays].
    static func daysRemaining(program: TrainingProgram, now: Date = Date()) -> Int {
        let elapsedDays = Int(now.timeIntervalSince(activeStartDate(for: program)) / 86400)
        let remaining = activeDurationDays(for: program) - elapsedDays
        return max(0, remaining)
    }

    /// 1-indexed current day within the Arc or Calibration Week, clamped to [1, durationDays].
    static func currentDayNumber(program: TrainingProgram, now: Date = Date()) -> Int {
        let elapsedDays = Int(now.timeIntervalSince(activeStartDate(for: program)) / 86400)
        let dayNumber = elapsedDays + 1
        return min(activeDurationDays(for: program), max(1, dayNumber))
    }

    static func activeStartDate(for program: TrainingProgram) -> Date {
        program.currentArc?.startDate ?? program.createdAt
    }

    private static func activeDurationDays(for program: TrainingProgram) -> Int {
        program.currentArc == nil ? program.durationDays : Arc.durationDays
    }
}

#if DEBUG
enum DevProgramClock {
    private static let dayOffsetKey = "unbound.devProgram.dayOffset"

    static var dayOffset: Int {
        UserDefaults.standard.integer(forKey: dayOffsetKey)
    }

    static var today: Date {
        today(offset: dayOffset)
    }

    static var now: Date {
        now(offset: dayOffset)
    }

    static var isSimulating: Bool {
        dayOffset != 0
    }

    static func today(offset: Int) -> Date {
        Calendar.current.startOfDay(for: now(offset: offset))
    }

    static func now(offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    }

    @discardableResult
    static func advance(days: Int) -> Int {
        setDayOffset(dayOffset + days)
    }

    @discardableResult
    static func reset() -> Int {
        setDayOffset(0)
    }

    @discardableResult
    static func setDayOffset(_ offset: Int) -> Int {
        UserDefaults.standard.set(offset, forKey: dayOffsetKey)
        return offset
    }
}
#endif
