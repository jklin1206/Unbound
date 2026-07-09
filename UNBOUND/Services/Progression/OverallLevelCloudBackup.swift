import Foundation

/// Cloud mirror for the overall level's XP ledger.
///
/// `OverallLevelProgress` lives in the local-only `overall_level_progress`
/// collection (`SyncCollectionMap.localOnlyCollections`); without a cloud copy
/// a reinstall silently resets a signed-in user's level to 0, re-locking every
/// rank gate behind its `minOverallLevel` floor. This service patches the whole
/// progress doc — total XP plus the processed-source receipts, so a restored
/// device can never double-ingest an already-counted log — onto the synced
/// `users` doc through the SAME offline-safe choke point every other users-doc
/// write takes (`SyncedDatabase` -> outbox -> `sync_merge_row` field-level
/// merge). Local stays the source of truth; this is a best-effort mirror whose
/// failures are logged, never silenced.
protocol OverallLevelBackuping: Sendable {
    func backup(_ progress: OverallLevelProgress, userId: String)
}

final class OverallLevelCloudBackup: OverallLevelBackuping, @unchecked Sendable {
    static let shared = OverallLevelCloudBackup()

    private let database: any DatabaseServiceProtocol
    private let logger: LoggingService

    /// Serializes the patch writes: each backup call captures its snapshot
    /// synchronously and chains behind the previous write, so two rapid ingests
    /// can never land out of order and let a stale snapshot overwrite a newer
    /// one (locally or via the FIFO outbox).
    private let tailLock = NSLock()
    private var tail: Task<Void, Never>?

    /// ISO-8601 dates to match both `DatabaseService` (local decode) and
    /// `UnboundSupabase.dbDecoder` (remote decode), so `updatedAt` round-trips
    /// identically through the local store and the jsonb column.
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

    func backup(_ progress: OverallLevelProgress, userId: String) {
        guard let encoded = Self.jsonObject(progress) else {
            logger.log(
                "Overall level cloud backup: failed to encode progress",
                level: .error,
                context: ["userId": userId]
            )
            return
        }
        enqueuePatch(field: "overallLevelBackup", value: encoded, userId: userId)
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

    /// Patch the backup field onto the `users` doc. `id` travels in the payload
    /// (the `sync_merge_row` ownership guard reads `p_full->>'id'`, and it is
    /// excluded from the SET clause server-side) so the write is valid even if
    /// this device has no local `users` doc yet.
    private func patch(field: String, value: Any, userId: String) async {
        do {
            try await database.update(
                ["id": userId, field: value],
                collection: "users",
                documentId: userId
            )
        } catch {
            logger.log(
                "Overall level cloud backup failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    // MARK: - Restore path

    /// Seed the local `overall_level_progress` doc from a fetched server
    /// profile. When no local doc exists, adopt the server copy wholesale; when
    /// one exists, keep whichever carries the HIGHER `totalXP` — XP is monotone,
    /// so a stale server copy can NEVER regress a locally-earned level. Writes
    /// only when the local doc actually changes; safe to run every launch.
    func seedLocalStores(from profile: UserProfile, userId: String) async {
        guard let server = profile.overallLevelBackup else { return }

        let local: OverallLevelProgress? = try? await database.read(
            collection: "overall_level_progress",
            documentId: userId
        )
        if let local, local.totalXP >= server.totalXP { return }

        // The doc must be keyed by the CURRENT userId (`id` derives from
        // `userId`), or the next ingest would load it here but persist it under
        // the stale id and fork the ledger. Re-key a payload carried over from
        // a migrated identity; the receipts still travel so nothing re-ingests.
        let adopted = server.userId == userId
            ? server
            : OverallLevelProgress(
                userId: userId,
                totalXP: server.totalXP,
                lastGainedXP: server.lastGainedXP,
                processedSourceLogIds: server.processedSourceLogIds,
                processedSourceRewards: server.processedSourceRewards,
                updatedAt: server.updatedAt
            )
        do {
            try await database.create(
                adopted,
                collection: "overall_level_progress",
                documentId: userId
            )
        } catch {
            logger.log(
                "Overall level cloud restore failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
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
