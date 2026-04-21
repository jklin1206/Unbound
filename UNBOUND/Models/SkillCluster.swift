import Foundation

// MARK: - SkillCluster
//
// The six regions of the unified skill graph. Every node in the graph
// belongs to exactly one cluster. Clusters are the top-level navigation
// on the Skill Map — tap a cluster, drill into its mini-graph.

enum SkillCluster: String, Codable, CaseIterable, Sendable, Identifiable {
    case heavyLifting       = "heavy_lifting"
    case legDominance       = "leg_dominance"
    case pullingPower       = "pulling_power"
    case calisthenicControl = "calisthenic_control"
    case coreLever          = "core_lever"
    case conditioning       = "conditioning"

    var id: String { rawValue }

    /// Short code used as node-ID prefix (e.g. "hl.2x-deadlift").
    var slug: String {
        switch self {
        case .heavyLifting:       return "hl"
        case .legDominance:       return "ld"
        case .pullingPower:       return "pp"
        case .calisthenicControl: return "cal"
        case .coreLever:          return "cl"
        case .conditioning:       return "co"
        }
    }

    var displayName: String {
        switch self {
        case .heavyLifting:       return "Heavy Lifting"
        case .legDominance:       return "Leg Dominance"
        case .pullingPower:       return "Pulling Power"
        case .calisthenicControl: return "Calisthenic Control"
        case .coreLever:          return "Core & Lever"
        case .conditioning:       return "Conditioning"
        }
    }

    var tagline: String {
        switch self {
        case .heavyLifting:       return "Barbell multipliers — squat · DL · bench"
        case .legDominance:       return "Single-leg, variation, bodyweight legs"
        case .pullingPower:       return "Everything on the bar"
        case .calisthenicControl: return "Holds, pushups, planche, handstand"
        case .coreLever:          return "Dynamic core · levers"
        case .conditioning:       return "Carries · hangs · grip endurance"
        }
    }

    /// SF Symbol glyph for tile + detail header.
    var glyph: String {
        switch self {
        case .heavyLifting:       return "dumbbell.fill"
        case .legDominance:       return "figure.walk"
        case .pullingPower:       return "figure.climbing"
        case .calisthenicControl: return "figure.flexibility"
        case .coreLever:          return "figure.core.training"
        case .conditioning:       return "flame.fill"
        }
    }
}
