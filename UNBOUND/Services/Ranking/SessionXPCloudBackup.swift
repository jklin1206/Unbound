import Foundation

// MARK: - SessionXPBackup

/// The cloud snapshot mirrored onto the `users` doc: the per-user session
/// record (streak, longest streak, totals) plus the bonus ledger, as ONE
/// jsonb value under the `streakBackup` field so the record and its ledger
/// can never drift apart across two partially applied patches.
struct SessionXPBackup: Codable, Equatable, Sendable {
    var record: SessionXPRecord
    var bonuses: [SessionXPBonusEntry]
}

// MARK: - SessionXPBackuping

/// Injection seam for `SessionXPService`: the production singleton wires the
/// real cloud mirror; test-constructed services get a fake (or nil) so unit
/// tests never touch the outbox / SyncedDatabase.
protocol SessionXPBackuping: Sendable {
    func backup(record: SessionXPRecord, bonuses: [SessionXPBonusEntry], userId: String)
}

// MARK: - SessionXPCloudBackup

/// Cloud mirror for the session-XP streak record.
///
/// The streak, longest streak, and total-session count live in device
/// UserDefaults (`SessionXPService`); without a cloud copy a reinstall
/// silently zeroes a signed-in user's streak. This service patches the record
/// + bonus ledger onto the synced `users` doc through the SAME offline-safe
/// choke point every other users-doc write takes (`SyncedDatabase` -> outbox
/// -> `sync_merge_row` field-level merge), so an offline write is retried by
/// the outbox and a concurrent edit to another column of the row survives.
/// Local UserDefaults stays the source of truth; this is a best-effort mirror
/// whose failures are logged, never silenced.
final class SessionXPCloudBackup: SessionXPBackuping, @unchecked Sendable {
    static let shared = SessionXPCloudBackup()

    private let database: any DatabaseServiceProtocol
    private let logger: LoggingService

    /// Serializes the patch writes: each backup call captures its snapshot
    /// synchronously and chains behind the previous write, so two rapid
    /// sessions can never land out of order and let a stale snapshot
    /// overwrite a newer one (locally or via the FIFO outbox).
    private let tailLock = NSLock()
    private var tail: Task<Void, Never>?

    /// ISO-8601 dates to match both `JSONDecoder.unbound` (local decode) and
    /// `UnboundSupabase.dbDecoder` (remote decode), so `lastSessionDate` /
    /// bonus dates round-trip identically through UserDefaults and the jsonb
    /// column.
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

    func backup(record: SessionXPRecord, bonuses: [SessionXPBonusEntry], userId: String) {
        guard let encoded = Self.jsonObject(SessionXPBackup(record: record, bonuses: bonuses)) else {
            logger.log(
                "Session XP cloud backup: failed to encode streak record",
                level: .error,
                context: ["userId": userId]
            )
            return
        }
        enqueuePatch(field: "streakBackup", value: encoded, userId: userId)
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

    /// Patch the streak field onto the `users` doc. `id` travels in the
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
                "Session XP cloud backup failed for \(field): \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    // MARK: - Restore path

    /// Seed the local store from a fetched server profile. When no local
    /// record exists, adopt the cloud copy wholesale (re-keyed to `userId`);
    /// when both exist, apply the SAME never-regressing merge the sign-in
    /// migration uses (`SessionXPRecord.merging`) with the cloud copy as the
    /// legacy side — totals and longest streak keep the better of both, and a
    /// long-lapsed cloud streak never resurrects over an active local run.
    /// Bonuses are display history, not currency: adopted only into an empty
    /// local ledger, otherwise local wins. Safe to run every launch — nothing
    /// is written when nothing changes.
    @MainActor
    func seedLocalStores(
        from profile: UserProfile,
        userId: String,
        service: SessionXPService? = nil
    ) {
        guard let cloud = profile.streakBackup else { return }
        let service = service ?? .shared

        let cloudRecord = cloud.record.rekeyed(to: userId)
        if let local = service.storedRecord(userId: userId) {
            let merged = SessionXPRecord.merging(legacy: cloudRecord, target: local)
            if merged != local {
                service.restore(merged)
            }
        } else {
            service.restore(cloudRecord)
        }

        if !cloud.bonuses.isEmpty, service.storedBonusLedger(userId: userId).isEmpty {
            service.restoreBonusLedger(cloud.bonuses, userId: userId)
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
