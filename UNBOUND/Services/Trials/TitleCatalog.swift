// UNBOUND/Services/Trials/TitleCatalog.swift
import Foundation

/// Maps TitleID → human-readable display name. 9 paths × 3 tiers = 27 Titles.
/// Naming is the spec-locked authoring scaffold; brand polish can tune later.
enum TitleCatalog {

    static func displayName(for id: TitleID) -> String {
        switch (id.path, id.tier) {
        // Axis Titles
        case (.axis(.power), .bronze):           return "Power Initiate"
        case (.axis(.power), .silver):           return "Power Sovereign"
        case (.axis(.power), .gold):             return "Power Ascendant"
        case (.axis(.agility), .bronze):         return "Vitality Initiate"
        case (.axis(.agility), .silver):         return "Vitality Warden"
        case (.axis(.agility), .gold):           return "Vitality Ascendant"
        case (.axis(.control), .bronze):         return "Control Initiate"
        case (.axis(.control), .silver):         return "Control Master"
        case (.axis(.control), .gold):           return "Control Ascendant"
        case (.axis(.endurance), .bronze):       return "Endurance Initiate"
        case (.axis(.endurance), .silver):       return "Endurance Pacer"
        case (.axis(.endurance), .gold):         return "Endurance Ascendant"
        case (.axis(.mobility), .bronze):        return "Mobility Initiate"
        case (.axis(.mobility), .silver):        return "Mobility Warden"
        case (.axis(.mobility), .gold):          return "Mobility Ascendant"
        case (.axis(.explosiveness), .bronze):   return "Explosiveness Initiate"
        case (.axis(.explosiveness), .silver):   return "Explosiveness Striker"
        case (.axis(.explosiveness), .gold):     return "Explosiveness Ascendant"
        // Binding Vow kind Titles
        case (.cardKind(.ember), .bronze):       return "Quiet Oathkeeper"
        case (.cardKind(.ember), .silver):       return "Open Gate Warden"
        case (.cardKind(.ember), .gold):         return "Still Heart Ascendant"
        case (.cardKind(.overdrive), .bronze):   return "Limit Break Spark"
        case (.cardKind(.overdrive), .silver):   return "Redline Vessel"
        case (.cardKind(.overdrive), .gold):     return "Heavenbreaker"
        case (.cardKind(.apex), .bronze):        return "No-Retreat Striver"
        case (.cardKind(.apex), .silver):        return "Final Set Conqueror"
        case (.cardKind(.apex), .gold):          return "Ascension Bound"
        }
    }

    /// All 27 TitleIDs in deterministic order.
    static let all: [TitleID] = {
        var result: [TitleID] = []
        for axis in AttributeKey.allCases {
            for tier in TitleID.Tier.allCases {
                result.append(TitleID(path: .axis(axis), tier: tier))
            }
        }
        for kind in WeeklyVowKind.allCases {
            for tier in TitleID.Tier.allCases {
                result.append(TitleID(path: .cardKind(kind), tier: tier))
            }
        }
        return result
    }()
}
