import Foundation

/// Local-only v1 persistence for user-owned Saved Workouts.
///
/// Persistence choice: JSON-on-disk in Application Support/UNBOUND, matching
/// `ProgramStore` and `TrainingSessionDraftStore`. That keeps the v1 editor
/// fast/offline and leaves a clean migration path for later cloud sync.
final class SavedWorkoutStore {
    static let shared = SavedWorkoutStore()

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func all() -> [SavedWorkout] {
        readWorkouts().sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func get(id: UUID) -> SavedWorkout? {
        readWorkouts().first { $0.id == id }
    }

    func save(_ workout: SavedWorkout) {
        var current = readWorkouts()
        var saved = workout
        saved.title = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.sessionRole = SavedWorkout.normalizedSessionRole(workout.sessionRole)
        saved.updatedAt = Date()

        if let index = current.firstIndex(where: { $0.id == saved.id }) {
            saved.createdAt = current[index].createdAt
            if saved.order == 0 {
                saved.order = current[index].order
            }
            current[index] = saved
        } else {
            if saved.order == 0, !current.isEmpty {
                saved.order = (current.map(\.order).max() ?? 0) + 1
            }
            current.append(saved)
        }
        writeWorkouts(current)
    }

    func delete(id: UUID) {
        writeWorkouts(readWorkouts().filter { $0.id != id })
    }

    func clear() {
        try? fileManager.removeItem(at: fileURL)
    }

    private func readWorkouts() -> [SavedWorkout] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([SavedWorkout].self, from: data)) ?? []
    }

    private func writeWorkouts(_ workouts: [SavedWorkout]) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(workouts)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("SavedWorkoutStore save failed: \(error)")
            #endif
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        return base
            .appendingPathComponent("UNBOUND", isDirectory: true)
            .appendingPathComponent("saved-workouts.json")
    }
}
