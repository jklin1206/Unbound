// UNBOUND/Models/Core/BuildClass.swift
import Foundation

// MARK: - BuildClass
//
// Anime-RPG class epithet derived from BuildIdentity — the earned-fantasy
// layer of the two-layer rule (BuildIdentity stays the grounded readout).
// Pure naming: no unlock, no progress, no mechanism. Stability comes from
// deriving off the HELD identity (`BuildClassStore`), never the live hex.

enum BuildClass: String, CaseIterable, Codable, Sendable {
    // Shape classes.
    case paragon        // balancedAthlete — the even hexagon
    case vagabond       // hybridAthlete — master of many disciplines

    // Specialist classes, one per axis.
    case titan          // power
    case monk           // control
    case ronin          // endurance
    case shinobi        // mobility
    case striker        // explosiveness
    case sage           // vitality

    // Hybrid classes, one per unordered axis pair.
    case berserker      // power + explosiveness
    case swordSaint     // power + control
    case juggernaut     // power + endurance
    case vanguard       // power + mobility
    case colossus       // power + vitality
    case bladeDancer    // control + explosiveness
    case assassin       // control + mobility
    case ascetic        // control + endurance
    case mystic         // control + vitality
    case phantom        // explosiveness + mobility
    case raider         // explosiveness + endurance
    case tempest        // explosiveness + vitality
    case wanderer       // endurance + mobility
    case immortal       // endurance + vitality
    case serpent        // mobility + vitality

    var displayName: String {
        L10n.string("buildClass.\(rawValue)", defaultValue: defaultDisplayName)
    }

    private var defaultDisplayName: String {
        switch self {
        case .paragon:     return "Paragon"
        case .vagabond:    return "Vagabond"
        case .titan:       return "Titan"
        case .monk:        return "Monk"
        case .ronin:       return "Ronin"
        case .shinobi:     return "Shinobi"
        case .striker:     return "Striker"
        case .sage:        return "Sage"
        case .berserker:   return "Berserker"
        case .swordSaint:  return "Sword Saint"
        case .juggernaut:  return "Juggernaut"
        case .vanguard:    return "Vanguard"
        case .colossus:    return "Colossus"
        case .bladeDancer: return "Blade Dancer"
        case .assassin:    return "Assassin"
        case .ascetic:     return "Ascetic"
        case .mystic:      return "Mystic"
        case .phantom:     return "Phantom"
        case .raider:      return "Raider"
        case .tempest:     return "Tempest"
        case .wanderer:    return "Wanderer"
        case .immortal:    return "Immortal"
        case .serpent:     return "Serpent"
        }
    }

    static func specialist(for axis: AttributeKey) -> BuildClass {
        switch axis {
        case .power:         return .titan
        case .control:       return .monk
        case .endurance:     return .ronin
        case .mobility:      return .shinobi
        case .explosiveness: return .striker
        case .vitality:      return .sage
        }
    }

    static func hybrid(_ a: AttributeKey, _ b: AttributeKey) -> BuildClass {
        // Unreachable for a well-formed .hybrid identity (primary != secondary).
        hybridClasses[[a, b]] ?? specialist(for: a)
    }

    private static let hybridClasses: [Set<AttributeKey>: BuildClass] = [
        [.power, .explosiveness]:         .berserker,
        [.power, .control]:               .swordSaint,
        [.power, .endurance]:             .juggernaut,
        [.power, .mobility]:              .vanguard,
        [.power, .vitality]:              .colossus,
        [.control, .explosiveness]:       .bladeDancer,
        [.control, .mobility]:            .assassin,
        [.control, .endurance]:           .ascetic,
        [.control, .vitality]:            .mystic,
        [.explosiveness, .mobility]:      .phantom,
        [.explosiveness, .endurance]:     .raider,
        [.explosiveness, .vitality]:      .tempest,
        [.endurance, .mobility]:          .wanderer,
        [.endurance, .vitality]:          .immortal,
        [.mobility, .vitality]:           .serpent
    ]
}

// MARK: - Derivation from BuildIdentity

extension BuildIdentity {
    var buildClass: BuildClass {
        switch shape {
        case .balancedAthlete: return .paragon
        case .hybridAthlete:   return .vagabond
        case .specialist, .lean:
            return BuildClass.specialist(for: primary ?? .power)
        case .hybrid:
            guard let primary, let secondary else { return .vagabond }
            return BuildClass.hybrid(primary, secondary)
        }
    }

    /// A lean identity is heading toward a class but hasn't settled — it
    /// reads as "Path of the Monk" instead of the full class name.
    var isClassPath: Bool { shape == .lean }

    var classDisplayName: String {
        guard isClassPath else { return buildClass.displayName }
        return L10n.format(
            "buildClass.pathFormat",
            defaultValue: "Path of the %@",
            buildClass.displayName
        )
    }
}
