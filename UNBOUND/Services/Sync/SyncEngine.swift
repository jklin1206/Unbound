import Foundation

/// Drains the outbox to the remote and restores from it. Single-flight.
/// No timers, no polling — driven entirely by external triggers (Task 6).
@MainActor
final class SyncEngine {
    static let shared = SyncEngine(outbox: .shared,
                                   remote: SupabaseRemoteSync.shared,
                                   local: DatabaseService.shared,
                                   maxAttempts: 5,
                                   auth: AuthService.shared)

    private let outbox: OutboxStore
    private let remote: any RemoteSync
    private let local: any DatabaseServiceProtocol
    private let maxAttempts: Int
    private let auth: any AuthServiceProtocol
    private let logger = LoggingService.shared
    private var isFlushing = false

    init(outbox: OutboxStore, remote: any RemoteSync,
         local: any DatabaseServiceProtocol, maxAttempts: Int,
         auth: any AuthServiceProtocol = AuthService.shared) {
        self.outbox = outbox; self.remote = remote
        self.local = local; self.maxAttempts = maxAttempts
        self.auth = auth
    }

    func flush() async {
        guard !isFlushing else { return }
        guard let currentUserId = auth.currentUserId else {
            logger.log("Outbox flush refused: no authenticated user", level: .warning)
            return
        }

        isFlushing = true
        defer { isFlushing = false }

        // Identity-mismatched entries (e.g. anonymous pre-sign-in writes that
        // migration has since re-written under the new UID) are redundant and
        // can never flush. Dead-letter them so they stop starving the FIFO head
        // instead of `continue`-ing them back to the front every flush.
        var mismatched: [OutboxEntry] = []

        for entry in outbox.peekBatch(limit: 50) {
            guard canFlush(entry, currentUserId: currentUserId) else {
                mismatched.append(entry)
                continue
            }

            do {
                switch entry.op {
                case .upsert:
                    // Server-side atomic merge (bug #5): push the full document
                    // plus the fields this entry owns; Postgres merges under the
                    // row lock. No remote read, no client-side overlay.
                    try await remote.merge(collection: entry.collection,
                                           docId: entry.docId,
                                           fullJSON: entry.payloadJSON ?? Data(),
                                           changedFields: entry.changedFields)
                case .delete:
                    try await remote.delete(collection: entry.collection,
                                            docId: entry.docId)
                }
                outbox.ack([entry.id])
            } catch {
                outbox.recordFailure(entry.id)
                let attempts = outbox.peekBatch(limit: outbox.pendingCount)
                    .first { $0.id == entry.id }?.attempt ?? maxAttempts
                if attempts >= maxAttempts {
                    logger.log("Outbox entry deadlettered: \(entry.collection)/\(entry.docId): \(error)",
                               level: .error, context: ["docId": entry.docId])
                    outbox.moveToDeadletter(entry.id)
                }
            }
        }

        deadletterMismatched(mismatched, currentUserId: currentUserId)
    }

    /// Moves identity-mismatched entries to the dead-letter store and logs once
    /// per batch (never per entry). The dead-letter store preserves the full
    /// entries for forensics; the queue self-heals regardless of migration state.
    private func deadletterMismatched(_ entries: [OutboxEntry], currentUserId: String) {
        guard !entries.isEmpty else { return }
        for entry in entries {
            outbox.moveToDeadletter(entry.id)
        }
        logger.log(
            "Outbox dead-lettered \(entries.count) identity-mismatched entries",
            level: .info,
            context: [
                "reason": "entry userId does not match authenticated user",
                "currentUserId": currentUserId,
                "docIds": entries.map(\.docId)
            ]
        )
    }

    private func canFlush(_ entry: OutboxEntry, currentUserId: String) -> Bool {
        guard !entry.userId.isEmpty else { return false }
        return entry.userId.caseInsensitiveCompare(currentUserId) == .orderedSame
    }

    func restore(userId: String) async throws {
        for collection in SyncCollectionMap.syncedCollections {
            let docs = (try? await remote.pull(collection: collection, userId: userId)) ?? []
            for json in docs {
                guard let remoteEl = try? JSONDecoder().decode(JSONElement.self, from: json),
                      let dict = remoteEl.value as? [String: JSONElement],
                      let idEl = dict["id"]?.value as? String else { continue }
                let merged = await mergedRestoreDoc(remote: remoteEl,
                                                    collection: collection, docId: idEl,
                                                    userId: userId)
                try? await local.create(merged, collection: collection, documentId: idEl)
            }
        }
    }

    /// Merge-on-pull defense: overlay any locally-pending changed fields for
    /// this doc FROM the local copy ONTO the remote doc, so a pull never
    /// clobbers a field the user edited locally but hasn't synced yet. When
    /// there is no pending local edit, the remote doc is taken as-is.
    private func mergedRestoreDoc(remote remoteEl: JSONElement,
                                  collection: String, docId: String,
                                  userId: String) async -> JSONElement {
        let pendingFields = pendingChangedFields(collection: collection, docId: docId, userId: userId)
        guard !pendingFields.isEmpty,
              let localEl: JSONElement = try? await local.read(collection: collection,
                                                               documentId: docId) else {
            return remoteEl
        }
        return DocumentMerger.overlay(fields: pendingFields, from: localEl, onto: remoteEl)
    }

    /// Union of changedFields across all pending outbox upsert entries for a doc.
    private func pendingChangedFields(collection: String, docId: String, userId: String) -> [String] {
        var seen = Set<String>()
        return outbox.peekBatch(limit: outbox.pendingCount)
            .filter {
                $0.op == .upsert &&
                $0.userId.caseInsensitiveCompare(userId) == .orderedSame &&
                $0.collection == collection &&
                $0.docId == docId
            }
            .flatMap(\.changedFields)
            .filter { seen.insert($0).inserted }
    }
}
