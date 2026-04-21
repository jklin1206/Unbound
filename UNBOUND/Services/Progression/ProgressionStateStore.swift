import Foundation

@MainActor
final class ProgressionStateStore {
    static let shared = ProgressionStateStore()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    func fetchAll(userId: String) async -> [ProgressionState] {
        do {
            let states: [ProgressionState] = try await database.query(
                collection: "progression_states",
                field: "userId",
                isEqualTo: userId,
                orderBy: "updatedAt",
                descending: true,
                limit: nil
            )
            return states
        } catch {
            logger.log("ProgressionStateStore fetchAll failed: \(error)", level: .warning)
            return []
        }
    }

    func fetch(userId: String, exerciseKey: String) async -> ProgressionState? {
        let id = "\(userId):\(exerciseKey.lowercased())"
        return try? await database.read(collection: "progression_states", documentId: id)
    }

    func save(_ state: ProgressionState) async {
        try? await database.create(state, collection: "progression_states", documentId: state.id)
    }

    func delete(_ state: ProgressionState) async {
        try? await database.delete(collection: "progression_states", documentId: state.id)
    }

    // MARK: Family state — chunk 2B

    func familyState(userId: String, family: String) async -> ProgressionFamilyState? {
        let id = "\(userId):\(family)"
        return try? await database.read(collection: "progression_families", documentId: id)
    }

    func saveFamilyState(_ state: ProgressionFamilyState) async {
        try? await database.create(state, collection: "progression_families", documentId: state.id)
    }

    func allFamilyStates(userId: String) async -> [ProgressionFamilyState] {
        do {
            let states: [ProgressionFamilyState] = try await database.query(
                collection: "progression_families",
                field: "userId",
                isEqualTo: userId,
                orderBy: "updatedAt",
                descending: true,
                limit: nil
            )
            return states
        } catch {
            logger.log("ProgressionStateStore allFamilyStates failed: \(error)", level: .warning)
            return []
        }
    }
}
