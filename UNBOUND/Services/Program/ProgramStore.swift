import Foundation

/// Network seam for the program store. `SupabaseProgramService` conforms.
protocol ProgramRemote: Sendable {
    /// Upsert the program + patch `current_program_id`. True iff it reached
    /// the server (a local-dev/unauth fallback also counts as persisted).
    func persist(_ program: TrainingProgram, userId: String) async -> Bool
    func fetchProgram(id: String) async throws -> TrainingProgram
}

/// The single on-device owner of the active TrainingProgram. Local-first:
/// the cache file is the fast-read source AND the edit surface; remote is
/// sync/backup + the monthly-replacement source. Mirrors WorkoutDraftStore.
@MainActor
final class ProgramStore {
    static let shared = ProgramStore()

    private let fileURL: URL
    private let remote: ProgramRemote
    private(set) var program: TrainingProgram?

    private struct Cached: Codable {
        var program: TrainingProgram
        var userId: String
        var dirty: Bool
        var syncedAt: Date?
    }

    init(directory: URL? = nil, remote: ProgramRemote = SupabaseProgramService.shared) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("program-store.json")
        self.remote = remote
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

    func adopt(_ program: TrainingProgram, userId: String) {
        self.program = program
        writeCache(Cached(program: program, userId: userId, dirty: false, syncedAt: Date()))
    }

    func save(_ program: TrainingProgram, userId: String) async {
        self.program = program
        writeCache(Cached(program: program, userId: userId, dirty: true, syncedAt: nil))
        if await remote.persist(program, userId: userId) {
            writeCache(Cached(program: program, userId: userId, dirty: false, syncedAt: Date()))
        }
    }

    func revalidate(userId: String, expectedProgramId: String) async {
        if program == nil { _ = loadLocal(userId: userId) }
        if let p = program, p.id == expectedProgramId { return }
        await flushIfDirty(userId: userId)
        if let fresh = try? await remote.fetchProgram(id: expectedProgramId) {
            adopt(fresh, userId: userId)
        }
    }

    func flushIfDirty(userId: String) async {
        guard let c = readCache(), c.userId == userId, c.dirty else { return }
        if await remote.persist(c.program, userId: userId) {
            writeCache(Cached(program: c.program, userId: userId,
                              dirty: false, syncedAt: Date()))
        }
    }

    func clear() {
        program = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}
