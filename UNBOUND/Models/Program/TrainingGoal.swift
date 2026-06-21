import Foundation

/// The user's training objective — the single driver of rep ranges / sets,
/// replacing the per-day BlockType phase cycle. Derived from BuildIdentity's
/// programTemplateKey until an explicit onboarding choice is added (Plan 5).
enum TrainingGoal: String, Codable, Hashable, Sendable {
    case strength      // get stronger — low reps, heavy
    case hypertrophy   // build muscle — moderate reps
    case skill         // bodyweight skills — rep/hold targets

    static func from(programTemplateKey key: String) -> TrainingGoal {
        switch key {
        case "power":   return .strength
        case "control": return .skill
        default:        return .hypertrophy   // endurance / balanced / unknown
        }
    }
}
