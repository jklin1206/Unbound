import Foundation

protocol WorkingWeightServiceProtocol: Sendable {
    func fetchWeights(userId: String) async throws -> [WorkingWeight]
    func fetchWeight(userId: String, exerciseName: String) async throws -> WorkingWeight?
    func updateFromLog(_ log: WorkoutLog, userId: String) async throws
    func getProgressionSuggestion(for exerciseName: String, userId: String) async throws -> ProgressionSuggestion?
}
