import Foundation

// MARK: - SkillCluster
//
// The regions of the unified skill graph. Every node in the graph
// belongs to exactly one cluster.
//
// Phase 2 (program-redesign) taxonomy:
//   • Heavy Lifting removed — lifting lives in scan + program layer.
//   • Handbalance removed as a separate landing concept. Handstand owns the
//     inversion path directly; planche owns the arm-balance-to-planche chain.
//
// Landing-screen trees: Pull, Push, Legs, Core, Handstand, Planche.
// Conditioning content remains available to workout/routine systems, but is
// not currently exposed as a skill-tree branch.

enum SkillCluster: String, Codable, CaseIterable, Sendable, Identifiable {
    case legDominance       = "leg_dominance"
    case pullingPower       = "pulling_power"
    case calisthenicControl = "calisthenic_control"
    case handstand          = "handstand"
    case handstandPushup    = "handstand_pushup"
    case oneArmHandstand    = "one_arm_handstand"
    case planche            = "planche"
    case coreLever          = "core_lever"
    case conditioning       = "conditioning"

    var id: String { rawValue }

    /// Short code used as node-ID prefix (e.g. "pp.muscle-up").
    var slug: String {
        switch self {
        case .legDominance:       return "ld"
        case .pullingPower:       return "pp"
        case .calisthenicControl: return "cal"
        case .handstand:          return "hs"
        case .handstandPushup:    return "hspu"
        case .oneArmHandstand:    return "oah"
        case .planche:            return "pl"
        case .coreLever:          return "cl"
        case .conditioning:       return "co"
        }
    }

    var displayName: String {
        switch self {
        case .legDominance:       return "Legs"
        case .pullingPower:       return "Pull"
        case .calisthenicControl: return "Push"
        case .handstand:          return "Handstand"
        case .handstandPushup:    return "Handstand Pushup"
        case .oneArmHandstand:    return "One-Arm Handstand"
        case .planche:            return "Planche"
        case .coreLever:          return "Core"
        case .conditioning:       return "Endurance"
        }
    }

    var tagline: String {
        switch self {
        case .legDominance:       return "Pistol · shrimp · Nordic"
        case .pullingPower:       return "Pull-up → muscle-up"
        case .calisthenicControl: return "Dip → HSPU · pressing strength"
        case .handstand:          return "Balance upside down"
        case .handstandPushup:    return "Press your bodyweight overhead"
        case .oneArmHandstand:    return "The final balance — one hand"
        case .planche:            return "Tuck → straddle → full planche"
        case .coreLever:          return "Hollow · L-sit · dragon flag"
        case .conditioning:       return "Carries · hangs · grip"
        }
    }

    /// SF Symbol glyph for tile + detail header.
    var glyph: String {
        switch self {
        case .legDominance:       return "figure.walk"
        case .pullingPower:       return "figure.climbing"
        case .calisthenicControl: return "figure.strengthtraining.functional"
        case .handstand:          return "figure.gymnastics"
        case .handstandPushup:    return "figure.strengthtraining.functional"
        case .oneArmHandstand:    return "figure.mind.and.body"
        case .planche:            return "figure.highintensity.intervaltraining"
        case .coreLever:          return "figure.core.training"
        case .conditioning:       return "flame.fill"
        }
    }

    /// If set, this cluster stays LOCKED until the listed cluster's keystone
    /// node(s) are `.achieved` or `.mastered`. Used to stage the Handstand →
    /// HSPU → One-Arm Handstand progression.
    var requiresClusterKeystone: SkillCluster? {
        switch self {
        case .handstandPushup: return .handstand
        case .oneArmHandstand: return .handstandPushup
        default:               return nil
        }
    }
}
