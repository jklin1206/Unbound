import Foundation

final class WorkoutLogService: WorkoutLogServiceProtocol, WorkoutLogCompatibilityHistoryWriting, @unchecked Sendable {
    static let shared = WorkoutLogService()
    private let database = DatabaseService.shared

    private init() {}

    func saveCompatibleHistoryLog(_ log: WorkoutLog) async throws {
        // MIGRATION(Phase 9): compatibility-only history write. This preserves
        // old WorkoutLog readers without running the legacy progression cascade.
        try await database.create(log, collection: "workoutLogs", documentId: log.id)
    }

    func updateLog(_ log: WorkoutLog) async throws {
        let data = try JSONEncoder().encode(log)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        try await database.update(dict, collection: "workoutLogs", documentId: log.id)
    }

    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        if let programId {
            return try await database.query(
                collection: "workoutLogs", field: "userId", isEqualTo: userId,
                orderBy: "startedAt", descending: true, limit: nil
            ).filter { ($0 as WorkoutLog).programId == programId }
        }
        return try await database.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: nil
        )
    }

    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        try await database.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: limit
        )
    }

    func deleteLog(id: String) async throws {
        try await database.delete(collection: "workoutLogs", documentId: id)
    }
}
