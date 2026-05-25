import Foundation

enum MissedSessionState: String, Codable, Equatable, Sendable {
    case normal
    case softCheckIn
    case rampWeekOffered
    case staleRecalibrationRecommended
}

struct ScheduledSessionAttendance: Equatable, Sendable {
    var scheduledAt: Date
    var completedAt: Date?

    init(scheduledAt: Date, completedAt: Date? = nil) {
        self.scheduledAt = scheduledAt
        self.completedAt = completedAt
    }

    var wasMissed: Bool { completedAt == nil }
}

struct MissedSessionMetricResult: Equatable, Sendable {
    var scheduledCount: Int
    var missedCount: Int
    var missedRatio: Double
    var state: MissedSessionState
}

enum MissedSessionMetric {
    static func evaluate(
        sessions: [ScheduledSessionAttendance],
        now: Date,
        calendar: Calendar = .current
    ) -> MissedSessionMetricResult {
        let window = windowStart(days: 7, before: now, calendar: calendar)
        let currentWindow = sessions.filter { session in
            session.scheduledAt >= window && session.scheduledAt <= now
        }
        let scheduled = currentWindow.count
        let missed = currentWindow.filter(\.wasMissed).count
        let ratio = scheduled == 0 ? 0 : Double(missed) / Double(scheduled)
        let sustained = isSustainedHighMiss(
            sessions: sessions,
            now: now,
            calendar: calendar
        )
        return MissedSessionMetricResult(
            scheduledCount: scheduled,
            missedCount: missed,
            missedRatio: ratio,
            state: state(missedRatio: ratio, sustainedHighMiss: sustained)
        )
    }

    static func state(
        missedRatio: Double,
        sustainedHighMiss: Bool = false
    ) -> MissedSessionState {
        if sustainedHighMiss { return .staleRecalibrationRecommended }
        if missedRatio >= 0.8 { return .rampWeekOffered }
        if missedRatio >= 0.5 { return .softCheckIn }
        return .normal
    }

    private static func isSustainedHighMiss(
        sessions: [ScheduledSessionAttendance],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let current = ratio(days: 7, endingAt: now, sessions: sessions, calendar: calendar)
        guard current >= 0.8 else { return false }
        let currentStart = windowStart(days: 7, before: now, calendar: calendar)
        let previousEnd = currentStart.addingTimeInterval(-1)
        let previous = ratio(days: 7, endingAt: previousEnd, sessions: sessions, calendar: calendar)
        return previous >= 0.8
    }

    private static func ratio(
        days: Int,
        endingAt end: Date,
        sessions: [ScheduledSessionAttendance],
        calendar: Calendar
    ) -> Double {
        let start = windowStart(days: days, before: end, calendar: calendar)
        let window = sessions.filter { $0.scheduledAt >= start && $0.scheduledAt <= end }
        guard !window.isEmpty else { return 0 }
        return Double(window.filter(\.wasMissed).count) / Double(window.count)
    }

    private static func windowStart(days: Int, before date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -days, to: date) ?? date
    }
}
