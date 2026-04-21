import Foundation

struct ExercisePreferenceSummary {
    let available: [ExercisePreference]
    let substitute: [ExercisePreference]
    let avoid: [ExercisePreference]

    var formattedForPrompt: String {
        var parts: [String] = []
        if !available.isEmpty {
            parts.append("AVAILABLE: \(available.map(\.displayName).joined(separator: ", "))")
        }
        if !substitute.isEmpty {
            parts.append("SUBSTITUTE ONLY: \(substitute.map(\.displayName).joined(separator: ", "))")
        }
        if !avoid.isEmpty {
            parts.append("AVOID (never program): \(avoid.map(\.displayName).joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }
}

protocol ExercisePreferenceServiceProtocol: Sendable {
    func fetchPreferences(userId: String) async throws -> [ExercisePreference]
    func setPreference(_ preference: ExercisePreference) async throws
    func deletePreference(id: String) async throws
    func getPreferenceSummary(userId: String) async throws -> ExercisePreferenceSummary
}
