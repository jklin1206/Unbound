import Foundation

protocol CustomExerciseStoreProtocol: Sendable {
    func all(userId: String) async -> [CustomExercise]
    func save(_ exercise: CustomExercise) async throws
    func delete(id: UUID, userId: String) async throws
}

final class CustomExerciseStore: CustomExerciseStoreProtocol, @unchecked Sendable {
    static let shared = CustomExerciseStore()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    func all(userId: String) async -> [CustomExercise] {
        do {
            let items: [CustomExercise] = try await database.query(
                collection: "custom_exercises",
                field: "userId",
                isEqualTo: userId,
                orderBy: "createdAt",
                descending: true,
                limit: nil
            )
            return items
        } catch {
            logger.log("CustomExerciseStore all failed: \(error)", level: .warning)
            return []
        }
    }

    func save(_ exercise: CustomExercise) async throws {
        try await database.create(
            exercise,
            collection: "custom_exercises",
            documentId: exercise.id.uuidString
        )
        logger.log("Custom exercise saved: \(exercise.displayName)", level: .info)
    }

    func delete(id: UUID, userId: String) async throws {
        try await database.delete(
            collection: "custom_exercises",
            documentId: id.uuidString
        )
    }
}

final class MockCustomExerciseStore: CustomExerciseStoreProtocol, @unchecked Sendable {
    var exercises: [CustomExercise] = []

    func all(userId: String) async -> [CustomExercise] {
        exercises.filter { $0.userId == userId }
    }

    func save(_ exercise: CustomExercise) async throws {
        exercises.removeAll { $0.id == exercise.id }
        exercises.append(exercise)
    }

    func delete(id: UUID, userId: String) async throws {
        exercises.removeAll { $0.id == id }
    }
}
