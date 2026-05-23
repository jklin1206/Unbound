// UNBOUND/Models/TrainingStyle.swift
import Foundation

enum TrainingStyle: String, Codable, CaseIterable, Identifiable {
    case bodyweight        // calisthenics, minimal equipment
    case freeWeights       // dumbbells + barbell + bench
    case hybrid            // mix of bodyweight + weights
    case machines          // cable / machine / gym

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyweight: return "Bodyweight / Calisthenics"
        case .freeWeights: return "Free weights"
        case .hybrid: return "Hybrid"
        case .machines: return "Gym machines"
        }
    }

    /// Default training style for users without equipment preference.
    static var `default`: TrainingStyle { .hybrid }
}
