import SwiftUI

// MARK: - SkillTreeSkin
//
// Cosmetic tier for the skill-tree rank UI. Unlocked by the user's
// *peak* archetype aggregate rank (peak survives decay; current does not).
//
// Default: violet. Gold unlocks at S-. Holographic unlocks at S+.

enum SkillTreeSkin: String, Codable, Sendable, CaseIterable, Identifiable {
    case violet
    case gold
    case holographic

    var id: String { rawValue }

    // MARK: Display

    var displayName: String {
        switch self {
        case .violet:       return "Violet"
        case .gold:         return "Gold"
        case .holographic:  return "Holographic"
        }
    }

    var description: String {
        switch self {
        case .violet:       return "The default arc. Violet impact, cursed precision."
        case .gold:         return "Warm gold rim. Earned by crossing into S-tier."
        case .holographic:  return "Shifting prism. The rarest skin — S+ reached."
        }
    }

    /// Minimum peak aggregate rank required. Nil = unlocked by default.
    var unlockRequirement: SubRank? {
        switch self {
        case .violet:       return nil
        case .gold:         return .sMinus
        case .holographic:  return .sPlus
        }
    }

    var unlockHintCopy: String {
        switch self {
        case .violet:       return "Always available."
        case .gold:         return "Reach S- on your arc rank."
        case .holographic:  return "Reach S+ — the summit."
        }
    }

    // MARK: Colors

    /// Static primary color for chips, rings, section headers. Holographic
    /// uses a base color here; animated gradients are provided separately.
    var primaryColor: Color {
        switch self {
        case .violet:       return Color.unbound.accent
        case .gold:         return Color.skinHex("FFC857")
        case .holographic:  return Color.skinHex("B5F3FE")
        }
    }

    /// Accent color used for cinematic glow and impact moments.
    var impactColor: Color {
        switch self {
        case .violet:       return Color.unbound.impact
        case .gold:         return Color.skinHex("FFD881")
        case .holographic:  return Color.skinHex("F5A4FF")
        }
    }

    /// Rim color for share cards + rank glow halos. Kept distinct from
    /// primaryColor so cinematic glow can read against the base.
    var rimColor: Color {
        switch self {
        case .violet:       return Color.unbound.accent
        case .gold:         return Color.skinHex("FFD881")
        case .holographic:  return Color.skinHex("D8B4FE")
        }
    }

    /// Base 3-stop gradient used behind nodes, hero cards, chips.
    var nodeGradient: LinearGradient {
        switch self {
        case .violet:
            return LinearGradient(
                colors: [Color.unbound.accent.opacity(0.35), Color.unbound.impact.opacity(0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [Color.skinHex("FFC857").opacity(0.45), Color.skinHex("B45309").opacity(0.25)],
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
                background: Color.unbound.accent.opacity(0.22),
                border: Color.unbound.accent,
                text: Color.unbound.textPrimary,
                glow: Color.unbound.accent
            )
        case .gold:
            return ChipStyle(
                background: Color.skinHex("FFC857").opacity(0.22),
                border: Color.skinHex("FFC857"),
                text: Color.skinHex("FFF4D1"),
                glow: Color.skinHex("FFD881")
            )
        case .holographic:
            return ChipStyle(
                background: Color.skinHex("B5F3FE").opacity(0.20),
                border: Color.skinHex("D8B4FE"),
                text: Color.unbound.textPrimary,
                glow: Color.skinHex("F5A4FF")
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
