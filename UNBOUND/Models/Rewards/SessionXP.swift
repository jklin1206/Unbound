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
    var processedSourceReceipts: [String: SessionXPSourceReceipt]

    init(
        userId: String,
        totalSessions: Int,
        currentStreak: Int,
        longestStreak: Int,
        lastSessionDate: Date?,
        weeklyCount: Int,
        weekStartDate: Date,
        processedSourceReceipts: [String: SessionXPSourceReceipt] = [:]
    ) {
        self.userId = userId
        self.totalSessions = totalSessions
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastSessionDate = lastSessionDate
        self.weeklyCount = weeklyCount
        self.weekStartDate = weekStartDate
        self.processedSourceReceipts = processedSourceReceipts
    }

    private enum CodingKeys: String, CodingKey {
        case userId, totalSessions, currentStreak, longestStreak, lastSessionDate
        case weeklyCount, weekStartDate, processedSourceReceipts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        totalSessions = try c.decode(Int.self, forKey: .totalSessions)
        currentStreak = try c.decode(Int.self, forKey: .currentStreak)
        longestStreak = try c.decode(Int.self, forKey: .longestStreak)
        lastSessionDate = try c.decodeIfPresent(Date.self, forKey: .lastSessionDate)
        weeklyCount = try c.decode(Int.self, forKey: .weeklyCount)
        weekStartDate = try c.decode(Date.self, forKey: .weekStartDate)
        processedSourceReceipts = try c.decodeIfPresent(
            [String: SessionXPSourceReceipt].self,
            forKey: .processedSourceReceipts
        ) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(totalSessions, forKey: .totalSessions)
        try c.encode(currentStreak, forKey: .currentStreak)
        try c.encode(longestStreak, forKey: .longestStreak)
        try c.encodeIfPresent(lastSessionDate, forKey: .lastSessionDate)
        try c.encode(weeklyCount, forKey: .weeklyCount)
        try c.encode(weekStartDate, forKey: .weekStartDate)
        try c.encode(processedSourceReceipts, forKey: .processedSourceReceipts)
    }

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

    mutating func markProcessed(sourceId: String?, receipt: SessionXPSourceReceipt) {
        guard let sourceId, !sourceId.isEmpty else { return }
        processedSourceReceipts[sourceId] = receipt
        if processedSourceReceipts.count > 250 {
            let overflow = processedSourceReceipts.count - 250
            let sortedKeys = processedSourceReceipts.keys.sorted()
            for key in sortedKeys.prefix(overflow) {
                processedSourceReceipts.removeValue(forKey: key)
            }
        }
    }

    func processedReceipt(for sourceId: String?) -> SessionXPSourceReceipt? {
        guard let sourceId, !sourceId.isEmpty else { return nil }
        return processedSourceReceipts[sourceId]
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

struct SessionXPSourceReceipt: Codable, Sendable {
    let streakExtended: Bool
    let streakBroken: Bool
    let streakCountAfter: Int

    init(
        streakExtended: Bool,
        streakBroken: Bool,
        streakCountAfter: Int = 0
    ) {
        self.streakExtended = streakExtended
        self.streakBroken = streakBroken
        self.streakCountAfter = streakCountAfter
    }

    private enum CodingKeys: String, CodingKey {
        case streakExtended, streakBroken, streakCountAfter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streakExtended = try c.decode(Bool.self, forKey: .streakExtended)
        streakBroken = try c.decode(Bool.self, forKey: .streakBroken)
        streakCountAfter = try c.decodeIfPresent(Int.self, forKey: .streakCountAfter) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(streakExtended, forKey: .streakExtended)
        try c.encode(streakBroken, forKey: .streakBroken)
        try c.encode(streakCountAfter, forKey: .streakCountAfter)
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
