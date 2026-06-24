import SwiftUI

// MARK: - SkillTreeSkin
//
// Cosmetic theme for the skill-tree UI. The skin changes the actual tree map:
// rails, rank bands, node fills, active rings, labels, chips, and share cards.
// Unlocks track the current named SkillTier ladder.

enum SkillTreeSkin: String, Codable, Sendable, CaseIterable, Identifiable {
    case violet
    case graphite
    case ember
    case jade
    case frost
    case gold
    case void
    case aurora
    case holographic
    case ascendant
    case chalk
    case blueprint
    case streetNeon = "street_neon"
    case inkDojo = "ink_dojo"
    case solarCircuit = "solar_circuit"
    case glassCircuit = "glass_circuit"
    case crystalCavern = "crystal_cavern"

    var id: String { rawValue }

    // MARK: Display

    var displayName: String {
        switch self {
        case .violet:       return "Violet"
        case .graphite:     return "Graphite"
        case .ember:        return "Ember"
        case .jade:         return "Jade"
        case .frost:        return "Frost"
        case .gold:         return "Gold"
        case .void:         return "Void"
        case .aurora:       return "Aurora"
        case .holographic:  return "Holographic"
        case .ascendant:    return "Ascendant"
        case .chalk:        return "Chalk Rails"
        case .blueprint:    return "Blueprint Rails"
        case .streetNeon:   return "Street Neon"
        case .inkDojo:      return "Ink Dojo"
        case .solarCircuit: return "Solar Circuit"
        case .glassCircuit: return "Glass Circuit"
        case .crystalCavern: return "Crystal Cavern"
        }
    }

    var description: String {
        switch self {
        case .violet:       return "The classic arc. Violet edges, cleaner shadows."
        case .graphite:     return "A low-noise tactical map with steel rails."
        case .ember:        return "Heat-map bands and orange active nodes."
        case .jade:         return "Green glass, calmer contrast, earned by Veteran."
        case .frost:        return "Cold cyan rails with a sharper technical read."
        case .gold:         return "Warm trophy lines for the crown-tier climb."
        case .void:         return "Deep-space surface with magenta impact seams."
        case .aurora:       return "Split teal, violet, and rose light across the tree."
        case .holographic:  return "Prismatic node glow for Unbound progress."
        case .ascendant:    return "White-gold apex styling for the top of the ladder."
        case .chalk:        return "A stripped-down map skin with chalk rails and quiet node glow."
        case .blueprint:    return "Cool drafting lines, icy nodes, and a crisp technical map read."
        case .streetNeon:   return "Cyan rails, magenta proven nodes, and sharper tree-map contrast."
        case .inkDojo:      return "Ink-wash banners, parchment banding, and restrained teal node light."
        case .solarCircuit: return "Amber active paths, teal glass nodes, and brighter circuit bands."
        case .glassCircuit: return "Premium teal glass nodes with gold active paths."
        case .crystalCavern: return "Violet crystal walls, cyan shard glow, and luminous cavern rails."
        }
    }

    var backgroundAssetName: String {
        "skill_tree_bg_\(rawValue)"
    }

    /// Minimum aggregate SkillTier required. Nil = unlocked by default.
    var unlockRequirement: SkillTier? {
        switch self {
        case .violet:       return nil
        case .graphite:     return nil
        case .ember:        return .novice
        case .jade:         return .veteran
        case .frost:        return .master
        case .gold:         return .vessel
        case .void:         return .ascendant
        case .aurora:       return .ascendant
        case .holographic:  return .unbound
        case .ascendant:    return .unbound
        case .chalk, .blueprint, .streetNeon, .inkDojo, .solarCircuit, .glassCircuit, .crystalCavern:
            return nil
        }
    }

    var unlockHintCopy: String {
        switch self {
        case .violet:       return "Always available."
        case .graphite:     return "Always available."
        case .ember:        return "Reach Novice aggregate tier."
        case .jade:         return "Reach Veteran aggregate tier."
        case .frost:        return "Reach Master aggregate tier."
        case .gold:         return "Reach Vessel aggregate tier."
        case .void:         return "Reach Ascendant aggregate tier."
        case .aurora:       return "Reach Ascendant aggregate tier."
        case .holographic:  return "Reach Unbound aggregate tier."
        case .ascendant:    return "Reach Unbound aggregate tier."
        case .chalk, .blueprint, .streetNeon, .inkDojo, .solarCircuit, .glassCircuit, .crystalCavern:
            return "Buy it in the Shop."
        }
    }

    var isShopExclusive: Bool {
        switch self {
        case .chalk, .blueprint, .streetNeon, .inkDojo, .solarCircuit, .glassCircuit, .crystalCavern:
            return true
        default:
            return false
        }
    }

    // MARK: Colors

    /// Static primary color for chips, rings, section headers. Holographic
    /// uses a base color here; animated gradients are provided separately.
    var primaryColor: Color {
        switch self {
        case .violet:       return Color.skinHex("9B5CFF")
        case .graphite:     return Color.skinHex("94A3B8")
        case .ember:        return Color.skinHex("FF7A3D")
        case .jade:         return Color.skinHex("55D487")
        case .frost:        return Color.skinHex("67E8F9")
        case .gold:         return Color.skinHex("FFC857")
        case .void:         return Color.skinHex("D946EF")
        case .aurora:       return Color.skinHex("5EEAD4")
        case .holographic:  return Color.skinHex("B5F3FE")
        case .ascendant:    return Color.skinHex("FFF3B0")
        case .chalk:        return Color.skinHex("CBD5E1")
        case .blueprint:    return Color.skinHex("38BDF8")
        case .streetNeon:   return Color.skinHex("22D3EE")
        case .inkDojo:      return Color.skinHex("EDE6D6")
        case .solarCircuit: return Color.skinHex("F97316")
        case .glassCircuit: return Color.skinHex("5EEAD4")
        case .crystalCavern: return Color.skinHex("A78BFA")
        }
    }

    /// Accent color used for cinematic glow and impact moments.
    var impactColor: Color {
        switch self {
        case .violet:       return Color.skinHex("FF5F7A")
        case .graphite:     return Color.skinHex("CBD5E1")
        case .ember:        return Color.skinHex("FFB86B")
        case .jade:         return Color.skinHex("B7F7C8")
        case .frost:        return Color.skinHex("A5F3FC")
        case .gold:         return Color.skinHex("FFD881")
        case .void:         return Color.skinHex("8B5CF6")
        case .aurora:       return Color.skinHex("F0ABFC")
        case .holographic:  return Color.skinHex("F5A4FF")
        case .ascendant:    return Color.skinHex("FFFFFF")
        case .chalk:        return Color.skinHex("2DD4BF")
        case .blueprint:    return Color.skinHex("E0F2FE")
        case .streetNeon:   return Color.skinHex("FF4FD8")
        case .inkDojo:      return Color.skinHex("2DD4BF")
        case .solarCircuit: return Color.skinHex("F6C95B")
        case .glassCircuit: return Color.skinHex("F6C95B")
        case .crystalCavern: return Color.skinHex("67E8F9")
        }
    }

    /// Rim color for share cards + rank glow halos. Kept distinct from
    /// primaryColor so cinematic glow can read against the base.
    var rimColor: Color {
        switch self {
        case .violet:       return primaryColor
        case .graphite:     return Color.skinHex("E2E8F0")
        case .ember:        return Color.skinHex("FED7AA")
        case .jade:         return Color.skinHex("86EFAC")
        case .frost:        return Color.skinHex("CFFAFE")
        case .gold:         return Color.skinHex("FFD881")
        case .void:         return Color.skinHex("C084FC")
        case .aurora:       return Color.skinHex("99F6E4")
        case .holographic:  return Color.skinHex("D8B4FE")
        case .ascendant:    return Color.skinHex("FFE8A3")
        case .chalk:        return Color.skinHex("F8FAFC")
        case .blueprint:    return Color.skinHex("BAE6FD")
        case .streetNeon:   return Color.skinHex("38BDF8")
        case .inkDojo:      return Color.skinHex("D84B3D")
        case .solarCircuit: return Color.skinHex("FDE68A")
        case .glassCircuit: return Color.skinHex("FDE68A")
        case .crystalCavern: return Color.skinHex("E9D5FF")
        }
    }

    /// High-contrast decal color for generated skill icon silhouettes.
    /// The asset provides alpha; the selected skin owns the color.
    var decalColor: Color {
        switch self {
        case .violet:       return Color.skinHex("C4B5FD")
        case .graphite:     return Color.skinHex("E2E8F0")
        case .ember:        return Color.skinHex("FED7AA")
        case .jade:         return Color.skinHex("BBF7D0")
        case .frost:        return Color.skinHex("ECFEFF")
        case .gold:         return Color.skinHex("FFF4D1")
        case .void:         return Color.skinHex("F5D0FE")
        case .aurora:       return Color.skinHex("CCFBF1")
        case .holographic:  return Color.skinHex("E0F2FE")
        case .ascendant:    return Color.skinHex("FFFBEA")
        case .chalk:        return Color.skinHex("E2E8F0")
        case .blueprint:    return Color.skinHex("E0F2FE")
        case .streetNeon:   return Color.skinHex("F0FDFA")
        case .inkDojo:      return Color.skinHex("F8FAFC")
        case .solarCircuit: return Color.skinHex("FFFBEB")
        case .glassCircuit: return Color.skinHex("FFFBEB")
        case .crystalCavern: return Color.skinHex("F5F3FF")
        }
    }

    var impactDecalColor: Color {
        switch self {
        case .graphite:     return Color.skinHex("F8FAFC")
        case .gold, .ascendant, .solarCircuit, .glassCircuit, .crystalCavern:
            return Color.skinHex("FFFFFF")
        default:
            return impactColor
        }
    }

    /// Base 3-stop gradient used behind nodes, hero cards, chips.
    var nodeGradient: LinearGradient {
        switch self {
        case .violet:
            return LinearGradient(
                colors: [primaryColor.opacity(0.30), Color.skinHex("16A3B8").opacity(0.12), impactColor.opacity(0.16)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .graphite:
            return LinearGradient(
                colors: [Color.skinHex("334155").opacity(0.55), Color.skinHex("0F172A").opacity(0.88)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .ember:
            return LinearGradient(
                colors: [Color.skinHex("FF7A3D").opacity(0.34), Color.skinHex("7F1D1D").opacity(0.32)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .jade:
            return LinearGradient(
                colors: [Color.skinHex("55D487").opacity(0.30), Color.skinHex("064E3B").opacity(0.28)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .frost:
            return LinearGradient(
                colors: [Color.skinHex("67E8F9").opacity(0.36), Color.skinHex("1E3A8A").opacity(0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [Color.skinHex("FFC857").opacity(0.45), Color.skinHex("B45309").opacity(0.25)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .void:
            return LinearGradient(
                colors: [Color.skinHex("18122B").opacity(0.92), Color.skinHex("D946EF").opacity(0.24)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .aurora:
            return LinearGradient(
                colors: [Color.skinHex("14B8A6").opacity(0.34), Color.skinHex("7C3AED").opacity(0.30), Color.skinHex("FB7185").opacity(0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .holographic:
            return LinearGradient(
                colors: [
                    Color.skinHex("7C3AED").opacity(0.45),
                    Color.skinHex("22D3EE").opacity(0.45),
                    Color.skinHex("F0ABFC").opacity(0.45)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .ascendant:
            return LinearGradient(
                colors: [Color.skinHex("FFF7D6").opacity(0.48), Color.skinHex("FFC857").opacity(0.26), Color.skinHex("B5F3FE").opacity(0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .chalk:
            return LinearGradient(
                colors: [Color.skinHex("334155").opacity(0.50), Color.skinHex("0B1120").opacity(0.84), Color.skinHex("2DD4BF").opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .blueprint:
            return LinearGradient(
                colors: [Color.skinHex("0F2741").opacity(0.88), Color.skinHex("38BDF8").opacity(0.24), Color.skinHex("E0F2FE").opacity(0.16)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .streetNeon:
            return LinearGradient(
                colors: [Color.skinHex("0F172A").opacity(0.88), Color.skinHex("22D3EE").opacity(0.24), Color.skinHex("FF4FD8").opacity(0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .inkDojo:
            return LinearGradient(
                colors: [Color.skinHex("111827").opacity(0.86), Color.skinHex("EDE6D6").opacity(0.18), Color.skinHex("2DD4BF").opacity(0.14)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .solarCircuit:
            return LinearGradient(
                colors: [Color.skinHex("180F1B").opacity(0.92), Color.skinHex("F97316").opacity(0.30), Color.skinHex("5EEAD4").opacity(0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .glassCircuit:
            return LinearGradient(
                colors: [Color.skinHex("0B1120").opacity(0.92), Color.skinHex("14B8A6").opacity(0.28), Color.skinHex("F6C95B").opacity(0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .crystalCavern:
            return LinearGradient(
                colors: [Color.skinHex("120A2A").opacity(0.94), Color.skinHex("7C3AED").opacity(0.34), Color.skinHex("67E8F9").opacity(0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    var mapBackground: LinearGradient {
        LinearGradient(
            colors: [
                primaryColor.opacity(backgroundWashOpacity),
                impactColor.opacity(backgroundWashOpacity * 0.58),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var backgroundWashOpacity: Double {
        switch self {
        case .graphite: return 0.06
        case .violet: return 0.08
        case .ember, .gold, .aurora, .holographic, .ascendant, .streetNeon, .solarCircuit, .glassCircuit, .crystalCavern: return 0.11
        case .jade, .frost, .void: return 0.09
        case .chalk, .blueprint: return 0.07
        case .inkDojo: return 0.08
        }
    }

    var backgroundAssetOpacity: Double {
        switch self {
        case .graphite, .jade, .frost, .chalk, .blueprint: return 0.96
        case .gold, .ember, .void, .inkDojo: return 0.92
        case .violet, .aurora, .holographic, .ascendant, .streetNeon, .solarCircuit, .glassCircuit: return 0.88
        case .crystalCavern: return 0.84
        }
    }

    var backgroundAssetContrast: Double {
        switch self {
        case .graphite, .jade, .frost, .chalk, .blueprint: return 1.24
        case .gold, .ember, .void, .streetNeon, .solarCircuit, .inkDojo: return 1.18
        case .violet, .aurora, .holographic, .ascendant, .glassCircuit: return 1.14
        case .crystalCavern: return 1.12
        }
    }

    /// Faint per-tier background stripe. Keyed to the ACTIVE SKIN (not the
    /// rank's reward tint) so the whole tree reads as one consistent skin —
    /// the rank tint made the high-tier bands at the bottom go gold/orange on
    /// every skin, which looked like a stray golden wash.
    func bandTint(for rank: RankTier) -> Color {
        let ramp = 0.012 + Double(rank.rawValue) * 0.011
        return primaryColor.opacity(ramp)
    }

    func nodeFill(state: NodeState, faded: Bool) -> Color {
        switch state {
        case .locked:
            return Color.unbound.surface
        case .proven:
            return primaryColor.opacity(faded ? 0.18 : 0.24)
        }
    }

    func nodeBorder(state: NodeState, faded: Bool, mythic: Bool = false) -> Color {
        if mythic && state == .locked { return impactColor.opacity(0.52) }
        switch state {
        case .locked:
            return faded ? Color.unbound.border.opacity(0.7) : Color.unbound.border
        case .proven:
            return primaryColor.opacity(faded ? 0.7 : 1.0)
        }
    }

    func nodeGlow(state: NodeState, faded: Bool) -> Color {
        switch state {
        case .locked: return .clear
        case .proven: return primaryColor.opacity(faded ? 0.24 : 0.46)
        }
    }
}

// MARK: - ChipStyle
//
// Skin-aware rank chip styling. A dumb value bag — views apply it.

struct ChipStyle: Sendable {
    let background: Color
    let border: Color
    let text: Color
    let glow: Color
}

extension SkillTreeSkin {
    var rankChipStyle: ChipStyle {
        switch self {
        case .violet:
            return ChipStyle(
                background: primaryColor.opacity(0.20),
                border: primaryColor,
                text: Color.unbound.textPrimary,
                glow: primaryColor
            )
        case .graphite:
            return ChipStyle(
                background: primaryColor.opacity(0.16),
                border: primaryColor.opacity(0.82),
                text: Color.unbound.textPrimary,
                glow: primaryColor
            )
        case .ember:
            return ChipStyle(
                background: primaryColor.opacity(0.20),
                border: primaryColor,
                text: Color.skinHex("FFE9D5"),
                glow: impactColor
            )
        case .jade:
            return ChipStyle(
                background: primaryColor.opacity(0.18),
                border: primaryColor,
                text: Color.skinHex("DCFCE7"),
                glow: primaryColor
            )
        case .frost:
            return ChipStyle(
                background: primaryColor.opacity(0.18),
                border: primaryColor,
                text: Color.skinHex("ECFEFF"),
                glow: primaryColor
            )
        case .gold:
            return ChipStyle(
                background: Color.skinHex("FFC857").opacity(0.22),
                border: Color.skinHex("FFC857"),
                text: Color.skinHex("FFF4D1"),
                glow: Color.skinHex("FFD881")
            )
        case .void:
            return ChipStyle(
                background: primaryColor.opacity(0.18),
                border: primaryColor,
                text: Color.skinHex("F5D0FE"),
                glow: impactColor
            )
        case .aurora:
            return ChipStyle(
                background: primaryColor.opacity(0.18),
                border: primaryColor,
                text: Color.skinHex("F0FDFA"),
                glow: impactColor
            )
        case .holographic:
            return ChipStyle(
                background: Color.skinHex("B5F3FE").opacity(0.20),
                border: Color.skinHex("D8B4FE"),
                text: Color.unbound.textPrimary,
                glow: Color.skinHex("F5A4FF")
            )
        case .ascendant:
            return ChipStyle(
                background: primaryColor.opacity(0.20),
                border: Color.skinHex("FFE8A3"),
                text: Color.skinHex("FFFBEA"),
                glow: impactColor
            )
        case .chalk:
            return ChipStyle(
                background: primaryColor.opacity(0.14),
                border: primaryColor.opacity(0.72),
                text: Color.unbound.textPrimary,
                glow: impactColor
            )
        case .blueprint:
            return ChipStyle(
                background: Color.skinHex("38BDF8").opacity(0.16),
                border: Color.skinHex("BAE6FD").opacity(0.84),
                text: Color.skinHex("E0F2FE"),
                glow: primaryColor
            )
        case .streetNeon:
            return ChipStyle(
                background: primaryColor.opacity(0.18),
                border: primaryColor,
                text: Color.unbound.textPrimary,
                glow: impactColor
            )
        case .inkDojo:
            return ChipStyle(
                background: Color.skinHex("EDE6D6").opacity(0.14),
                border: Color.skinHex("EDE6D6").opacity(0.76),
                text: Color.skinHex("F8FAFC"),
                glow: impactColor
            )
        case .solarCircuit:
            return ChipStyle(
                background: Color.skinHex("F97316").opacity(0.20),
                border: Color.skinHex("F6C95B"),
                text: Color.skinHex("FFFBEB"),
                glow: impactColor
            )
        case .glassCircuit:
            return ChipStyle(
                background: Color.skinHex("F6C95B").opacity(0.18),
                border: Color.skinHex("F6C95B"),
                text: Color.skinHex("FFFBEB"),
                glow: impactColor
            )
        case .crystalCavern:
            return ChipStyle(
                background: Color.skinHex("7C3AED").opacity(0.20),
                border: Color.skinHex("A78BFA"),
                text: Color.skinHex("F5F3FF"),
                glow: impactColor
            )
        }
    }
}

// MARK: - Hex helper (namespaced to avoid collision with other extensions)

extension Color {
    static func skinHex(_ hex: String) -> Color {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double( int        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

// MARK: - Notification payload

struct SkinUnlock: Identifiable, Sendable {
    let id: UUID
    let skin: SkillTreeSkin
    let at: Date

    init(skin: SkillTreeSkin, at: Date = Date()) {
        self.id = UUID()
        self.skin = skin
        self.at = at
    }
}

extension Notification.Name {
    static let skinUnlocked = Notification.Name("unbound.skinUnlocked")
    static let skinChanged = Notification.Name("unbound.skinChanged")
}
