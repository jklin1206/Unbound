import Foundation

/// Durable, single-device FIFO of pending changes. Persisted as one JSON
/// array via atomic write. Coalesces by (collection, docId) so the queue
/// stays bounded regardless of edit volume. Mutating operations stay on the
/// main actor for serialized access while construction remains nonisolated.
final class OutboxStore: @unchecked Sendable {
    static let shared = OutboxStore()

    private let pendingURL: URL
    private let deadletterURL: URL
    private var pending: [OutboxEntry] = []
    private var dead: [OutboxEntry] = []
    private let logger = LoggingService.shared

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.pendingURL = base.appendingPathComponent("outbox.json")
        self.deadletterURL = base.appendingPathComponent("outbox-deadletter.json")
        self.pending = Self.loadEntries(from: pendingURL)
        self.dead = Self.loadEntries(from: deadletterURL)
    }

    /// Decodes a persisted queue file. A missing file (first launch) is normal
    /// and starts empty silently; a present-but-unreadable file is a corruption
    /// signal - recovery is still to start empty, but never silently.
    private static func loadEntries(from url: URL) -> [OutboxEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            return try JSONDecoder().decode([OutboxEntry].self, from: Data(contentsOf: url))
        } catch {
            LoggingService.shared.log(
                "Outbox load failed; discarding unreadable queue file",
                level: .error,
                context: ["file": url.lastPathComponent, "error": String(describing: error)]
            )
            return []
        }
    }

    @MainActor
    var pendingCount: Int { pending.count }

    @MainActor
    var deadletterCount: Int { dead.count }

    @MainActor
    func enqueue(_ entry: OutboxEntry) {
        if let i = pending.firstIndex(where: {
            $0.userId == entry.userId && $0.collection == entry.collection && $0.docId == entry.docId
        }) {
            // Coalesce: the new payload supersedes the old, but changedFields
            // must UNION — otherwise a field edited only in the earlier entry
            // would no longer be merged on flush, reintroducing data loss.
            var merged = entry
            let union = pending[i].changedFields + entry.changedFields
            var seen = Set<String>()
            merged.changedFields = union.filter { seen.insert($0).inserted }
            pending[i] = merged
        } else {
            pending.append(entry)
        }
        persistPending()
    }

    @MainActor
    func peekBatch(limit: Int) -> [OutboxEntry] {
        Array(pending.prefix(limit))
    }

    @MainActor
    func ack(_ ids: [UUID]) {
        let set = Set(ids)
        pending.removeAll { set.contains($0.id) }
        persistPending()
    }

    @MainActor
    func recordFailure(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[i].attempt += 1
        persistPending()
    }

    @MainActor
    func moveToDeadletter(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
        dead.append(pending.remove(at: i))
        persistPending()
        persist(dead, to: deadletterURL)
    }

    @MainActor
    func clear() {
        pending = []
        dead = []
        try? FileManager.default.removeItem(at: pendingURL)
        try? FileManager.default.removeItem(at: deadletterURL)
    }

    @MainActor
    private func persistPending() {
        persist(pending, to: pendingURL)
    }

    /// Atomic write with one immediate retry. On repeated failure the in-memory
    /// queue is left untouched - it stays the source of truth, so a later
    /// successful persist recovers - and the failure is never swallowed.
    @MainActor
    private func persist(_ entries: [OutboxEntry], to url: URL) {
        do {
            try JSONEncoder().encode(entries).write(to: url, options: .atomic)
        } catch {
            logger.log(
                "Outbox persist failed; retrying once",
                level: .error,
                context: ["file": url.lastPathComponent, "error": String(describing: error)]
            )
            do {
                try JSONEncoder().encode(entries).write(to: url, options: .atomic)
            } catch {
                logger.log(
                    "Outbox persist retry failed; in-memory queue retained",
                    level: .error,
                    context: ["file": url.lastPathComponent, "error": String(describing: error)]
                )
            }
        }
    }
}
