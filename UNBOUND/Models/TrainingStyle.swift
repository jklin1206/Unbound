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

    /// Archetype-driven default training style. The user can override in Settings.
    /// - shredded  (Saitama)  → bodyweight (calisthenic-coded)
    /// - leanCut   (Itadori)  → hybrid (athletic fighter mix)
    /// - vTaper    (Toji)     → freeWeights (compound lifts for wide frame)
    /// - heavyDuty (Todo)     → freeWeights (heroic mass)
    static func `default`(for archetype: Archetype) -> TrainingStyle {
        switch archetype {
        case .shredded: return .bodyweight
        case .leanCut: return .hybrid
        case .vTaper, .heavyDuty: return .freeWeights
        }
    }
}
