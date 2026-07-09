import Foundation

@MainActor
final class ProgressionStateStore {
    static let shared = ProgressionStateStore()
    private let database: any DatabaseServiceProtocol
    private let logger = LoggingService.shared
    private let collection = "progression_states"

    init(database: any DatabaseServiceProtocol = SyncedDatabase.shared) {
        self.database = database
    }

    func fetchAll(userId: String) async -> [ProgressionState] {
        do {
            let states: [ProgressionState] = try await database.query(
                collection: collection,
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
        return try? await database.read(collection: collection, documentId: id)
    }

    func save(_ state: ProgressionState) async {
        try? await database.create(state, collection: collection, documentId: state.id)
    }

    /// Like `save`, but surfaces the write failure instead of swallowing it.
    /// Callers that report success to the user (e.g. applying a deload) need to
    /// know whether the row actually landed. Idempotent: the document id is
    /// `userId:exerciseKey`, so a retry overwrites the same row in place.
    func persist(_ state: ProgressionState) async throws {
        try await database.create(state, collection: collection, documentId: state.id)
    }

    func delete(_ state: ProgressionState) async {
        try? await database.delete(collection: collection, documentId: state.id)
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
