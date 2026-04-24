import Foundation

// MARK: - StatScore
//
// Four-axis summary of a user's physical state, surfaced on the home
// dashboard as a 2×2 readout. Each axis is a clamped 0...100 integer so
// the UI can render a consistent grid.
//
//   Strength   — peak output. Aggregated sub-rank ordinal of the user's
//                emphasis lifts (or calisthenic family state for bodyweight
//                archetypes). A B-rank lifter reads ~60, S-rank ~95.
//   Stamina    — sustained output. Weekly session density blended with
//                current streak momentum. Drops when training tapers.
//   Technique  — skill mastery. Percentage of `SkillGraph` nodes that the
//                user has pushed to `.achieved` or `.mastered`.
//   Vitality   — recovery / readiness proxy. Streak + recency composite
//                with a hard drop-off past 7 days of inactivity. (Future:
//                blend HealthKit HRV + sleep when integrated.)
//
// All four are directional signals — this is dashboard eye-candy backed
// by real data, not a clinical score. Re-derived on every home appear
// + on `.sessionXPUpdated`.

struct StatScore: Sendable, Equatable {
    let strength: Int
    let stamina: Int
    let technique: Int
    let vitality: Int
    let computedAt: Date

    static let empty = StatScore(
        strength: 0,
        stamina: 0,
        technique: 0,
        vitality: 0,
        computedAt: .distantPast
    )

    var strengthRank: SubRank { Self.rank(for: strength) }
    var staminaRank:  SubRank { Self.rank(for: stamina)  }
    var techniqueRank: SubRank { Self.rank(for: technique) }
    var vitalityRank: SubRank { Self.rank(for: vitality) }

    /// 0...100 → SubRank ladder (0...17). Each sub-rank covers ~5.5 points.
    /// E-  at 0, S+ at 100, linear in between.
    static func rank(for value: Int) -> SubRank {
        let clamped = max(0, min(100, value))
        let ordinal = Int((Double(clamped) / 100.0 * 17.0).rounded(.down))
        return SubRank.allCases.first(where: { $0.ordinal == min(17, ordinal) }) ?? .eMinus
    }
}
