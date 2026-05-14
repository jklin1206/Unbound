import Foundation

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
