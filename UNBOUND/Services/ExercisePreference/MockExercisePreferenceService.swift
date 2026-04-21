import Foundation

final class MockExercisePreferenceService: ExercisePreferenceServiceProtocol, @unchecked Sendable {
    var preferences: [ExercisePreference] = []

    func fetchPreferences(userId: String) async throws -> [ExercisePreference] { preferences }

    func setPreference(_ preference: ExercisePreference) async throws {
        preferences.removeAll { $0.id == preference.id }
        preferences.append(preference)
    }

    func deletePreference(id: String) async throws {
        preferences.removeAll { $0.id == id }
    }

    func getPreferenceSummary(userId: String) async throws -> ExercisePreferenceSummary {
        ExercisePreferenceSummary(
            available: preferences.filter { $0.status == .available },
            substitute: preferences.filter { $0.status == .substitute },
            avoid: preferences.filter { $0.status == .avoid }
        )
    }
}
