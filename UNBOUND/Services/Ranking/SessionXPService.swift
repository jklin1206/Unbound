import Foundation

// MARK: - SessionXPServiceProtocol

@MainActor
protocol SessionXPServiceProtocol: AnyObject {
    /// Returns the cached record for the user (or an empty one).
    func record(userId: String) -> SessionXPRecord

    /// Records a session. Updates streak + weekly counters. Posts
    /// `.sessionXPUpdated`. Badge evaluation is handled by callers.
    @discardableResult
    func recordSession(userId: String, at: Date) async -> SessionXPDelta
}

// MARK: - SessionXPService

@MainActor
final class SessionXPService: SessionXPServiceProtocol {
    static let shared = SessionXPService()

    private let logger = LoggingService.shared
    private let defaults = UserDefaults.standard
    private let keyPrefix = "unbound.sessionxp."
    private let streakResetKey = "unbound.streakResetDays"

    private init() {
        // Default streak-reset window (days). 14 = "life happens, don't punish."
        if defaults.object(forKey: streakResetKey) == nil {
            defaults.set(14, forKey: streakResetKey)
        }
    }

    func record(userId: String) -> SessionXPRecord {
        load(userId: userId) ?? .empty(userId: userId, weekStart: Self.currentWeekStart())
    }

    @discardableResult
    func recordSession(userId: String, at date: Date) async -> SessionXPDelta {
        var current = record(userId: userId)
        let previous = current

        current.totalSessions += 1

        // Streak logic. Consecutive calendar days extend the streak. > 2
        // calendar days without a session breaks it (per spec — gives a
        // 48h grace window so users don't lose streaks for a single rest
        // day). The streakResetDays fallback (default 14) is a hard cap.
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let streakReset = max(2, defaults.integer(forKey: streakResetKey))

        let (newStreak, extended, broken): (Int, Bool, Bool) = {
            guard let last = current.lastSessionDate else {
                return (1, true, false)
            }
            let lastDay = cal.startOfDay(for: last)
            if lastDay == today { return (max(current.currentStreak, 1), false, false) }
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff <= 2 { return (current.currentStreak + 1, true, false) }
            if diff > streakReset { return (1, false, true) }
            return (1, false, true)
        }()

        current.currentStreak = newStreak
        current.longestStreak = max(current.longestStreak, newStreak)
        current.lastSessionDate = date

        // Weekly roll-over.
        let weekStart = Self.currentWeekStart(relativeTo: date)
        if cal.startOfDay(for: current.weekStartDate) != cal.startOfDay(for: weekStart) {
            current.weeklyCount = 1
            current.weekStartDate = weekStart
        } else {
            current.weeklyCount += 1
        }

        persist(current)

        let delta = SessionXPDelta(
            previous: previous,
            updated: current,
            streakExtended: extended,
            streakBroken: broken
        )
        NotificationCenter.default.post(
            name: .sessionXPUpdated,
            object: nil,
            userInfo: ["delta": delta]
        )
        logger.log(
            "Session XP: total \(current.totalSessions), streak \(current.currentStreak), weekly \(current.weeklyCount)",
            level: .debug
        )
        return delta
    }

    // MARK: Persistence

    private func key(for userId: String) -> String { keyPrefix + userId }

    private func load(userId: String) -> SessionXPRecord? {
        guard let data = defaults.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder.unbound.decode(SessionXPRecord.self, from: data)
    }

    private func persist(_ record: SessionXPRecord) {
        guard let data = try? JSONEncoder.unbound.encode(record) else { return }
        defaults.set(data, forKey: key(for: record.userId))
    }

    // MARK: Helpers

    private static func currentWeekStart(relativeTo date: Date = Date()) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? cal.startOfDay(for: date)
    }
}

// MARK: - MockSessionXPService

@MainActor
final class MockSessionXPService: SessionXPServiceProtocol {
    var records: [String: SessionXPRecord] = [:]

    func record(userId: String) -> SessionXPRecord {
        records[userId] ?? .empty(userId: userId, weekStart: Date())
    }

    @discardableResult
    func recordSession(userId: String, at: Date) async -> SessionXPDelta {
        var r = record(userId: userId)
        let previous = r
        r.totalSessions += 1
        r.currentStreak += 1
        r.longestStreak = max(r.longestStreak, r.currentStreak)
        r.lastSessionDate = at
        r.weeklyCount += 1
        records[userId] = r
        return SessionXPDelta(previous: previous, updated: r, streakExtended: true, streakBroken: false)
    }
}

// MARK: - Shared Codable helpers
//
// Namespaced encoder/decoder using ISO8601 date strategy so UserDefaults
// blobs round-trip cleanly across app launches.

extension JSONDecoder {
    static let unbound: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension JSONEncoder {
    static let unbound: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
