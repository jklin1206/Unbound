import Foundation

protocol WorkoutLogServiceProtocol: Sendable {
    func saveLog(_ log: WorkoutLog) async throws
    func updateLog(_ log: WorkoutLog) async throws
    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog]
    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog]
    func deleteLog(id: String) async throws
}
