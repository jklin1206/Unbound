import Foundation

// MARK: - VelocityWeighting
//
// The "velocity / LV layer". Overall LV is the gamified time-in-game number.
// Before this layer, LV-XP was `Σ rawAP × novelty`, and `rawAP`'s intensity
// term is measured *relative to the user's own prior best* — so a veteran and
// a beginner who log equal volume earn near-identical LV. Ability was invisible.
//
// This makes ability visible by weighting each movement's AP by how hard the
// movement is (skill), whether it's a compound lift (compound), and by giving
// a session-level bonus for returning after a layoff (comeback) plus a one-time
// bolus when a rank/tier is crossed.
//
// Scope is LV only. Per-lift RankTier and skill tiers are objective performance
// standards (StrengthStandards) and stay pure — they are not touched here.
//
// All magnitudes are centralized constants so the feel is one-line tunable.

enum VelocityWeighting {

    // MARK: Tunables

    /// Per-gain skill multiplier keyed off intrinsic movement difficulty.
    /// A veteran training advanced/elite movements earns more LV per unit of
    /// volume than a beginner on beginner movements.
    static func skillMultiplier(for difficulty: MovementDifficulty) -> Double {
        switch difficulty {
        case .beginner:     return 1.0
        case .intermediate: return 1.2
        case .advanced:     return 1.45
        case .elite:        return 1.75
        }
    }

    /// Per-gain compound multiplier. Compound movements (≥2 muscle groups
    /// trained) earn slightly more than isolation work.
    static let compoundBonus = 1.15
    static func compoundMultiplier(isCompound: Bool) -> Double {
        isCompound ? compoundBonus : 1.0
    }

    /// Session-level comeback multiplier from days since the last LV gain.
    /// Rewards returning after a break; capped so chronic absence isn't farmable.
    static func comebackMultiplier(daysSinceLastSession days: Double) -> Double {
        switch days {
        case ..<3:   return 1.0
        case ..<10:  return 1.1
        case ..<30:  return 1.2
        default:     return 1.25
        }
    }

    /// One-time LV-XP bolus granted per rank / tier crossing in a session.
    static let bolusPerRankUp: Double = 150
    static func rankUpBolus(rankUpEvents: Int) -> Double {
        Double(max(0, rankUpEvents)) * bolusPerRankUp
    }

    // MARK: Gain resolution

    /// Difficulty for a logged gain. Prefers the exact movement, falls back to
    /// the ranked standard, then to `.beginner` when the catalog has neither.
    static func difficulty(for gain: MovementAPGain) -> MovementDifficulty {
        if let exact = MovementCatalog.definition(for: gain.movementId) {
            return exact.difficulty
        }
        if let standard = MovementCatalog.definition(for: gain.rankStandardMovementId) {
            return standard.difficulty
        }
        return .beginner
    }

    /// A gain is compound when its movement trains 2+ muscle groups.
    static func isCompound(for gain: MovementAPGain) -> Bool {
        let definition = MovementCatalog.definition(for: gain.movementId)
            ?? MovementCatalog.definition(for: gain.rankStandardMovementId)
        return (definition?.muscleGroups.count ?? 0) >= 2
    }

    // MARK: Session weighting

    /// Velocity-weighted AP for a session: each gain's raw AP scaled by its
    /// skill + compound multipliers. Replaces the flat `Σ rawAP` for LV.
    static func weightedAP(gains: [MovementAPGain]) -> Double {
        gains.reduce(0) { total, gain in
            let raw = max(0, gain.rawAP)
            guard raw > 0 else { return total }
            let skill = skillMultiplier(for: difficulty(for: gain))
            let compound = compoundMultiplier(isCompound: isCompound(for: gain))
            return total + raw * skill * compound
        }
    }
}
