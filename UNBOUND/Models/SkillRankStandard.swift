import Foundation

// MARK: - Skill rank standard (prototype, pull family)
//
// Consistent-with-movements model: a skill ranks on the SAME 9-tier RankTier as
// lifts (StrengthStandards pattern). Each skill has ONE standard — the "Forged"
// anchor (the best ÷ this value = 1.0 lands you at Forged). RankTier =
// band(best ÷ standard) through a shared global curve. Replaces the per-node
// 9-tier hand-authored tierCriteria. See docs/STAR-STANDARD-DESIGN.md. Additive
// prototype — does not touch the live system.

/// What the standard measures — always the skill's OWN movement.
enum SkillMetric: Hashable, Sendable {
    case reps(exercise: String)
    case seconds(exercise: String)
    case bodyweightRatio(exercise: String)   // added load ÷ bodyweight

    var exercise: String {
        switch self {
        case .reps(let e), .seconds(let e), .bodyweightRatio(let e): return e
        }
    }
}

/// One node's standard: a metric + the single "Forged" anchor value + a
/// difficulty weight (drives the overall rank).
struct SkillRankStandard: Hashable, Sendable {
    let metric: SkillMetric
    /// The value at which best÷standard = 1.0 → Forged (the "you genuinely own it" tier).
    let standard: Double
    /// Overall-rank weight (1 foundational … 12 mythic).
    let weight: Int
}

/// Computed rank for a skill, given the user's logs.
struct SkillRankResult: Hashable, Sendable {
    let tier: RankTier
    let best: Double
    /// 0…1 progress from the current tier to the next (the %-to-next-rank bar).
    let progressToNextTier: Double
    let nextTier: RankTier?
}

// MARK: - Pull family standards (one number each — the Forged anchor)

enum PullSkillStandards {
    static let table: [String: SkillRankStandard] = [
        "pp.dead-hang":        .init(metric: .seconds(exercise: "dead hang"),            standard: 60, weight: 1),
        "pp.pullup":           .init(metric: .reps(exercise: "pullup"),                  standard: 10, weight: 2),
        "pp.chin-up":          .init(metric: .reps(exercise: "chin-up"),                 standard: 12, weight: 2),
        "pp.wide-pullup":      .init(metric: .reps(exercise: "wide pullup"),             standard: 8,  weight: 2),
        "pp.weighted-pullup":  .init(metric: .bodyweightRatio(exercise: "weighted pullup"), standard: 0.33, weight: 2),
        "pp.archer-pullup":    .init(metric: .reps(exercise: "archer pullup"),           standard: 3,  weight: 4),
        "pp.muscle-up":        .init(metric: .reps(exercise: "muscle-up"),               standard: 3,  weight: 4),
        "pp.ring-muscle-up":   .init(metric: .reps(exercise: "ring muscle-up"),          standard: 3,  weight: 4),
        "pp.strict-muscle-up": .init(metric: .reps(exercise: "strict muscle-up"),        standard: 2,  weight: 4),
        "pp.one-arm-pullup":   .init(metric: .reps(exercise: "one-arm pullup"),          standard: 1,  weight: 7),
    ]
}
