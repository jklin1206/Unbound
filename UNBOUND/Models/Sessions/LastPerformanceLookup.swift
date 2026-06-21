import Foundation

/// One set's last performance, read from prior WorkoutLog history.
struct LastSetPerformance: Codable, Equatable, Sendable {
    var weightKg: Double?
    var reps: Int?
    var durationSeconds: Int?   // holds/carries; nil for rep-based sets
    var performedAt: Date
}

/// Pure lookup of the most-recent prior performance per exercise, built from the
/// user's recent completed WorkoutLogs. `workingIndex` is 0-based over the entry's
/// non-warmup sets. No app/DB/UI dependencies — unit-testable in isolation.
struct LastPerformanceLookup {
    private struct Entry { let sets: [SetLog]; let performedAt: Date }
    private var byKey: [String: Entry] = [:]

    init(logs: [WorkoutLog], excludingLogId: String?) {
        let sorted = logs
            .filter { $0.id != excludingLogId }
            .sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
        for log in sorted {
            let when = log.completedAt ?? log.startedAt
            for entry in log.exerciseEntries where !entry.skipped {
                let working = entry.sets.filter { !$0.isWarmup }
                guard !working.isEmpty else { continue }
                for key in Self.keys(for: entry) where byKey[key] == nil {
                    byKey[key] = Entry(sets: working, performedAt: when)
                }
            }
        }
    }

    func lastWorkingSet(movementId: String?, exerciseName: String, workingIndex: Int) -> LastSetPerformance? {
        guard let entry = resolve(movementId: movementId, exerciseName: exerciseName),
              workingIndex >= 0, workingIndex < entry.sets.count else { return nil }
        let s = entry.sets[workingIndex]
        return LastSetPerformance(weightKg: s.weightKg, reps: s.reps,
                                  durationSeconds: s.durationSeconds, performedAt: entry.performedAt)
    }

    private func resolve(movementId: String?, exerciseName: String) -> Entry? {
        if let mid = movementId, let e = byKey["mid:" + mid] { return e }
        return byKey["name:" + Self.normalize(exerciseName)]
    }
    private static func keys(for entry: ExerciseLogEntry) -> [String] {
        var keys = ["name:" + normalize(entry.exerciseName)]
        if let mid = entry.movementId { keys.append("mid:" + mid) }
        return keys
    }
    private static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
