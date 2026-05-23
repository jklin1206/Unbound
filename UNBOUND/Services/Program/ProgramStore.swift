import Foundation

/// Network seam for the program store. `SupabaseProgramService` conforms.
protocol ProgramRemote: Sendable {
    /// Retained for source compatibility; ProgramStore no longer calls this
    /// (the outbox handles program push). Conformers may keep their impl.
    func persist(_ program: TrainingProgram, userId: String) async -> Bool
    func fetchProgram(id: String) async throws -> TrainingProgram
}

/// The single on-device owner of the active TrainingProgram. Local-first:
/// the cache file is the fast-read source AND the edit surface. Cloud sync
/// is now via the unified outbox (`save()` enqueues a program upsert + a
/// users.currentProgramId patch). `remote.fetchProgram` remains the
/// monthly-replacement / restore pull. The `dirty/syncedAt` fields in the
/// on-disk `Cached` struct are kept for backward decode compatibility but
/// no longer drive any logic — the outbox is the single "unsynced" source.
@MainActor
final class ProgramStore {
    static let shared = ProgramStore()

    private let fileURL: URL
    private let remote: ProgramRemote
    private let outbox: OutboxStore
    private(set) var program: TrainingProgram?

    private struct Cached: Codable {
        var program: TrainingProgram
        var userId: String
        var dirty: Bool
        var syncedAt: Date?
    }

    init(directory: URL? = nil,
         remote: ProgramRemote = SupabaseProgramService.shared,
         outbox: OutboxStore = .shared) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("program-store.json")
        self.remote = remote
        self.outbox = outbox
    }

    private func readCache() -> Cached? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Cached.self, from: data)
    }

    private func writeCache(_ c: Cached) {
        if let data = try? JSONEncoder().encode(c) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    @discardableResult
    func loadLocal(userId: String) -> TrainingProgram? {
        guard let c = readCache(), c.userId == userId else { return nil }
        program = c.program
        return c.program
    }

    /// Adopt a program received from the server (restore / rollover pull).
    /// Does NOT enqueue — it already exists remotely.
    func adopt(_ program: TrainingProgram, userId: String) {
        self.program = program
        writeCache(Cached(program: program, userId: userId, dirty: false, syncedAt: Date()))
    }

    /// Local-authoritative save: write cache, enqueue the program upsert and
    /// the user's currentProgramId patch. SyncEngine drains them later.
    func save(_ program: TrainingProgram, userId: String) async {
        self.program = program
        writeCache(Cached(program: program, userId: userId, dirty: false, syncedAt: Date()))

        if let json = try? JSONEncoder().encode(program) {
            outbox.enqueue(OutboxEntry(id: UUID(), userId: userId,
                collection: "programs", docId: program.id, op: .upsert,
                payloadJSON: json, enqueuedAt: Date(), attempt: 0))
        }
        if let patch = try? JSONSerialization.data(withJSONObject:
            ["id": userId, "current_program_id": program.id]) {
            outbox.enqueue(OutboxEntry(id: UUID(), userId: userId,
                collection: "users", docId: userId, op: .upsert,
                payloadJSON: patch, enqueuedAt: Date(), attempt: 0))
        }
        NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
    }

    /// Monthly-replacement / restore pull: if the expected program differs
    /// from local, fetch from the remote and adopt.
    func revalidate(userId: String, expectedProgramId: String) async {
        if program == nil { _ = loadLocal(userId: userId) }
        if let p = program, p.id == expectedProgramId { return }
        if let fresh = try? await remote.fetchProgram(id: expectedProgramId) {
            adopt(fresh, userId: userId)
        }
    }

    func clear() {
        program = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}
