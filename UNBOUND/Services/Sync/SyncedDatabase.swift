import Foundation

/// DatabaseServiceProtocol decorator: every mutation writes the local store
/// first (authoritative, instant) then enqueues an OutboxEntry. The single
/// choke point — a store cannot be "forgotten" by sync.
final class SyncedDatabase: DatabaseServiceProtocol, @unchecked Sendable {
    static let shared = SyncedDatabase(local: DatabaseService.shared,
                                       outbox: OutboxStore.shared)

    private let local: any DatabaseServiceProtocol
    private let outbox: OutboxStore

    init(local: any DatabaseServiceProtocol, outbox: OutboxStore) {
        self.local = local
        self.outbox = outbox
    }

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
        try await local.create(object, collection: collection, documentId: documentId)
        // A create authors the whole document, so every top-level field changed.
        let changed = (try? JSONEncoder().encode(object))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .map { Array($0.keys) } ?? []
        await enqueueUpsert(collection: collection, docId: documentId, changedFields: changed)
    }

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        try await local.read(collection: collection, documentId: documentId)
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        try await local.update(fields, collection: collection, documentId: documentId)
        await enqueueUpsert(collection: collection, docId: documentId,
                            changedFields: Array(fields.keys))
    }

    func delete(collection: String, documentId: String) async throws {
        try await local.delete(collection: collection, documentId: documentId)
        guard SyncCollectionMap.table(for: collection) != nil else { return }
        let entry = OutboxEntry(id: UUID(), userId: "", collection: collection,
                                docId: documentId, op: .delete, payloadJSON: nil,
                                enqueuedAt: Date(), attempt: 0)
        await MainActor.run {
            outbox.enqueue(entry)
            NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
        }
    }

    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any,
                           orderBy: String?, descending: Bool, limit: Int?) async throws -> [T] {
        try await local.query(collection: collection, field: field, isEqualTo: value,
                              orderBy: orderBy, descending: descending, limit: limit)
    }

    /// Re-reads the just-written doc as raw JSON so the enqueued payload is
    /// the full, merged document (correct even after a field-level `update`).
    /// `changedFields` records which top-level keys THIS edit touched so the
    /// SyncEngine can overlay only those onto the remote doc — concurrent edits
    /// to different fields then converge to the union instead of clobbering.
    private func enqueueUpsert(collection: String, docId: String,
                               changedFields: [String]) async {
        guard SyncCollectionMap.table(for: collection) != nil else { return }
        guard let el: JSONElement = try? await local.read(collection: collection,
                                                          documentId: docId),
              let payload = try? JSONEncoder().encode(el) else { return }
        let dict = el.value as? [String: JSONElement]
        let userId = (dict?["userId"]?.value as? String)
            ?? (dict?["id"]?.value as? String) ?? ""
        let entry = OutboxEntry(id: UUID(), userId: userId, collection: collection,
                                docId: docId, op: .upsert, payloadJSON: payload,
                                changedFields: changedFields,
                                enqueuedAt: Date(), attempt: 0)
        await MainActor.run {
            outbox.enqueue(entry)
            NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
        }
    }
}
