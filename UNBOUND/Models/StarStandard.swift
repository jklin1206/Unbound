import Foundation

// MARK: - Star-Standard progression (prototype, pull family)
//
// Overcooked-style per-skill rating: each node ranks on its OWN movement vs a
// standard, earning 0–3 stars. ★ = can genuinely do it · ★★ = solid · ★★★ =
// elite. Replaces the per-node 9-tier hand-authored ladder. See
// docs/STAR-STANDARD-DESIGN.md. This is an ADDITIVE prototype — it does not
// touch the existing RankTier/TierCriterion system yet.

/// What a star standard measures — always the skill's OWN movement.
enum StarMetric: Hashable, Sendable {
    /// Best single-set rep count for `exercise`.
    case reps(exercise: String)
    /// Best held duration (SetLog.durationSeconds, legacy reps fallback) for `exercise`.
    case seconds(exercise: String)
    /// Best added load ÷ bodyweight for `exercise` (e.g. weighted pull-up +0.5x bw).
    case bodyweightRatio(exercise: String)

    var exercise: String {
        switch self {
        case .reps(let e), .seconds(let e), .bodyweightRatio(let e): return e
        }
    }

    var unitLabel: String {
        switch self {
        case .reps:           return "reps"
        case .seconds:        return "s"
        case .bodyweightRatio: return "× bw"
        }
    }
}

/// One node's standard: a metric + the three star thresholds + a difficulty
/// weight (drives the overall rank — a ★ on a hard skill is worth more).
struct StarStandard: Hashable, Sendable {
    let metric: StarMetric
    let oneStar: Double
    let twoStar: Double
    let threeStar: Double
    /// Overall-rank weight per star earned (1 foundational … 12 mythic).
    let weight: Int

    var thresholds: [Double] { [oneStar, twoStar, threeStar] }
}

/// Computed rating for a node, given the user's logs.
struct StarRating: Hashable, Sendable {
    /// 0–3 stars earned.
    let stars: Int
    /// User's best score on this node's metric.
    let bestScore: Double
    /// 0…1 fraction toward the NEXT star (1.0 when 3-starred).
    let progressToNext: Double
    /// Threshold value needed for the next star (nil when 3-starred).
    let nextThreshold: Double?
    let metric: StarMetric

    /// Weighted points this rating contributes to the overall athlete rank.
    func weightedPoints(weight: Int) -> Int { stars * weight }
}

// MARK: - Pull family standards (from docs/STAR-STANDARD-DESIGN.md)

enum PullStarStandards {
    /// Keyed by SkillNode id. Owner refines the numbers.
    static let table: [String: StarStandard] = [
        "pp.dead-hang":        .init(metric: .seconds(exercise: "dead hang"),       oneStar: 30, twoStar: 60, threeStar: 120, weight: 1),
        "pp.pullup":           .init(metric: .reps(exercise: "pullup"),             oneStar: 1,  twoStar: 8,  threeStar: 15,  weight: 2),
        "pp.chin-up":          .init(metric: .reps(exercise: "chin-up"),            oneStar: 1,  twoStar: 10, threeStar: 18,  weight: 2),
        "pp.wide-pullup":      .init(metric: .reps(exercise: "wide pullup"),        oneStar: 1,  twoStar: 6,  threeStar: 12,  weight: 2),
        "pp.weighted-pullup":  .init(metric: .bodyweightRatio(exercise: "weighted pullup"), oneStar: 0.10, twoStar: 0.33, threeStar: 0.50, weight: 2),
        "pp.archer-pullup":    .init(metric: .reps(exercise: "archer pullup"),      oneStar: 1,  twoStar: 3,  threeStar: 6,   weight: 4),
        "pp.muscle-up":        .init(metric: .reps(exercise: "muscle-up"),          oneStar: 1,  twoStar: 3,  threeStar: 7,   weight: 4),
        "pp.ring-muscle-up":   .init(metric: .reps(exercise: "ring muscle-up"),     oneStar: 1,  twoStar: 3,  threeStar: 6,   weight: 4),
        "pp.strict-muscle-up": .init(metric: .reps(exercise: "strict muscle-up"),   oneStar: 1,  twoStar: 2,  threeStar: 5,   weight: 4),
        "pp.one-arm-pullup":   .init(metric: .reps(exercise: "one-arm pullup"),     oneStar: 1,  twoStar: 2,  threeStar: 5,   weight: 7),
    ]
}
