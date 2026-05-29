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
        case .void:         return .unbound
        case .aurora:       return .unbound
        case .holographic:  return .ascendant
        case .ascendant:    return .ascendant
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
        }
    }

    var impactDecalColor: Color {
        switch self {
        case .graphite:     return Color.skinHex("F8FAFC")
        case .gold, .ascendant:
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
        case .ember, .gold, .aurora, .holographic, .ascendant: return 0.11
        case .jade, .frost, .void: return 0.09
        }
    }

    var backgroundAssetOpacity: Double {
        switch self {
        case .graphite, .jade, .frost: return 0.96
        case .gold, .ember, .void: return 0.92
        case .violet, .aurora, .holographic, .ascendant: return 0.88
        }
    }

    var backgroundAssetContrast: Double {
        switch self {
        case .graphite, .jade, .frost: return 1.24
        case .gold, .ember, .void: return 1.18
        case .violet, .aurora, .holographic, .ascendant: return 1.14
        }
    }

    func bandTint(for rank: RankTier) -> Color {
        let ramp = 0.012 + Double(rank.rawValue) * 0.011
        let color = rank >= .vessel ? impactColor : primaryColor
        return color.opacity(ramp)
    }

    func nodeFill(state: NodeState, faded: Bool) -> Color {
        switch state {
        case .locked:
            return Color.unbound.surface
        case .proven:
            return primaryColor.opacity(faded ? 0.10 : 0.20)
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
