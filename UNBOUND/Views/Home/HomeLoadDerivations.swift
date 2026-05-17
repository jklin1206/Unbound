import Foundation

/// Pure, dependency-free derivations from a single recent-logs fetch.
/// Exists so the Home load can dedupe three `workout_logs` fetches into one
/// and still be unit-tested. The week logic is lifted verbatim from the
/// original `refreshWeeklyRhythm`.
enum HomeLoadDerivations {

    static func lastLog(_ logs: [WorkoutLog]) -> WorkoutLog? { logs.first }

    static func hasLogged(_ logs: [WorkoutLog]) -> Bool { !logs.isEmpty }

    /// Monday-indexed (Mon=1 … Sun=7) set of weekdays with a session this
    /// calendar week. `startedAts` are each log's `startedAt`.
    static func weekSessionDays(_ startedAts: [Date],
                                now: Date = .now,
                                calendar baseCal: Calendar = .current) -> Set<Int> {
        var cal = baseCal
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = cal.date(from: components) else { return [] }
        var days: Set<Int> = []
        for started in startedAts where started >= weekStart {
            let weekday = cal.component(.weekday, from: started)
            let monIndex = ((weekday + 5) % 7) + 1
            days.insert(monIndex)
        }
        return days
    }
}
