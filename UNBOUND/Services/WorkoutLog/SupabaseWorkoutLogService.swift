import Foundation

// MARK: - SupabaseWorkoutLogService
//
// WorkoutLog persistence now flows through the unified offline outbox:
// SyncedDatabase writes the local store (authoritative, instant) and
// enqueues the cloud upsert/delete, which SyncEngine drains on
// foreground/reconnect. The previous ad-hoc "try Supabase / catch any error /
// fall back to local" logic is removed — the outbox is the single sync path.

final class SupabaseWorkoutLogService: WorkoutLogServiceProtocol, WorkoutLogCompatibilityHistoryWriting, @unchecked Sendable {
    static let shared = SupabaseWorkoutLogService()

    private let db = SyncedDatabase.shared

    private init() {}

    func saveCompatibleHistoryLog(_ log: WorkoutLog) async throws {
        // MIGRATION(Phase 9): compatibility-only history write. It keeps old
        // history/rendering paths alive without re-running legacy awards.
        try await db.create(log, collection: "workoutLogs", documentId: log.id)
    }

    // MARK: - updateLog

    func updateLog(_ log: WorkoutLog) async throws {
        // Upsert semantics: rewrite the doc locally + enqueue.
        try await db.create(log, collection: "workoutLogs", documentId: log.id)
    }

    // MARK: - fetchLogs

    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        let logs: [WorkoutLog] = try await db.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: nil
        )
        if let programId { return logs.filter { $0.programId == programId } }
        return logs
    }

    // MARK: - fetchRecentLogs

    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        try await db.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: limit
        )
    }

    // MARK: - deleteLog

    func deleteLog(id: String) async throws {
        try await db.delete(collection: "workoutLogs", documentId: id)
    }
}
