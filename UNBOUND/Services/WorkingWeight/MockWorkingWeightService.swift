import Foundation

final class MockWorkingWeightService: WorkingWeightServiceProtocol, @unchecked Sendable {
    var weights: [WorkingWeight] = []

    func fetchWeights(userId: String) async throws -> [WorkingWeight] { weights }
    func fetchWeight(userId: String, exerciseName: String) async throws -> WorkingWeight? {
        weights.first { $0.exerciseName == exerciseName }
    }
    func updateFromLog(_ log: WorkoutLog, userId: String) async throws {}
    func getProgressionSuggestion(for exerciseName: String, userId: String) async throws -> ProgressionSuggestion? { .hold }
}
