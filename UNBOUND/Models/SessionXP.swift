import Foundation

// MARK: - SessionXPRecord
//
// Per-user session counter. Drives streaks + badge unlocks. Does NOT drive
// RankTier — rank is strictly strength-based. XP is participation.

struct SessionXPRecord: Codable, Sendable, Identifiable {
    var id: String { "\(userId):sessionxp" }
    let userId: String
    var totalSessions: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastSessionDate: Date?
    var weeklyCount: Int
    var weekStartDate: Date

    static func empty(userId: String, weekStart: Date) -> SessionXPRecord {
        SessionXPRecord(
            userId: userId,
            totalSessions: 0,
            currentStreak: 0,
            longestStreak: 0,
            lastSessionDate: nil,
            weeklyCount: 0,
            weekStartDate: weekStart
        )
    }

    // MARK: - Streak countdown (Liftoff rule: log within a 3-day gap)

    /// Days left to log a workout before the streak breaks. nil if no active
    /// streak. `3` = logged today (full headroom), `0` = log today or lose it,
    /// negative = already lapsed (next session starts a new run).
    func streakDaysRemaining(asOf now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard currentStreak > 0, let last = lastSessionDate else { return nil }
        let gap = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return ProgramAwareStreakPolicy.maxGapDays - gap
    }

    /// True when the streak will break unless the user logs today.
    func streakAtRisk(asOf now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let left = streakDaysRemaining(asOf: now, calendar: calendar) else { return false }
        return left <= 0
    }

    /// True when a session was already logged today (streak safe, full headroom).
    func loggedToday(asOf now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = lastSessionDate else { return false }
        return calendar.isDate(last, inSameDayAs: now)
    }
}

struct SessionXPDelta: Sendable {
    let previous: SessionXPRecord
    let updated: SessionXPRecord
    let streakExtended: Bool
    let streakBroken: Bool

    var streakIncreasedTo: Int? {
        streakExtended ? updated.currentStreak : nil
    }
}

extension Notification.Name {
    static let sessionXPUpdated   = Notification.Name("unbound.sessionXPUpdated")
    static let sessionXPBonusAdded = Notification.Name("unbound.sessionXPBonusAdded")
}
