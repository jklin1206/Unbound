import Foundation

struct SquadTitleID: Codable, Hashable, Sendable {
    enum Category: String, Codable, Sendable {
        case linkedSessions      // "The Pact"
        case squadStreak         // "The Streak"
        case collectiveAxis      // "The {Axis} Crew"
        case affinityTenure      // "{Axis} Pact"
    }

    let category: Category
    let axis: AttributeKey?     // only set for .collectiveAxis and .affinityTenure
    let tier: Int               // 1, 2, 3
}

// MARK: - Per-axis name mapping helper

extension SquadTitleID {
    /// Human-readable display name for this squad title.
    var displayName: String {
        switch category {
        case .linkedSessions:
            return "The Pact"
        case .squadStreak:
            return "The Streak"
        case .collectiveAxis:
            switch axis {
            case .power:         return "The Iron Crew"
            case .agility:       return "The Recovery Crew"
            case .control:       return "The Focused Crew"
            case .endurance:     return "The Long Haul Crew"
            case .mobility:      return "The Loose Crew"
            case .explosiveness: return "The Storm Crew"
            case nil:            return "The Crew"
            }
        case .affinityTenure:
            switch axis {
            case .power:         return "Power Pact"
            case .agility:       return "Vitality Pact"
            case .control:       return "Control Pact"
            case .endurance:     return "Endurance Pact"
            case .mobility:      return "Mobility Pact"
            case .explosiveness: return "Explosiveness Pact"
            case nil:            return "Pact"
            }
        }
    }
}
