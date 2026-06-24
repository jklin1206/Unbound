import Foundation

// MARK: - SkillTierGenerator
//
// Generates a skill's full 9-tier ladder ([SkillTier: TierCriterion]) from a few
// REAL anchor points, instead of hand-authoring 9 numbers per skill (the source of
// the old distribution mess). Mirrors how lifts work: a small set of real standards
// + a curve → all the tiers, automatically sensible (accelerating, no 1-rep creep,
// elite-not-freak top).
//
// Two shapes:
//   • .full(levels)      — GRIND moves with real range (pull-up, dip, hold). The 5
//                          strength levels [Beginner…Elite] map onto tiers 0/2/4/6/8
//                          (Beginner→Initiate … Elite→peak); odd tiers interpolate.
//   • .feat(floor,ladder)— HARD FEATS that don't span 9 honest tiers (one-arm pull-up).
//                          The move's difficulty sets a FLOOR rank: your first rep
//                          jumps you straight there, and the short rep ladder runs
//                          floor→peak. Ranks below the floor are "not yet" — never
//                          padded with other exercises' criteria (no double-downs).
//                          The early-rank journey lives on the separate lead-up nodes.
//
// Anchors come from real data — see docs/strength-standards-harvest.md + docs/standards-*.md.

struct SkillAnchor: Hashable, Sendable {
    enum Metric: Hashable, Sendable { case reps, seconds, bodyweightRatio }

    enum Spec: Hashable, Sendable {
        /// 5 ascending real standards [Beginner, Novice, Intermediate, Advanced, Elite].
        case full([Double])
        /// Apex feat scaled on its OWN movement: Initiate = 1 rep/second of the real
        /// skill, scaled geometrically to `ceiling` (the elite human max) at Unbound.
        /// No regressions in the ladder — the route to the first rep lives in the
        /// unlock gate + training plan, never in the rank criteria.
        case scaled(to: Double)
    }

    let exerciseName: String
    let metric: Metric
    let spec: Spec
}

enum SkillTierGenerator {

    /// 5 real levels → 9 tier values. Levels anchor at ordinals 0,2,4,6,8; the odd
    /// ordinals are the midpoints. The real anchors already encode acceleration, so a
    /// linear fill between them stays sensibly spaced.
    static func interpolate(levels: [Double]) -> [Double] {
        precondition(levels.count == 5, "a full anchor needs exactly 5 levels")
        var t = [Double](repeating: 0, count: 9)
        for (i, ordinal) in [0, 2, 4, 6, 8].enumerated() { t[ordinal] = levels[i] }
        for odd in stride(from: 1, to: 8, by: 2) { t[odd] = (t[odd - 1] + t[odd + 1]) / 2 }
        return t
    }

    /// Generate the full 9-tier ladder for an anchor.
    static func generate(_ anchor: SkillAnchor) -> [SkillTier: TierCriterion] {
        let values: [Double]
        switch anchor.spec {
        case .full(let levels):
            values = climbing(interpolate(levels: levels), metric: anchor.metric)
        case .scaled(let ceiling):
            values = scaledValues(to: ceiling, metric: anchor.metric)
        }
        var out: [SkillTier: TierCriterion] = [:]
        for (i, tier) in SkillTier.allCases.enumerated() {
            out[tier] = criterion(for: anchor.metric, value: values[i], exercise: anchor.exerciseName)
        }
        return out
    }

    // MARK: Shaping

    /// Round + enforce strictly-increasing (bump any rounding tie). For grind moves.
    private static func climbing(_ raw: [Double], metric: SkillAnchor.Metric) -> [Double] {
        let step = metric == .bodyweightRatio ? 0.05 : 1.0
        var previous = -Double.greatestFiniteMagnitude
        return raw.map { value in
            let v = max(rounded(value, metric), previous + step)
            previous = v
            return v
        }
    }

    /// Apex feat: 1 → ceiling, geometric across the 9 tiers, rounded + strictly
    /// increasing. Initiate is always 1 (rep/second) of the real movement; Unbound
    /// is the ceiling (the elite max). Same scaling the standards preview uses.
    private static func scaledValues(to ceiling: Double, metric: SkillAnchor.Metric) -> [Double] {
        let step = metric == .bodyweightRatio ? 0.05 : 1.0
        var previous = -Double.greatestFiniteMagnitude
        return (0..<9).map { i in
            let raw = pow(ceiling, Double(i) / 8.0)
            let v = max(rounded(raw, metric), previous + step)
            previous = v
            return v
        }
    }

    private static func rounded(_ v: Double, _ metric: SkillAnchor.Metric) -> Double {
        metric == .bodyweightRatio ? (v * 20).rounded() / 20 : v.rounded()
    }

    private static func criterion(for metric: SkillAnchor.Metric, value: Double, exercise: String) -> TierCriterion {
        switch metric {
        case .reps:            return .reps(Int(value), exerciseName: exercise)
        case .seconds:         return .exerciseSeconds(Int(value), exerciseName: exercise)
        case .bodyweightRatio: return .exerciseBodyweightRatio(value, exerciseName: exercise)
        }
    }
}

