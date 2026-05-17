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
                    try await remote.upsert(collection: entry.collection,
                        docId: entry.docId, json: entry.payloadJSON ?? Data())
                case .delete:
                    try await remote.delete(collection: entry.collection,
                                            docId: entry.docId)
                }
                outbox.ack([entry.id])
            } catch {
                outbox.recordFailure(entry.id)
                // Re-read the updated attempt count after recordFailure
                let updatedAttempt = outbox.peekBatch(limit: 50)
                    .first { $0.id == entry.id }?.attempt ?? maxAttempts
                if updatedAttempt >= maxAttempts {
                    logger.log("Outbox entry deadlettered: \(entry.collection)/\(entry.docId): \(error)",
                               level: .error, context: ["docId": entry.docId])
                    outbox.moveToDeadletter(entry.id)
                } else {
                    break
                }
            }
        }
    }

    func restore(userId: String) async throws {
        for collection in SyncCollectionMap.syncedCollections {
            let docs = (try? await remote.pull(collection: collection, userId: userId)) ?? []
            for json in docs {
                guard let el = try? JSONDecoder().decode(JSONElement.self, from: json),
                      let dict = el.value as? [String: JSONElement],
                      let idEl = dict["id"]?.value as? String else { continue }
                try? await local.create(el, collection: collection, documentId: idEl)
            }
        }
    }
}
