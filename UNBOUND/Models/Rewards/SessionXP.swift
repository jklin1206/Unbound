import Foundation

// MARK: - SessionXPRecord
//
// Per-user session counter. Drives streaks + badge unlocks. Does NOT drive
// RankTier — rank is strictly strength-based. XP is participation.

struct SessionXPRecord: Codable, Sendable, Equatable, Identifiable {
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

struct SessionXPSourceReceipt: Codable, Sendable, Equatable {
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

// MARK: - Sign-in re-key / merge
//
// SessionXP is keyed by userId, which changes on the anonymous → signed-in
// transition. Carrying the record across that transition is what stops the
// streak resetting to zero on sign-in (see UserDataMigrationCoordinator +
// SessionXPService.migrateRecord).

/// Outcome of carrying a SessionXP record across the sign-in identity change.
enum SessionXPMigrationOutcome: Sendable, Equatable {
    /// No pre-auth record existed — nothing to carry over.
    case noLegacy
    /// The legacy record was carried onto the signed-in id (no target existed).
    case rekeyed
    /// The legacy record was merged into an existing signed-in record.
    case merged
    /// A signed-in record already held the same data — no write needed.
    case unchanged
    /// Legacy data was present but unreadable (corrupt), or the write failed —
    /// surfaced as a migration failure so it is retried rather than silently
    /// dropping the streak.
    case failed
}

extension SessionXPRecord {
    /// Returns a copy of this record keyed to a new userId, preserving all
    /// counters and receipts.
    func rekeyed(to userId: String) -> SessionXPRecord {
        SessionXPRecord(
            userId: userId,
            totalSessions: totalSessions,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastSessionDate: lastSessionDate,
            weeklyCount: weeklyCount,
            weekStartDate: weekStartDate,
            processedSourceReceipts: processedSourceReceipts
        )
    }

    /// Combines a pre-auth (legacy) record with an existing post-auth (target)
    /// record without ever regressing the streak, keyed to `target.userId`.
    ///
    /// The current streak is derived with the *same* day-gap policy the live
    /// streak uses: the older run is bridged forward to the newer run's last
    /// logged day. If the two runs are contiguous (within the grace window) the
    /// streaks chain — e.g. a 3-day anonymous run ending yesterday plus a
    /// session today reads as 4, not 1. If the gap broke the older run, the
    /// newer run's streak stands on its own (a long-dead streak is never
    /// resurrected). All-time bests and totals keep the better of both, and
    /// receipts are unioned so source-idempotency survives the merge.
    static func merging(
        legacy: SessionXPRecord,
        target: SessionXPRecord,
        calendar: Calendar = .current
    ) -> SessionXPRecord {
        let legacyDate = legacy.lastSessionDate ?? .distantPast
        let targetDate = target.lastSessionDate ?? .distantPast
        let olderIsLegacy = legacyDate <= targetDate
        let older = olderIsLegacy ? legacy : target
        let newer = olderIsLegacy ? target : legacy

        // Bridge the older run forward to the newer run's last logged day.
        let bridge = ProgramAwareStreakPolicy.shouldExtendStreak(
            from: older.lastSessionDate ?? .distantPast,
            to: newer.lastSessionDate ?? .distantPast,
            currentStreak: older.currentStreak,
            calendar: calendar
        )
        // Contiguous → the chained streak (older run + bridged days), but never
        // below the newer run's own count. Broken → the newer run is the live one.
        let currentStreak = bridge.broken
            ? newer.currentStreak
            : max(bridge.streak, newer.currentStreak)

        return SessionXPRecord(
            userId: target.userId,
            totalSessions: max(legacy.totalSessions, target.totalSessions),
            currentStreak: currentStreak,
            longestStreak: max(legacy.longestStreak, target.longestStreak, currentStreak),
            lastSessionDate: newer.lastSessionDate,
            weeklyCount: newer.weeklyCount,
            weekStartDate: newer.weekStartDate,
            processedSourceReceipts: legacy.processedSourceReceipts
                .merging(target.processedSourceReceipts) { _, target in target }
        )
    }
}

extension Notification.Name {
    static let sessionXPUpdated   = Notification.Name("unbound.sessionXPUpdated")
    static let sessionXPBonusAdded = Notification.Name("unbound.sessionXPBonusAdded")
}
