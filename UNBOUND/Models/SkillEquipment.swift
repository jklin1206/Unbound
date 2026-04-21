import Foundation

// MARK: - SkillEquipment
//
// Every skill node declares the equipment it needs. SkillEquipment is NEVER
// used to hide or lock nodes — the user always sees everything. SkillEquipment
// is badge metadata (visible on the node) + profile info (feeds the
// "what to work on next" recommender and the adaptive program).

enum SkillEquipment: String, Codable, CaseIterable, Sendable, Identifiable {
    case bodyweight
    case pullupBar
    case gymnasticRings
    case barbell
    case dumbbells
    case parallettes
    case kettlebell
    case sled
    case rower
    case elevatedSurface

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyweight:       return "Bodyweight"
        case .pullupBar:        return "Pullup bar"
        case .gymnasticRings:   return "Gymnastic rings"
        case .barbell:          return "Barbell + plates"
        case .dumbbells:        return "Dumbbells"
        case .parallettes:      return "Parallettes"
        case .kettlebell:       return "Kettlebell"
        case .sled:             return "Sled"
        case .rower:            return "Rower"
        case .elevatedSurface:  return "Bench / box"
        }
    }

    /// SF Symbol for the equipment badge.
    var glyph: String {
        switch self {
        case .bodyweight:       return "figure.stand"
        case .pullupBar:        return "line.horizontal.3"
        case .gymnasticRings:   return "circle.grid.2x1"
        case .barbell:          return "dumbbell.fill"
        case .dumbbells:        return "dumbbell"
        case .parallettes:      return "parkingsign"
        case .kettlebell:       return "drop.fill"
        case .sled:             return "arrow.down.to.line"
        case .rower:            return "figure.rower"
        case .elevatedSurface:  return "square.stack.fill"
        }
    }
}

// MARK: - UserSkillEquipmentProfile
//
// Lightweight user-settable profile of what equipment they have access
// to. Feeds the recommender; never blocks node visibility.

struct UserSkillEquipmentProfile: Codable, Sendable {
    var hasFullGym: Bool
    var available: Set<SkillEquipment>

    static let `default` = UserSkillEquipmentProfile(
        hasFullGym: false,
        available: [.bodyweight, .pullupBar]
    )

    func has(_ e: SkillEquipment) -> Bool {
        hasFullGym || available.contains(e) || e == .bodyweight
    }

    /// True if every required equipment for a node is available to the user.
    func covers(_ required: [SkillEquipment]) -> Bool {
        required.allSatisfy { has($0) }
    }
}
