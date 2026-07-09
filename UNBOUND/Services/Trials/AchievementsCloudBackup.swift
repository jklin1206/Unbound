// UNBOUND/Services/Trials/AchievementsCloudBackup.swift
import Foundation

/// Cloud mirror for titles, kept vows, and badges.
///
/// Unlocked titles, the kept-vows history, per-lane completion counters, and
/// the badge unlock map live in device UserDefaults; without a cloud copy a
/// reinstall silently wipes them, and several are NOT recomputable (streak
/// badges unlock at a transient streak peak, `first_*` skill badges scan a
/// bounded log window, keptVows has no other home). This service patches the
/// durable subset onto the synced `users` doc through the SAME offline-safe
/// choke point every other users-doc write takes (`SyncedDatabase` -> outbox
/// -> `sync_merge_row` field-level merge). Local UserDefaults stays the source
/// of truth; this is a best-effort mirror whose failures are logged, never
/// silenced.
protocol AchievementsBackuping: Sendable {
    func backup(userId: String)
}

/// The wire payload for the `users.achievementsBackup` field: the durable
/// subset of `WeeklyVowsState` plus the badge unlock map.
///
/// Weekly-ephemeral fields (`currentWeekStart`, `currentWeekCards`,
/// `currentTrial`, `skippedCurrentWeek`, `fuelAnchorsByVowId`,
/// `lastVowLogByVowId`) are deliberately NOT here — they regenerate on the
/// Monday roll, and restoring a stale week would confuse the rollover.
///
/// The local store persists dates with a PLAIN JSONEncoder (reference-epoch
/// doubles); the wire uses ISO-8601 (whole seconds) to match both
/// `DatabaseService` (local decode) and `UnboundSupabase.dbDecoder` (remote
/// decode). The truncation is safe: every id derived from a date
/// (`KeptVow.id`, `WeeklyVowPenaltyLedgerEntry.id`) already floors to whole
/// seconds via `Int(...)`, so ids survive the round trip and the
/// union-by-id merges below never duplicate an entry.
struct AchievementsBackup: Codable, Equatable, Sendable {
    var unlockedTitles: [TitleID]
    var equippedTitle: TitleID?
    var keptVows: [KeptVow]
    var completionsByLane: [VowLane: Int]
    var weeklyVowCompletionLedger: [WeeklyVowCompletionLedgerEntry]
    var weeklyVowPenaltyLedger: [WeeklyVowPenaltyLedgerEntry]
    /// badgeId -> unlockedAt. The EARLIEST date wins on merge — the earlier
    /// timestamp is the true unlock moment.
    var badges: [String: Date]
}

extension AchievementsBackup {
    /// Snapshot ONLY the durable fields of a vows state + a badge map.
    init(state: WeeklyVowsState, badges: [String: Date]) {
        self.init(
            unlockedTitles: state.unlockedTitles,
            equippedTitle: state.equippedTitle,
            keptVows: state.keptVows,
            completionsByLane: state.completionsByLane,
            weeklyVowCompletionLedger: state.weeklyVowCompletionLedger,
            weeklyVowPenaltyLedger: state.weeklyVowPenaltyLedger,
            badges: badges
        )
    }
}

final class AchievementsCloudBackup: AchievementsBackuping, @unchecked Sendable {
    static let shared = AchievementsCloudBackup()

    private let database: any DatabaseServiceProtocol
    private let logger: LoggingService
    private let defaults: UserDefaults
    /// Seam-free reader over the same defaults the production store writes.
    /// Constructed here (never `.shared`) so wiring `WeeklyVowsStore.shared`'s
    /// backup to `AchievementsCloudBackup.shared` cannot recurse.
    private let vows: WeeklyVowsStore

    /// Serializes the patch writes AND guards `lastSent`: each backup call
    /// captures its snapshot synchronously and chains behind the previous
    /// write, so two rapid unlocks can never land out of order and let a stale
    /// snapshot overwrite a newer one (locally or via the FIFO outbox).
    private let tailLock = NSLock()
    private var tail: Task<Void, Never>?
    /// Last successfully patched snapshot per userId. Ephemeral-only saves
    /// (week rolls, picks, daily self-report taps) produce an identical
    /// durable snapshot and skip the redundant patch.
    private var lastSent: [String: AchievementsBackup] = [:]

    /// ISO-8601 dates to match both `DatabaseService` (local decode) and
    /// `UnboundSupabase.dbDecoder` (remote decode), so the nested unlock dates
    /// round-trip identically through the local store and the jsonb column.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(
        database: any DatabaseServiceProtocol = SyncedDatabase.shared,
        logger: LoggingService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.database = database
        self.logger = logger
        self.defaults = defaults
        self.vows = WeeklyVowsStore(defaults: defaults)
    }

    // MARK: - Write path

    func backup(userId: String) {
        let snapshot = AchievementsBackup(
            state: vows.load(userId: userId),
            badges: BadgeUnlockStore.load(userId: userId, defaults: defaults)
        )
        enqueuePatch(snapshot, userId: userId)
    }

    /// Append this snapshot to the ordered write chain. The snapshot is taken
    /// at call time; the chain guarantees write order matches call order.
    private func enqueuePatch(_ snapshot: AchievementsBackup, userId: String) {
        tailLock.lock()
        defer { tailLock.unlock() }
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            await self?.patch(snapshot, userId: userId)
        }
    }

    /// Patch the backup field onto the `users` doc. `id` travels in the
    /// payload (the `sync_merge_row` ownership guard reads `p_full->>'id'`,
    /// and it is excluded from the SET clause server-side) so the write is
    /// valid even if this device has no local `users` doc yet.
    /// Lock use lives in synchronous helpers: NSLock is not async-safe to
    /// hold across awaits, and Swift 6 rejects lock()/unlock() in async code.
    private func isAlreadySent(_ snapshot: AchievementsBackup, userId: String) -> Bool {
        tailLock.lock()
        defer { tailLock.unlock() }
        return lastSent[userId] == snapshot
    }

    private func markSent(_ snapshot: AchievementsBackup, userId: String) {
        tailLock.lock()
        defer { tailLock.unlock() }
        lastSent[userId] = snapshot
    }

    private func patch(_ snapshot: AchievementsBackup, userId: String) async {
        // Compared at patch time (the chain is serialized), so a burst of
        // saves that changed nothing durable collapses to zero patches.
        guard !isAlreadySent(snapshot, userId: userId) else { return }

        guard let encoded = Self.jsonObject(snapshot) else {
            logger.log(
                "Achievements cloud backup: failed to encode snapshot",
                level: .error,
                context: ["userId": userId]
            )
            return
        }
        do {
            try await database.update(
                ["id": userId, "achievementsBackup": encoded],
                collection: "users",
                documentId: userId
            )
            markSent(snapshot, userId: userId)
        } catch {
            // lastSent stays untouched so the next durable save retries.
            logger.log(
                "Achievements cloud backup failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    // MARK: - Restore path

    /// Seed the local stores from a fetched server profile. Merges are
    /// conservative unions that can NEVER drop a locally-earned unlock; writes
    /// happen only when something actually changes. Safe to run every launch.
    /// Seeding through the production `.shared` store re-mirrors the merged
    /// union to the cloud via the store's own backup seam — by design, so both
    /// sides converge on the superset.
    @MainActor
    func seedLocalStores(
        from profile: UserProfile,
        userId: String,
        vowsStore: WeeklyVowsStore = .shared,
        badgeDefaults: UserDefaults = .standard
    ) {
        guard let server = profile.achievementsBackup else { return }
        seedLocalStores(from: server, userId: userId, vowsStore: vowsStore, badgeDefaults: badgeDefaults)
    }

    @MainActor
    func seedLocalStores(
        from server: AchievementsBackup,
        userId: String,
        vowsStore: WeeklyVowsStore,
        badgeDefaults: UserDefaults
    ) {
        let local = vowsStore.load(userId: userId)
        let merged = Self.merged(local: local, server: server)
        if merged != local {
            vowsStore.save(merged, userId: userId)
        }

        let localBadges = BadgeUnlockStore.load(userId: userId, defaults: badgeDefaults)
        let mergedBadges = Self.mergedBadges(local: localBadges, server: server.badges)
        if mergedBadges != localBadges {
            BadgeUnlockStore.save(mergedBadges, userId: userId, defaults: badgeDefaults)
        }
    }

    // MARK: - Merge semantics

    /// Merge a server backup into the local state, durable fields ONLY — the
    /// weekly-ephemeral fields pass through from `local` untouched.
    /// - Titles: union; local order first, server-only titles appended.
    /// - Equipped title: local pick always wins; adopt the server pick only
    ///   when local has none AND it is owned after the union (same guard
    ///   `equipTitle` enforces).
    /// - Kept vows: union by id (local wins), oldest-first, trimmed to the
    ///   same 100-entry tail `sealVow` keeps.
    /// - Per-lane counters: max per lane (monotone counters — max can only
    ///   restore, never double-count).
    /// - Ledgers: union by id so a restored receipt keeps its idempotency
    ///   bite (`recordBreakIfNeeded` / completion-bonus consumption see the
    ///   entry and refuse to re-credit); penalty tail matches the 100-entry
    ///   cap `WeeklyVowPenaltyCatalog` keeps.
    static func merged(local: WeeklyVowsState, server: AchievementsBackup) -> WeeklyVowsState {
        var merged = local

        let ownedTitles = Set(local.unlockedTitles)
        merged.unlockedTitles = local.unlockedTitles
            + server.unlockedTitles.filter { !ownedTitles.contains($0) }

        if merged.equippedTitle == nil,
           let serverEquipped = server.equippedTitle,
           merged.unlockedTitles.contains(serverEquipped) {
            merged.equippedTitle = serverEquipped
        }

        merged.keptVows = Array(
            unionById(local: local.keptVows, server: server.keptVows)
                .sorted { $0.completedAt < $1.completedAt }
                .suffix(100)
        )

        for (lane, count) in server.completionsByLane {
            merged.completionsByLane[lane] = max(merged.completionsByLane[lane] ?? 0, count)
        }

        merged.weeklyVowCompletionLedger = unionById(
            local: local.weeklyVowCompletionLedger,
            server: server.weeklyVowCompletionLedger
        ).sorted { $0.completedAt < $1.completedAt }

        merged.weeklyVowPenaltyLedger = Array(
            unionById(local: local.weeklyVowPenaltyLedger, server: server.weeklyVowPenaltyLedger)
                .sorted { $0.missedAt < $1.missedAt }
                .suffix(100)
        )

        return merged
    }

    /// Union with per-badge EARLIEST unlockedAt — the earlier timestamp is the
    /// true unlock moment, and a server-only badge (e.g. a streak peak that is
    /// not recomputable) always survives.
    static func mergedBadges(local: [String: Date], server: [String: Date]) -> [String: Date] {
        var merged = local
        for (id, serverDate) in server {
            if let localDate = merged[id] {
                merged[id] = min(localDate, serverDate)
            } else {
                merged[id] = serverDate
            }
        }
        return merged
    }

    /// Union by stable id; on a collision the LOCAL entry wins.
    private static func unionById<T: Identifiable>(local: [T], server: [T]) -> [T] {
        var seen = Set(local.map(\.id))
        var result = local
        for item in server where !seen.contains(item.id) {
            seen.insert(item.id)
            result.append(item)
        }
        return result
    }

    // MARK: - Helpers

    /// Encode a Codable value to a Foundation JSON object (`[String: Any]`) so it
    /// can ride inside the `[String: Any]` field dict `DatabaseService.update`
    /// serializes with `JSONSerialization`.
    private static func jsonObject<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? encoder.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
