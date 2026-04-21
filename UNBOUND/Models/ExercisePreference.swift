import Foundation

enum ExercisePreferenceStatus: String, Codable, CaseIterable {
    case available
    case substitute
    case avoid

    var displayName: String {
        switch self {
        case .available: return "Available"
        case .substitute: return "Substitute"
        case .avoid: return "Avoid"
        }
    }
}

struct ExercisePreference: Codable, Identifiable {
    let id: String
    let userId: String
    var exerciseName: String
    var displayName: String
    var status: ExercisePreferenceStatus
    var muscleGroups: [MuscleGroup]
    var substitutePreference: String?
    var notes: String?
    var updatedAt: Date
}
