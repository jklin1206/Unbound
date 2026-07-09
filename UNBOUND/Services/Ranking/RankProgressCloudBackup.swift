import Foundation

/// Cloud mirror for the trial-confirmed rank + per-lift tiers.
///
/// The displayed rank (`OverallRankTrialStore`) and per-lift tiers
/// (`LiftTierService`) live in device UserDefaults; without a cloud copy a
/// reinstall or an orphaned identity migration silently resets a user's rank to
/// Initiate. This service patches those two values onto the synced `users` doc
/// through the SAME offline-safe choke point every other users-doc write takes
/// (`SyncedDatabase` -> outbox -> `sync_merge_row` field-level merge), so an
/// offline write is retried by the outbox and a concurrent edit to another
/// column of the row survives. Local UserDefaults stays the source of truth;
/// this is a best-effort mirror whose failures are logged, never silenced.
protocol RankProgressBackuping: Sendable {
    func backupTrials(_ progress: OverallRankTrialProgress, userId: String)
    func backupLiftTiers(_ tiers: [String: SkillTier], userId: String)
}

final class RankProgressCloudBackup: RankProgressBackuping, @unchecked Sendable {
    static let shared = RankProgressCloudBackup()

    private let database: any DatabaseServiceProtocol
    private let logger: LoggingService

    /// Serializes the patch writes: each backup call captures its snapshot
    /// synchronously and chains behind the previous write, so two rapid rank
    /// or tier advances can never land out of order and let a stale snapshot
    /// overwrite a newer one (locally or via the FIFO outbox).
    private let tailLock = NSLock()
    private var tail: Task<Void, Never>?

    /// ISO-8601 dates to match both `DatabaseService` (local decode) and
    /// `UnboundSupabase.dbDecoder` (remote decode), so the nested attempt dates
    /// round-trip identically through the local store and the jsonb column.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(
        database: any DatabaseServiceProtocol = SyncedDatabase.shared,
        logger: LoggingService = .shared
    ) {
        self.database = database
        self.logger = logger
    }

    // MARK: - Write path

    func backupTrials(_ progress: OverallRankTrialProgress, userId: String) {
        guard let encoded = Self.jsonObject(progress) else {
            logger.log(
                "Rank progress cloud backup: failed to encode trial progress",
                level: .error,
                context: ["userId": userId]
            )
            return
        }
        enqueuePatch(field: "overallRankTrials", value: encoded, userId: userId)
    }

    func backupLiftTiers(_ tiers: [String: SkillTier], userId: String) {
        let value = tiers.mapValues { $0.rawValue }
        enqueuePatch(field: "liftTiers", value: value, userId: userId)
    }

    /// Append this snapshot to the ordered write chain. The snapshot is taken
    /// at call time; the chain guarantees write order matches call order.
    private func enqueuePatch(field: String, value: Any, userId: String) {
        tailLock.lock()
        defer { tailLock.unlock() }
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            await self?.patch(field: field, value: value, userId: userId)
        }
    }

    /// Patch a single rank field onto the `users` doc. `id` travels in the
    /// payload (the `sync_merge_row` ownership guard reads `p_full->>'id'`, and
    /// it is excluded from the SET clause server-side) so the write is valid even
    /// if this device has no local `users` doc yet.
    private func patch(field: String, value: Any, userId: String) async {
        do {
            try await database.update(
                ["id": userId, field: value],
                collection: "users",
                documentId: userId
            )
        } catch {
            logger.log(
                "Rank progress cloud backup failed for \(field): \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    // MARK: - Restore path

    /// Seed the local stores from a fetched server profile. When a local store
    /// is empty, adopt the server copy wholesale; when it already has data, merge
    /// conservatively so a server copy can NEVER lower a local rank or tier
    /// (union of passed attempts / per-lift max tier). Safe to run every launch —
    /// it only ever raises local state.
    @MainActor
    func seedLocalStores(
        from profile: UserProfile,
        userId: String,
        trialStore: OverallRankTrialStore = .shared,
        liftTierStore: LiftTierService? = nil
    ) {
        let liftTierStore = liftTierStore ?? .shared
        if let serverProgress = profile.overallRankTrials {
            let local = trialStore.load(userId: userId)
            let merged = local.mergedNeverRegressing(with: serverProgress)
            if merged != local {
                trialStore.save(merged, userId: userId)
            }
        }

        if let serverTiers = profile.liftTiers {
            for (lift, serverTier) in serverTiers where serverTier > liftTierStore.tier(lift: lift, userId: userId) {
                liftTierStore.save(tier: serverTier, lift: lift, userId: userId)
            }
        }
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
