import Foundation

/// Durable, single-device FIFO of pending changes. Persisted as one JSON
/// array via atomic write. Coalesces by (collection, docId) so the queue
/// stays bounded regardless of edit volume. @MainActor for serialized access.
@MainActor
final class OutboxStore {
    static let shared = OutboxStore()

    private let pendingURL: URL
    private let deadletterURL: URL
    private var pending: [OutboxEntry] = []
    private var dead: [OutboxEntry] = []

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.pendingURL = base.appendingPathComponent("outbox.json")
        self.deadletterURL = base.appendingPathComponent("outbox-deadletter.json")
        self.pending = (try? JSONDecoder().decode([OutboxEntry].self,
                        from: Data(contentsOf: pendingURL))) ?? []
        self.dead = (try? JSONDecoder().decode([OutboxEntry].self,
                     from: Data(contentsOf: deadletterURL))) ?? []
    }

    var pendingCount: Int { pending.count }

    func enqueue(_ entry: OutboxEntry) {
        if let i = pending.firstIndex(where: {
            $0.collection == entry.collection && $0.docId == entry.docId
        }) {
            pending[i] = entry
        } else {
            pending.append(entry)
        }
        persistPending()
    }

    func peekBatch(limit: Int) -> [OutboxEntry] {
        Array(pending.prefix(limit))
    }

    func ack(_ ids: [UUID]) {
        let set = Set(ids)
        pending.removeAll { set.contains($0.id) }
        persistPending()
    }

    func recordFailure(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[i].attempt += 1
        persistPending()
    }

    func moveToDeadletter(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
        dead.append(pending.remove(at: i))
        persistPending()
        try? JSONEncoder().encode(dead).write(to: deadletterURL, options: .atomic)
    }

    private func persistPending() {
        try? JSONEncoder().encode(pending).write(to: pendingURL, options: .atomic)
    }
}
