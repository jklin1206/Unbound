import Foundation
import SwiftUI

// MARK: - RankTitle helpers
//
// Adds the metadata the per-skill rank system needs on top of the
// existing 9-case `RankTitle` enum. Kept separate from the canonical
// declaration in `SubRank.swift` so the strength-standards machinery
// stays thin.

extension RankTitle {
    /// 1-9 ordinal — the user-facing tier number, matching the
    /// Initiate → Ascendant ladder.
    var ordinal: Int {
        switch self {
        case .initiate:   return 1
        case .novice:     return 2
        case .apprentice: return 3
        case .forged:     return 4
        case .veteran:    return 5
        case .honed:      return 6
        case .vessel:     return 7
        case .unbound:    return 8
        case .ascendant:  return 9
        }
    }

    /// "Named tiers" get the brand-flavored treatment — distinct color,
    /// rank-up cinematic candidate, share-card eligible. The bottom four
    /// stay quiet on purpose so the named-tier crossing feels earned.
    var isNamedTier: Bool {
        ordinal >= 5
    }

    /// True for the three crown tiers — Vessel/Unbound/Ascendant.
    /// Reserved for the full chain-shatter cinematic.
    var deservesCinematic: Bool {
        switch self {
        case .vessel, .unbound, .ascendant: return true
        default: return false
        }
    }

    /// Canonical visual tint for the nine UNBOUND title tiers. These are
    /// sampled to match the shipped `rank_title_*` badge art, then used by
    /// profile glow, avatar frames, chips, and rank-up moments.
    var rewardTint: Color {
        switch self {
        case .initiate: return Self.rankColor(red: 0x54, green: 0x52, blue: 0x5E)
        case .novice: return Self.rankColor(red: 0x4C, green: 0x52, blue: 0x9A)
        case .apprentice: return Self.rankColor(red: 0xC7, green: 0x9D, blue: 0x46)
        case .forged: return Self.rankColor(red: 0xAF, green: 0x40, blue: 0x1A)
        case .veteran: return Self.rankColor(red: 0x3E, green: 0x74, blue: 0x49)
        case .honed: return Self.rankColor(red: 0x2C, green: 0x90, blue: 0xBB)
        case .vessel: return Self.rankColor(red: 0x54, green: 0x2F, blue: 0x7F)
        case .unbound: return Self.rankColor(red: 0x97, green: 0x33, blue: 0x9D)
        case .ascendant: return Color.unbound.rankGold
        }
    }

    /// Multi-stop glow for tiers whose badge art reads as more than one
    /// color. Ascendant gets the gold + astral-violet treatment so the
    /// profile background feels crowned instead of flat yellow.
    var rewardGlowColors: [Color] {
        switch self {
        case .ascendant:
            return [
                Color.unbound.rankGold,
                Self.rankColor(red: 0xA0, green: 0x69, blue: 0x94),
                Color.unbound.impact
            ]
        default:
            return [rewardTint]
        }
    }

    /// Foreground-safe companion color for small text/icons on dark UI.
    /// The base reward tint stays badge-accurate for frames and glows, while
    /// this keeps labels from dipping below readable contrast.
    var rewardTextTint: Color {
        switch self {
        case .initiate:
            return Color.unbound.textSecondary
        case .novice:
            return Self.rankColor(red: 0x8D, green: 0x94, blue: 0xFF)
        case .apprentice:
            return rewardTint
        case .forged:
            return Color.unbound.ember
        case .veteran:
            return Self.rankColor(red: 0x64, green: 0xC4, blue: 0x75)
        case .honed:
            return rewardTint
        case .vessel:
            return Self.rankColor(red: 0xB2, green: 0x7A, blue: 0xF4)
        case .unbound:
            return Self.rankColor(red: 0xD8, green: 0x61, blue: 0xDF)
        case .ascendant:
            return Color.unbound.rankGold
        }
    }

    private static func rankColor(red: Int, green: Int, blue: Int) -> Color {
        Color(.sRGB, red: Double(red) / 255.0, green: Double(green) / 255.0, blue: Double(blue) / 255.0, opacity: 1.0)
    }

    var rewardOriginOrnamentAssetName: String {
        switch self {
        case .forged, .apprentice: return "reward_ornament_origin_ember"
        case .veteran: return "reward_ornament_origin_green"
        default: return "reward_ornament_origin_blue"
        }
    }

    var rewardEndpointOrnamentAssetName: String {
        switch self {
        case .forged, .apprentice: return "reward_ornament_endpoint_orange"
        case .veteran, .honed: return "reward_ornament_endpoint_teal"
        default: return "reward_ornament_endpoint_blue"
        }
    }

    var rewardTickOrnamentAssetName: String {
        switch self {
        case .vessel, .unbound, .ascendant: return "reward_ornament_tick_violet"
        case .apprentice: return "reward_ornament_tick_gold"
        default: return "reward_ornament_tick_bone"
        }
    }

    /// Next tier up, or nil if already at Ascendant.
    var next: RankTitle? {
        switch self {
        case .initiate:   return .novice
        case .novice:     return .apprentice
        case .apprentice: return .forged
        case .forged:     return .veteran
        case .veteran:    return .honed
        case .honed:      return .vessel
        case .vessel:     return .unbound
        case .unbound:    return .ascendant
        case .ascendant:  return nil
        }
    }

    /// Derives the user's currently-earned tier on a given skill from the
    /// existing per-node state model. Bridge between the legacy 1-5 level
    /// + E-S difficulty system and the 9-tier ladder shown to the user.
    ///
    /// Mapping rules:
    /// - locked / attempting → Initiate
    /// - achieved at currentLevel L (1-4) → Novice/Apprentice/Forged/Veteran
    /// - achieved at currentLevel 5      → Honed
    /// - mastered: caps boosted by intrinsic skill difficulty
    ///   - E/D-rank skill mastered → Honed
    ///   - C-rank mastered          → Vessel
    ///   - B-rank mastered          → Vessel
    ///   - A-rank mastered          → Unbound
    ///   - S-rank mastered          → Ascendant
    static func derived(
        state: NodeState,
        currentLevel: Int,
        skillRank: SkillRank
    ) -> RankTitle {
        if state == .locked || state == .attempting {
            return .initiate
        }

        let baseAchieved: RankTitle = {
            switch currentLevel {
            case ..<2: return .novice
            case 2:    return .apprentice
            case 3:    return .forged
            case 4:    return .veteran
            default:   return .honed
            }
        }()

        if state == .achieved {
            return baseAchieved
        }

        // mastered — bump by intrinsic difficulty
        switch skillRank {
        case .e, .d: return .honed
        case .c, .b: return .vessel
        case .a:     return .unbound
        case .s:     return .ascendant
        }
    }
}

extension SkillTier {
    var rankTitle: RankTitle {
        switch self {
        case .initiate:   return .initiate
        case .novice:     return .novice
        case .apprentice: return .apprentice
        case .forged:     return .forged
        case .veteran:    return .veteran
        case .honed:      return .honed
        case .vessel:     return .vessel
        case .unbound:    return .unbound
        case .ascendant:  return .ascendant
        }
    }

    var rewardTint: Color {
        rankTitle.rewardTint
    }

    var rewardGlowColors: [Color] {
        rankTitle.rewardGlowColors
    }

    var rewardTextTint: Color {
        rankTitle.rewardTextTint
    }
}
