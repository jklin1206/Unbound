import Foundation

final class ExercisePreferenceService: ExercisePreferenceServiceProtocol, @unchecked Sendable {
    static let shared = ExercisePreferenceService()
    private let database: any DatabaseServiceProtocol = SyncedDatabase.shared
    private let logger = LoggingService.shared
    private var cache: [ExercisePreference]?

    private init() {}

    func fetchPreferences(userId: String) async throws -> [ExercisePreference] {
        if let cache { return cache }
        let prefs: [ExercisePreference] = try await database.query(
            collection: "exercisePreferences", field: "userId", isEqualTo: userId,
            orderBy: "updatedAt", descending: true, limit: nil
        )
        cache = prefs
        return prefs
    }

    func setPreference(_ preference: ExercisePreference) async throws {
        try await database.create(preference, collection: "exercisePreferences", documentId: preference.id)
        cache = nil
        logger.log("Exercise preference set: \(preference.displayName) -> \(preference.status.rawValue)", level: .info)
    }

    func deletePreference(id: String) async throws {
        try await database.delete(collection: "exercisePreferences", documentId: id)
        cache = nil
    }

    func getPreferenceSummary(userId: String) async throws -> ExercisePreferenceSummary {
        let prefs = try await fetchPreferences(userId: userId)
        return ExercisePreferenceSummary(
            available: prefs.filter { $0.status == .available },
            substitute: prefs.filter { $0.status == .substitute },
            avoid: prefs.filter { $0.status == .avoid }
        )
    }
}
