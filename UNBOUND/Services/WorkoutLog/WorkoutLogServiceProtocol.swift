import Foundation

protocol WorkoutLogServiceProtocol: Sendable {
    func updateLog(_ log: WorkoutLog) async throws
    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog]
    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog]
    func deleteLog(id: String) async throws
}

protocol WorkoutLogCompatibilityHistoryWriting: Sendable {
    /// Side-effect-free history write for routes that have already completed
    /// progression through TrainingCompletionService.
    func saveCompatibleHistoryLog(_ log: WorkoutLog) async throws
}
