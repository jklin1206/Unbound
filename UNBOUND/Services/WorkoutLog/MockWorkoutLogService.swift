import Foundation

final class MockWorkoutLogService: WorkoutLogServiceProtocol, @unchecked Sendable {
    var logs: [WorkoutLog] = []

    func saveLog(_ log: WorkoutLog) async throws { logs.append(log) }
    func updateLog(_ log: WorkoutLog) async throws {
        logs.removeAll { $0.id == log.id }
        logs.append(log)
    }
    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        if let programId { return logs.filter { $0.programId == programId } }
        return logs
    }
    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        Array(logs.prefix(limit))
    }
    func deleteLog(id: String) async throws { logs.removeAll { $0.id == id } }
}
