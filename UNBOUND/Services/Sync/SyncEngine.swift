import Foundation

/// Drains the outbox to the remote and restores from it. Single-flight.
/// No timers, no polling — driven entirely by external triggers (Task 6).
@MainActor
final class SyncEngine {
    static let shared = SyncEngine(outbox: .shared,
                                   remote: SupabaseRemoteSync.shared,
                                   local: DatabaseService.shared,
                                   maxAttempts: 5)

    private let outbox: OutboxStore
    private let remote: any RemoteSync
    private let local: any DatabaseServiceProtocol
    private let maxAttempts: Int
    private let logger = LoggingService.shared
    private var isFlushing = false

    init(outbox: OutboxStore, remote: any RemoteSync,
         local: any DatabaseServiceProtocol, maxAttempts: Int) {
        self.outbox = outbox; self.remote = remote
        self.local = local; self.maxAttempts = maxAttempts
    }

    func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        for entry in outbox.peekBatch(limit: 50) {
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
    }

    func restore(userId: String) async throws {
        for collection in SyncCollectionMap.syncedCollections {
            let docs = (try? await remote.pull(collection: collection, userId: userId)) ?? []
            for json in docs {
                guard let remoteEl = try? JSONDecoder().decode(JSONElement.self, from: json),
                      let dict = remoteEl.value as? [String: JSONElement],
                      let idEl = dict["id"]?.value as? String else { continue }
                let merged = await mergedRestoreDoc(remote: remoteEl,
                                                    collection: collection, docId: idEl)
                try? await local.create(merged, collection: collection, documentId: idEl)
            }
        }
    }

    /// Merge-on-pull defense: overlay any locally-pending changed fields for
    /// this doc FROM the local copy ONTO the remote doc, so a pull never
    /// clobbers a field the user edited locally but hasn't synced yet. When
    /// there is no pending local edit, the remote doc is taken as-is.
    private func mergedRestoreDoc(remote remoteEl: JSONElement,
                                  collection: String, docId: String) async -> JSONElement {
        let pendingFields = pendingChangedFields(collection: collection, docId: docId)
        guard !pendingFields.isEmpty,
              let localEl: JSONElement = try? await local.read(collection: collection,
                                                               documentId: docId) else {
            return remoteEl
        }
        return DocumentMerger.overlay(fields: pendingFields, from: localEl, onto: remoteEl)
    }

    /// Union of changedFields across all pending outbox upsert entries for a doc.
    private func pendingChangedFields(collection: String, docId: String) -> [String] {
        var seen = Set<String>()
        return outbox.peekBatch(limit: outbox.pendingCount)
            .filter { $0.op == .upsert && $0.collection == collection && $0.docId == docId }
            .flatMap(\.changedFields)
            .filter { seen.insert($0).inserted }
    }
}
