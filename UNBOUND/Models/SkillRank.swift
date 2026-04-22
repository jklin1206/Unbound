import SwiftUI

// MARK: - SkillRank
//
// E/D/C/B/A/S tier that accompanies every skill node. The rank is a
// difficulty/identity signal shown on the node chip, NOT the user's
// current progression within the skill. Progression lives in the
// 1-5 level ladder on each SkillNode (see SkillLevel.swift).
//
// Brand language comes from the existing UNBOUND rank tier system
// (Dormant/Awakened/Forged/Sharpened/Unbound/Ascended). Keep the
// palette muted — rank is a signal, not a billboard.

public enum SkillRank: String, Codable, CaseIterable, Sendable {
    case e, d, c, b, a, s

    /// Letter shown on rank chip (E/D/C/B/A/S)
    public var letter: String { rawValue.uppercased() }

    /// UNBOUND rank language per existing brand system
    public var unboundLabel: String {
        switch self {
        case .e: return "Dormant"
        case .d: return "Awakened"
        case .c: return "Forged"
        case .b: return "Sharpened"
        case .a: return "Unbound"
        case .s: return "Ascended"
        }
    }

    /// Relative difficulty order for sorting (E = easiest)
    public var difficultyOrder: Int {
        SkillRank.allCases.firstIndex(of: self) ?? 0
    }

    /// True when the rank sits at the top of the ladder (S = Ascended).
    /// An S-rank skill is a life pursuit, not a rank tier — distinct visual
    /// treatment (flame instead of hex, impact orange instead of muted
    /// violet) is applied wherever rank chips render.
    public var isAscendedTier: Bool { self == .s }

    /// Supporting tagline shown alongside `unboundLabel` when space permits.
    /// S-rank emphasizes the lifelong-practice framing.
    public var tagline: String {
        switch self {
        case .e: return "Foundation."
        case .d: return "Awakening the movement."
        case .c: return "Forged through reps."
        case .b: return "Sharpened edge."
        case .a: return "Unbound from limits."
        case .s: return "Ascended — years of dedicated practice."
        }
    }

    /// Accent color for rank-coded UI. Uses Color.unbound tokens if available,
    /// otherwise a sensible fallback. Keep the palette muted — rank is a
    /// signal, not a billboard.
    public var accentColor: Color {
        switch self {
        case .e: return Color(red: 0.65, green: 0.70, blue: 0.75)  // cool grey
        case .d: return Color(red: 0.40, green: 0.70, blue: 0.95)  // azure
        case .c: return Color(red: 0.55, green: 0.85, blue: 0.55)  // forged green
        case .b: return Color(red: 0.95, green: 0.75, blue: 0.35)  // sharpened amber
        case .a: return Color(red: 0.60, green: 0.35, blue: 0.95)  // unbound violet (brand)
        case .s: return Color(red: 0.95, green: 0.45, blue: 0.35)  // ascended flame
        }
    }
}
