// UNBOUND/Services/Squads/SquadTitleCatalog.swift
import Foundation

/// Maps SquadTitleID → human-readable display name.
/// 4 categories × (per-axis or nil) × 3 tiers.
enum SquadTitleCatalog {

    static func displayName(for id: SquadTitleID) -> String {
        let romanTier: String
        switch id.tier {
        case 1:  romanTier = "I"
        case 2:  romanTier = "II"
        case 3:  romanTier = "III"
        default: romanTier = "\(id.tier)"
        }

        switch id.category {
        case .linkedSessions:
            return "The Pact · \(romanTier)"

        case .squadStreak:
            return "The Streak · \(romanTier)"

        case .collectiveAxis:
            let baseName: String
            switch id.axis {
            case .power:         baseName = "The Iron Crew"
            case .vitality:       baseName = "The Recovery Crew"
            case .control:       baseName = "The Focused Crew"
            case .endurance:     baseName = "The Long Haul Crew"
            case .mobility:      baseName = "The Loose Crew"
            case .explosiveness: baseName = "The Storm Crew"
            case nil:            baseName = "The Crew"
            }
            return "\(baseName) · \(romanTier)"

        case .affinityTenure:
            let baseName: String
            switch id.axis {
            case .power:         baseName = "Power Pact"
            case .vitality:       baseName = "Vitality Pact"
            case .control:       baseName = "Control Pact"
            case .endurance:     baseName = "Endurance Pact"
            case .mobility:      baseName = "Mobility Pact"
            case .explosiveness: baseName = "Explosiveness Pact"
            case nil:            baseName = "Pact"
            }
            return "\(baseName) · \(romanTier)"
        }
    }

    /// All known SquadTitleIDs in deterministic order:
    /// linkedSessions (3) + squadStreak (3) + collectiveAxis (6×3=18) + affinityTenure (6×3=18) = 42 total
    static let allKnown: [SquadTitleID] = {
        var result: [SquadTitleID] = []

        // linkedSessions — no axis
        for tier in 1...3 {
            result.append(SquadTitleID(category: .linkedSessions, axis: nil, tier: tier))
        }

        // squadStreak — no axis
        for tier in 1...3 {
            result.append(SquadTitleID(category: .squadStreak, axis: nil, tier: tier))
        }

        // collectiveAxis — per axis
        for axis in AttributeKey.allCases {
            for tier in 1...3 {
                result.append(SquadTitleID(category: .collectiveAxis, axis: axis, tier: tier))
            }
        }

        // affinityTenure — per axis
        for axis in AttributeKey.allCases {
            for tier in 1...3 {
                result.append(SquadTitleID(category: .affinityTenure, axis: axis, tier: tier))
            }
        }

        return result
    }()
}
