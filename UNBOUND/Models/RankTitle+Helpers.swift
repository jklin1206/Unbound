import Foundation
import SwiftUI

// MARK: - RankTier visual + derivation helpers
//
// Color, ornament, and derivation metadata for the nine UNBOUND tiers. The
// core ladder (cases, displayName, token, ordinal, next, Codable) lives in
// SkillTier.swift; this file adds the SwiftUI-flavored surface.

extension RankTier {
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
        case .master: return Self.rankColor(red: 0x2C, green: 0x90, blue: 0xBB)
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
        case .master:
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
        case .veteran, .master: return "reward_ornament_endpoint_teal"
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

    /// Derives the user's currently-earned tier on a given skill from the
    /// existing per-node state model.
    ///
    /// Mapping rules:
    /// - locked / attempting → Initiate
    /// - achieved at currentLevel L (1-4) → Novice/Apprentice/Forged/Veteran
    /// - achieved at currentLevel 5      → Master
    /// - mastered: caps boosted by intrinsic skill difficulty
    static func derived(
        state: NodeState,
        currentLevel: Int,
        skillRank: SkillRank
    ) -> RankTier {
        if state == .locked || state == .attempting {
            return .initiate
        }

        let baseAchieved: RankTier = {
            switch currentLevel {
            case ..<2: return .novice
            case 2:    return .apprentice
            case 3:    return .forged
            case 4:    return .veteran
            default:   return .master
            }
        }()

        if state == .achieved {
            return baseAchieved
        }

        // mastered — bump by intrinsic difficulty
        switch skillRank {
        case .e, .d: return .master
        case .c, .b: return .vessel
        case .a:     return .unbound
        case .s:     return .ascendant
        }
    }
}
