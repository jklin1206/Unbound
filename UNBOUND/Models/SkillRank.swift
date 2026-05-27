import SwiftUI

// MARK: - SkillRank
//
// Legacy intrinsic difficulty bucket that accompanies every skill node.
// It is a content-authoring signal, NOT the user's current progression
// within the skill. Progression lives in SkillTier.
//
// User-facing surfaces should render the mapped Initiate → Ascendant
// `rankTitle`, never the raw bucket key.

public enum SkillRank: String, Codable, CaseIterable, Sendable {
    case e, d, c, b, a, s

    /// Raw legacy bucket key. Do not use this for user-facing rank labels.
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

    /// Relative difficulty order for sorting from easiest to hardest.
    public var difficultyOrder: Int {
        SkillRank.allCases.firstIndex(of: self) ?? 0
    }

    /// Visual title badge used when showing skill difficulty. The internal
    /// bucket remains useful for ordering and content authoring, but the UI
    /// presents the app's named rank-title badges instead of raw keys.
    var rankTitle: RankTitle {
        RankTitle.legacyLetterFallback(rawValue)
    }

    /// True when the skill sits at the top intrinsic difficulty bucket.
    /// These skills are life pursuits, so distinct visual treatment is
    /// applied wherever rank chips render.
    public var isAscendedTier: Bool { self == .s }

    /// Supporting tagline shown alongside `unboundLabel` when space permits.
    /// The top bucket emphasizes the lifelong-practice framing.
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
