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
        case (.axis(.agility), .bronze):         return "Agility Initiate"
        case (.axis(.agility), .silver):         return "Agility Striker"
        case (.axis(.agility), .gold):           return "Agility Ascendant"
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
        // Weekly Vow kind Titles
        case (.cardKind(.ember), .bronze):       return "Ember Keeper"
        case (.cardKind(.ember), .silver):       return "Ember Warden"
        case (.cardKind(.ember), .gold):         return "Ember Ascendant"
        case (.cardKind(.overdrive), .bronze):   return "Overdrive Spark"
        case (.cardKind(.overdrive), .silver):   return "Overdrive Engine"
        case (.cardKind(.overdrive), .gold):     return "Overdrive Ascendant"
        case (.cardKind(.apex), .bronze):        return "Apex Striver"
        case (.cardKind(.apex), .silver):        return "Apex Conqueror"
        case (.cardKind(.apex), .gold):          return "Apex Ascendant"
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
