import Foundation

final class MockWorkoutLogService: WorkoutLogServiceProtocol, WorkoutLogCompatibilityHistoryWriting, @unchecked Sendable {
    var logs: [WorkoutLog] = []
    private(set) var saveLogCallCount = 0
    private(set) var compatibleHistorySaveCallCount = 0

    func saveLog(_ log: WorkoutLog) async throws {
        saveLogCallCount += 1
        upsert(log)
    }
    func saveCompatibleHistoryLog(_ log: WorkoutLog) async throws {
        compatibleHistorySaveCallCount += 1
        upsert(log)
    }
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

    private func upsert(_ log: WorkoutLog) {
        logs.removeAll { $0.id == log.id }
        logs.append(log)
    }
}
