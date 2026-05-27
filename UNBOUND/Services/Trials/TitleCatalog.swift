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
        case (.axis(.vitality), .bronze):         return "Vitality Initiate"
        case (.axis(.vitality), .silver):         return "Vitality Warden"
        case (.axis(.vitality), .gold):           return "Vitality Ascendant"
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
        case (.cardKind(.ember), .bronze):       return "Steady Keeper"
        case (.cardKind(.ember), .silver):       return "Recovery Anchor"
        case (.cardKind(.ember), .gold):         return "Still Standard"
        case (.cardKind(.overdrive), .bronze):   return "Final Set"
        case (.cardKind(.overdrive), .silver):   return "Pressure Finisher"
        case (.cardKind(.overdrive), .gold):     return "Closer"
        case (.cardKind(.apex), .bronze):        return "Limit Tested"
        case (.cardKind(.apex), .silver):        return "Limit Breaker"
        case (.cardKind(.apex), .gold):          return "Limit Standard"
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
