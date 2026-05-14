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
    case honed       = 5
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
        case .honed:      return "Honed"
        case .vessel:     return "Vessel"
        case .unbound:    return "Unbound"
        case .ascendant:  return "Ascendant"
        }
    }

    /// Tiers that trigger the full chain-shatter cinematic on advancing.
    /// Lower tiers use the quiet bloom toast.
    var isFlagshipMoment: Bool { rawValue >= SkillTier.vessel.rawValue }

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
