import Foundation

enum Archetype: String, CaseIterable, Identifiable {
    case vTaper = "v_taper"
    case heavyDuty = "heavy_duty"
    case shredded = "shredded"
    case leanCut = "lean_cut"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vTaper: return "V-TAPER"
        case .heavyDuty: return "HEAVYWEIGHT"
        case .shredded: return "SLEEPER"
        case .leanCut: return "SHREDDED"
        }
    }

    /// Short uppercase name used for UI titles, card labels, program names, etc.
    /// Single source of truth — replaces the per-view `archetypeName` switches.
    var shortName: String {
        switch self {
        case .vTaper: return "V-TAPER"
        case .heavyDuty: return "HEAVYWEIGHT"
        case .shredded: return "SLEEPER"
        case .leanCut: return "SHREDDED"
        }
    }

    /// Anime-character shorthand shown as a small mono label beneath the
    /// display name. Kept separate from `subtitle` (physique description) so
    /// character references stay clearly labeled as inspiration, not identity.
    var characterTagline: String {
        switch self {
        case .vTaper:    return "Toji build"
        case .leanCut:   return "Itadori build"
        case .heavyDuty: return "Todo build"
        case .shredded:  return "Saitama build"
        }
    }

    var subtitle: String {
        switch self {
        case .vTaper: return "Wide Frame Aesthetic"
        case .heavyDuty: return "Heroic Mass"
        case .shredded: return "Gymnast Precision"
        case .leanCut: return "Athletic Fighter"
        }
    }

    var tagline: String {
        switch self {
        case .vTaper: return "Own the room. Shoulders wide, waist carved, posture unshakable."
        case .heavyDuty: return "Take up space. Heroic frame, heavy numbers, presence at a glance."
        case .shredded: return "Precision over bulk. Compact, carved, in total control of your body."
        case .leanCut: return "Fast, proportional, capable. Built like a fighter who never stops."
        }
    }

    var animeReferences: [String] {
        switch self {
        case .vTaper:    return ["Toji Fushiguro", "Gojo Satoru", "Levi Ackerman"]
        case .heavyDuty: return ["Aoi Todo", "All Might", "Escanor"]
        case .shredded:  return ["Saitama", "Garou", "Killua Zoldyck"]
        case .leanCut:   return ["Itadori Yuji", "Sung Jin-Woo", "Bakugo Katsuki"]
        }
    }

    var primaryMetric: String {
        switch self {
        case .vTaper: return "Shoulder-to-waist ratio (target: 1.618)"
        case .heavyDuty: return "Cross-sectional mass index"
        case .shredded: return "Body fat percentage (target: 8-12%)"
        case .leanCut: return "Lean mass to bodyweight ratio"
        }
    }

    /// Expected filename for the archetype's hero silhouette PNG in
    /// Resources/BodyMap/. Files don't all exist yet — the loader falls
    /// back to `body_unbound_front.png` and then SF Symbols.
    var silhouetteAssetName: String {
        switch self {
        case .heavyDuty: return "archetype_heavyweight"
        case .leanCut:   return "archetype_shredded"
        case .vTaper:    return "archetype_vtaper"
        case .shredded:  return "archetype_sleeper"
        }
    }

    var priorityMuscleGroups: [MuscleGroup] {
        switch self {
        case .vTaper: return [.shoulders, .lats, .chest, .arms, .core]
        case .heavyDuty: return [.chest, .legs, .back, .shoulders, .arms, .traps]
        case .shredded: return [.core, .chest, .shoulders, .arms, .legs]
        case .leanCut: return [.core, .shoulders, .legs, .chest, .back]
        }
    }
}

// MARK: - Codable with legacy migration
//
// Retired archetype raw values are coerced at decode time so existing
// persisted profiles don't crash after a set trim.
extension Archetype: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Legacy migration: "brute" retired → map to heavyDuty, the
        // closest surviving mass/compound-focused archetype.
        let migrated = raw == "brute" ? Archetype.heavyDuty.rawValue : raw
        guard let archetype = Archetype(rawValue: migrated) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown archetype raw value: \(raw)"
            )
        }
        self = archetype
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
