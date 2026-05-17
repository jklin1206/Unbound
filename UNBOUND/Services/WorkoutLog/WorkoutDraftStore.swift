import Foundation

/// Local autosave of an in-progress workout. Survives app kill / network drop.
/// Supabase save still happens only on COMPLETE (via WorkoutLogService).
@MainActor
final class WorkoutDraftStore {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("workout-draft.json")
    }

    var hasDraft: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    func save(_ session: ActiveWorkoutSession) throws {
        let data = try JSONEncoder().encode(session.snapshot())
        try data.write(to: fileURL, options: .atomic)
    }

    func load() -> ActiveWorkoutSession? {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        else { return nil }
        return ActiveWorkoutSession(snapshot: snap)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
