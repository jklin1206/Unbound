import Foundation

// MARK: - Skill mastery stars (prototype, pull family)
//
// A skill is mastered through 5 DISCRETE stars on its OWN movement — hand-authored
// ascending thresholds. Hit a threshold → the star fills. Between stars the card
// shows an honest whole-number tally ("7 / 10 reps to next star") — no fractional
// bar (reps are chunky integers; a lift on continuous load keeps its fraction bar,
// a skill does not). Past 5 stars the card tracks your personal best forever.
//
// Depth within a NODE is the metric (reps/seconds/load) on that exact movement;
// depth across DIFFICULTY is the tree itself — the harder variations (ring / strict
// / weighted muscle-up) are their OWN nodes with their own stars, so a feat node's
// rep ceiling stays LOW (muscle-up 1/2/3/4/5, not /15): you own it cleanly, then
// climb to the next node. Grind movements (pull-up, dead hang) keep higher ceilings.
//
// Per-session dopamine is XP→attributes, separate from stars (Liftoff keeps XP and
// rank on separate tracks for exactly this reason). Additive prototype — does not
// touch the live system. See docs/STAR-STANDARD-DESIGN.md.

/// What a pip measures — always the skill's OWN movement.
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

/// One skill's mastery ladder: a metric + 5 ascending star thresholds + a difficulty
/// weight (drives the overall athlete rank — a star on a muscle-up outweighs a star
/// on a pull-up).
struct SkillRankStandard: Hashable, Sendable {
    let metric: SkillMetric
    /// 5 ascending values. Index 0 = 1★ ("Learned"), index 4 = 5★ ("Mastered").
    let thresholds: [Double]
    /// Overall-rank weight (1 foundational … 7 mythic).
    let weight: Int
}

/// Computed mastery for a skill, given the user's logs.
struct SkillRankResult: Hashable, Sendable {
    /// 0 = not yet learned … 5 = mastered.
    let stars: Int
    /// Best logged value on the skill's own movement (the PB).
    let best: Double
    /// The value to reach the NEXT star; nil when mastered (stars == 5).
    let nextThreshold: Double?

    var isMastered: Bool { stars >= 5 }

    /// Endpoint labels only — the middle stars are unnamed fill (the stars speak).
    var label: String {
        switch stars {
        case 0:  return "Locked"
        case 1:  return "Learned"
        case 5:  return "Mastered"
        default: return "Proven"
        }
    }
}

// MARK: - Pull family mastery ladders (5 hand-authored pips each)

enum PullSkillStandards {
    static let table: [String: SkillRankStandard] = [
        // Grind movements — higher rep/second/load ceilings (depth lives in the number).
        "pp.dead-hang":        .init(metric: .seconds(exercise: "dead hang"),               thresholds: [30, 45, 60, 90, 120], weight: 1),
        "pp.pullup":           .init(metric: .reps(exercise: "pullup"),                     thresholds: [1, 5, 10, 15, 20],    weight: 2),
        "pp.chin-up":          .init(metric: .reps(exercise: "chin-up"),                    thresholds: [1, 5, 10, 15, 20],    weight: 2),
        "pp.wide-pullup":      .init(metric: .reps(exercise: "wide pullup"),                thresholds: [3, 6, 10, 15, 20],    weight: 2),
        "pp.weighted-pullup":  .init(metric: .bodyweightRatio(exercise: "weighted pullup"), thresholds: [0.1, 0.25, 0.5, 0.75, 1.0], weight: 2),
        "pp.archer-pullup":    .init(metric: .reps(exercise: "archer pullup"),              thresholds: [1, 2, 4, 6, 10],      weight: 4),
        // Feat nodes — LOW capped ceilings; depth comes from the next node, not rep grinding.
        "pp.muscle-up":        .init(metric: .reps(exercise: "muscle-up"),                  thresholds: [1, 2, 3, 4, 5],       weight: 4),
        "pp.ring-muscle-up":   .init(metric: .reps(exercise: "ring muscle-up"),             thresholds: [1, 2, 3, 4, 5],       weight: 4),
        "pp.strict-muscle-up": .init(metric: .reps(exercise: "strict muscle-up"),           thresholds: [1, 2, 3, 4, 5],       weight: 4),
        "pp.one-arm-pullup":   .init(metric: .reps(exercise: "one-arm pullup"),             thresholds: [1, 2, 3, 4, 5],       weight: 7),
    ]
}
