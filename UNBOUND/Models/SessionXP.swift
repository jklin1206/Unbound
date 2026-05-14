import Foundation

// MARK: - SessionXPRecord
//
// Per-user session counter. Drives streaks + badge unlocks. Does NOT drive
// SubRank — rank is strictly strength-based. XP is participation.

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
