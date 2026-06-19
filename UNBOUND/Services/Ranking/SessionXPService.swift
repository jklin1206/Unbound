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

    /// Source-idempotent variant for canonical completion flows that may retry
    /// after partial persistence. Duplicate source ids replay the original
    /// streak flags without incrementing counters again.
    @discardableResult
    func recordSession(userId: String, at: Date, sourceId: String?) async -> SessionXPDelta

    /// Apply an out-of-band XP bonus (e.g. linked-session +20%, affinity +10%).
    /// Posts `.sessionXPBonusAdded` with the amount and reason.
    func addBonus(userId: String, amount: Int, reason: String) async

    /// Returns the affinity bonus amount applied during the most recent bonus
    /// entry for the given user (reason == "affinity"), or 0 if none.
    func affinityBonusForLatestSession(userId: String) async -> Int

    /// Records a session AND applies the squad affinity +10% bonus if the
    /// session's dominant axis matches the squad's affinity axis.
    ///
    /// - Parameters:
    ///   - userId: The user.
    ///   - date: Session date.
    ///   - log: The finished `WorkoutLog`. Used to derive dominant axis.
    ///   - catalog: Attribute catalog for delta computation.
    ///   - squadService: Squad service for affinity lookup.
    @discardableResult
    func recordSessionWithAffinity(
        userId: String,
        at date: Date,
        log: WorkoutLog,
        catalog: AttributeCatalogProtocol,
        squadService: SquadServiceProtocol
    ) async -> SessionXPDelta
}

extension SessionXPServiceProtocol {
    @discardableResult
    func recordSession(userId: String, at date: Date, sourceId: String?) async -> SessionXPDelta {
        await recordSession(userId: userId, at: date)
    }
}

// MARK: - SessionXPBonusEntry
//
// A lightweight ledger entry written for each out-of-band XP bonus.
// Stored per-user under "unbound.sessionxpbonus.<userId>".

struct SessionXPBonusEntry: Codable, Sendable {
    let amount: Int
    let reason: String
    let date: Date
}

// MARK: - SessionXPService

@MainActor
final class SessionXPService: SessionXPServiceProtocol {
    static let shared = SessionXPService()

    private let logger = LoggingService.shared
    private let defaults = UserDefaults.standard
    private let bonusKeyPrefix = "unbound.sessionxpbonus."
    private let streakResetKey = "unbound.streakResetDays"

    /// The UserDefaults key the per-user record is persisted under. Exposed so
    /// the sign-in data migration re-keys the streak to the exact same slot the
    /// service reads from — a mismatch here would silently fail to carry the
    /// streak over (see UserDataMigrationCoordinator.migrateSessionXP).
    nonisolated static func storageKey(for userId: String) -> String {
        "unbound.sessionxp." + userId
    }

    private init() {
        // Default streak-reset window (days). 14 = "life happens, don't punish."
        if defaults.object(forKey: streakResetKey) == nil {
            defaults.set(14, forKey: streakResetKey)
        }
    }

    func record(userId: String) -> SessionXPRecord {
        load(userId: userId) ?? .empty(userId: userId, weekStart: Self.currentWeekStart())
    }

    /// Carries a SessionXP record from a pre-auth (legacy) userId onto the
    /// signed-in userId, atomically on the main actor so it can't interleave
    /// with a concurrent `recordSession` read-modify-write on the same key.
    /// This is the streak's half of the sign-in data migration (Bug #3): the
    /// legacy slot is left in place as a backup; the signed-in slot is the new
    /// source of truth. Returns the outcome so the migration coordinator can
    /// build its summary and defer the completion flag on a corrupt/failed run.
    func migrateRecord(from legacyUserId: String, to supabaseUserId: String) -> SessionXPMigrationOutcome {
        guard let legacyData = defaults.data(forKey: key(for: legacyUserId)) else {
            return .noLegacy
        }
        guard let legacy = try? JSONDecoder.unbound.decode(SessionXPRecord.self, from: legacyData) else {
            // Data present but unreadable — surface as a failure so the migration
            // retries instead of silently losing the streak.
            return .failed
        }

        let result: SessionXPRecord
        let outcome: SessionXPMigrationOutcome
        if let existing = load(userId: supabaseUserId) {
            let merged = SessionXPRecord.merging(legacy: legacy, target: existing)
            guard merged != existing else { return .unchanged }
            result = merged
            outcome = .merged
        } else {
            result = legacy.rekeyed(to: supabaseUserId)
            outcome = .rekeyed
        }

        guard persisted(result) else { return .failed }
        return outcome
    }

    @discardableResult
    func recordSession(userId: String, at date: Date) async -> SessionXPDelta {
        await recordSession(userId: userId, at: date, sourceId: nil)
    }

    @discardableResult
    func recordSession(userId: String, at date: Date, sourceId: String?) async -> SessionXPDelta {
        var current = record(userId: userId)
        let previous = current

        if let receipt = current.processedReceipt(for: sourceId) {
            var replayed = current
            if receipt.streakCountAfter > 0 {
                replayed.currentStreak = receipt.streakCountAfter
                replayed.longestStreak = max(replayed.longestStreak, receipt.streakCountAfter)
            }
            return SessionXPDelta(
                previous: current,
                updated: replayed,
                streakExtended: receipt.streakExtended,
                streakBroken: receipt.streakBroken
            )
        }

        current.totalSessions += 1

        // Streak logic. Consecutive calendar days extend the streak. The
        // base 48h grace window protects a single missed day, and longer
        // gaps only survive when every skipped program day is recovery.
        let cal = Calendar.current
        let streakReset = max(2, defaults.integer(forKey: streakResetKey))

        let (newStreak, extended, broken): (Int, Bool, Bool) = {
            guard let last = current.lastSessionDate else {
                return (1, true, false)
            }
            let decision = ProgramAwareStreakPolicy.shouldExtendStreak(
                from: last,
                to: date,
                currentStreak: current.currentStreak,
                resetWindowDays: streakReset,
                activeProgram: ProgramStore.shared.program,
                calendar: cal
            )
            return (decision.streak, decision.extended, decision.broken)
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

        current.markProcessed(
            sourceId: sourceId,
            receipt: SessionXPSourceReceipt(
                streakExtended: extended,
                streakBroken: broken,
                streakCountAfter: current.currentStreak
            )
        )

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

    // MARK: Affinity + Session

    @discardableResult
    func recordSessionWithAffinity(
        userId: String,
        at date: Date,
        log: WorkoutLog,
        catalog: AttributeCatalogProtocol,
        squadService: SquadServiceProtocol
    ) async -> SessionXPDelta {
        // 1. Record the base session (streak, counters, .sessionXPUpdated).
        let delta = await recordSession(userId: userId, at: date)

        // 2. Check squad affinity.
        //    baseXP proxy: fixed 10 units per session for bonus computation.
        //    +10% of base = 1 unit, +20% of base = 2 units, net max = 2 (non-stacking).
        let baseXP = 10

        let squadState = squadService.state(userId: userId)
        if let squad = squadState.currentSquad,
           let affinityAxis = squad.affinityAxis,
           let dominant = AttributeIngest.dominantAxis(for: log, catalog: catalog),
           affinityAxis == dominant {
            let affinityBonus = Int(Double(baseXP) * 0.10)
            await addBonus(userId: userId, amount: affinityBonus, reason: "affinity")
        }

        return delta
    }

    // MARK: Bonus

    func addBonus(userId: String, amount: Int, reason: String) async {
        guard amount != 0 else { return }
        let entry = SessionXPBonusEntry(amount: amount, reason: reason, date: Date())
        var ledger = loadBonusLedger(userId: userId)
        ledger.append(entry)
        persistBonusLedger(ledger, userId: userId)
        NotificationCenter.default.post(
            name: .sessionXPBonusAdded,
            object: nil,
            userInfo: ["userId": userId, "amount": amount, "reason": reason]
        )
        logger.log(
            "Session XP bonus: userId=\(userId) amount=\(amount) reason=\(reason)",
            level: .debug
        )
    }

    func affinityBonusForLatestSession(userId: String) async -> Int {
        let ledger = loadBonusLedger(userId: userId)
        return ledger.last(where: { $0.reason == "affinity" })?.amount ?? 0
    }

    // MARK: Persistence

    private func key(for userId: String) -> String { Self.storageKey(for: userId) }

    private func bonusKey(for userId: String) -> String { bonusKeyPrefix + userId }

    private func loadBonusLedger(userId: String) -> [SessionXPBonusEntry] {
        guard let data = defaults.data(forKey: bonusKey(for: userId)) else { return [] }
        return (try? JSONDecoder.unbound.decode([SessionXPBonusEntry].self, from: data)) ?? []
    }

    private func persistBonusLedger(_ ledger: [SessionXPBonusEntry], userId: String) {
        // Cap the ledger at 200 entries to avoid unbounded growth.
        let capped = ledger.count > 200 ? Array(ledger.suffix(200)) : ledger
        guard let data = try? JSONEncoder.unbound.encode(capped) else { return }
        defaults.set(data, forKey: bonusKey(for: userId))
    }

    private func load(userId: String) -> SessionXPRecord? {
        guard let data = defaults.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder.unbound.decode(SessionXPRecord.self, from: data)
    }

    private func persist(_ record: SessionXPRecord) {
        _ = persisted(record)
    }

    /// Persists a record, returning whether the encode + write succeeded so the
    /// sign-in migration can report a write failure rather than silently
    /// dropping the streak.
    @discardableResult
    private func persisted(_ record: SessionXPRecord) -> Bool {
        guard let data = try? JSONEncoder.unbound.encode(record) else { return false }
        defaults.set(data, forKey: key(for: record.userId))
        return true
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

    // Spy properties for test assertions.
    struct BonusCall: Equatable {
        let userId: String
        let amount: Int
        let reason: String
    }
    var bonusCalls: [BonusCall] = []
    var stubbedAffinityBonus: Int = 0

    func record(userId: String) -> SessionXPRecord {
        records[userId] ?? .empty(userId: userId, weekStart: Date())
    }

    @discardableResult
    func recordSession(userId: String, at: Date) async -> SessionXPDelta {
        await recordSession(userId: userId, at: at, sourceId: nil)
    }

    @discardableResult
    func recordSession(userId: String, at: Date, sourceId: String?) async -> SessionXPDelta {
        var r = record(userId: userId)
        let previous = r
        if let receipt = r.processedReceipt(for: sourceId) {
            var replayed = r
            if receipt.streakCountAfter > 0 {
                replayed.currentStreak = receipt.streakCountAfter
                replayed.longestStreak = max(replayed.longestStreak, receipt.streakCountAfter)
            }
            return SessionXPDelta(
                previous: r,
                updated: replayed,
                streakExtended: receipt.streakExtended,
                streakBroken: receipt.streakBroken
            )
        }
        r.totalSessions += 1
        r.currentStreak += 1
        r.longestStreak = max(r.longestStreak, r.currentStreak)
        r.lastSessionDate = at
        r.weeklyCount += 1
        r.markProcessed(
            sourceId: sourceId,
            receipt: SessionXPSourceReceipt(
                streakExtended: true,
                streakBroken: false,
                streakCountAfter: r.currentStreak
            )
        )
        records[userId] = r
        return SessionXPDelta(previous: previous, updated: r, streakExtended: true, streakBroken: false)
    }

    func addBonus(userId: String, amount: Int, reason: String) async {
        bonusCalls.append(BonusCall(userId: userId, amount: amount, reason: reason))
    }

    func affinityBonusForLatestSession(userId: String) async -> Int {
        stubbedAffinityBonus
    }

    // Spy support for affinity tests.
    var stubbedDominantAxis: AttributeKey? = nil

    @discardableResult
    func recordSessionWithAffinity(
        userId: String,
        at date: Date,
        log: WorkoutLog,
        catalog: AttributeCatalogProtocol,
        squadService: SquadServiceProtocol
    ) async -> SessionXPDelta {
        let delta = await recordSession(userId: userId, at: date)
        let baseXP = 10
        let squadState = squadService.state(userId: userId)
        // In tests, use the stubbed dominant axis rather than computing from log.
        let dominant = stubbedDominantAxis ?? AttributeIngest.dominantAxis(for: log, catalog: catalog)
        if let squad = squadState.currentSquad,
           let affinityAxis = squad.affinityAxis,
           let dominant = dominant,
           affinityAxis == dominant {
            let bonus = Int(Double(baseXP) * 0.10)
            await addBonus(userId: userId, amount: bonus, reason: "affinity")
        }
        return delta
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
