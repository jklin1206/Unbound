import Foundation

/// 9-tier per-skill ladder. Replaces SubRank (lifts), SkillRank (difficulty),
/// and SkillLevel (1-5 XP). Apex-style: no letter grades, no aggregate user
/// rank. Each skill has its own Initiate→Ascendant progression.
///
/// Bottom 4 (Initiate–Forged) are quiet trainee tiers. Top 5 (Veteran–
/// Ascendant) are brand-flavored. Cinematic asymmetry: only Vessel/Unbound/
/// Ascendant crossings trigger the full chain-shatter cinematic.
enum SkillTier: Int, Codable, CaseIterable, Sendable, Comparable {
    case initiate    = 0
    case novice      = 1
    case apprentice  = 2
    case forged      = 3
    case veteran     = 4
    case master       = 5
    case vessel      = 6
    case unbound     = 7
    case ascendant   = 8

    var displayName: String {
        switch self {
        case .initiate:   return "Initiate"
        case .novice:     return "Novice"
        case .apprentice: return "Apprentice"
        case .forged:     return "Forged"
        case .veteran:    return "Veteran"
        case .master:      return "Master"
        case .vessel:     return "Vessel"
        case .unbound:    return "Unbound"
        case .ascendant:  return "Ascendant"
        }
    }

    /// Tiers that trigger the full chain-shatter cinematic on advancing.
    /// Lower tiers use the quiet bloom toast.
    var isFlagshipMoment: Bool { rawValue >= SkillTier.vessel.rawValue }

    /// Asset name for the shield badge image in RankTitles/.
    var assetName: String {
        switch self {
        case .initiate:   return "rank_title_initiate"
        case .novice:     return "rank_title_novice"
        case .apprentice: return "rank_title_apprentice"
        case .forged:     return "rank_title_forged"
        case .veteran:    return "rank_title_veteran"
        case .master:      return "rank_title_master"
        case .vessel:     return "rank_title_vessel"
        case .unbound:    return "rank_title_unbound"
        case .ascendant:  return "rank_title_ascendant"
        }
    }

    static func < (lhs: SkillTier, rhs: SkillTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Emitted by RankService.ingest when a skill advances. Carries enough
/// payload for cinematic dispatchers to render the right effect.
struct SkillTierAdvance: Equatable, Sendable, Identifiable {
    let skillId: String
    let from: SkillTier
    let to: SkillTier

    /// Stable id for SwiftUI fullScreenCover(item:) usage.
    var id: String { "\(skillId):\(from.rawValue)→\(to.rawValue)" }

    /// Whether this advance lands on a flagship tier (Vessel+) and should
    /// trigger the chain-shatter cinematic instead of the quiet bloom.
    var isFlagship: Bool { to.isFlagshipMoment }
}

extension Notification.Name {
    /// Emitted by RankService.ingest when a skill advances. The `object`
    /// payload is a `SkillTierAdvance`.
    /// NOTE: distinct from `.rankAdvanced` (SubRank/LiftRank) to avoid
    /// colliding with existing listeners. Phase 7 migrates listeners;
    /// Phase 8 renames or merges.
    static let skillTierAdvanced = Notification.Name("unbound.skillTierAdvanced")
}

// MARK: - SubRank → SkillTier bridge

extension SubRank {
    /// Convert a SubRank to the nearest SkillTier. Used at RankBadge →
    /// TierBadge call sites during the rank-cleanup migration.
    var asSkillTier: SkillTier {
        switch ordinal {
        case 0...1: return .initiate
        case 2...3: return .novice
        case 4...5: return .apprentice
        case 6...7: return .forged
        case 8...9: return .veteran
        case 10...11: return .master
        case 12...13: return .vessel
        case 14...15: return .unbound
        default:    return .ascendant
        }
    }
}

extension RankTitle {
    /// Convert a RankTitle to its equivalent SkillTier.
    var asSkillTier: SkillTier {
        switch self {
        case .initiate:   return .initiate
        case .novice:     return .novice
        case .apprentice: return .apprentice
        case .forged:     return .forged
        case .veteran:    return .veteran
        case .master:      return .master
        case .vessel:     return .vessel
        case .unbound:    return .unbound
        case .ascendant:  return .ascendant
        }
    }
}
