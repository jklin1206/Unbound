import Foundation

// MARK: - CompoundStandards
//
// The single source for barbell COMPOUND rank standards: per-tier bodyweight
// multiplier tables (9 tiers, male + female) for squat / bench / deadlift / OHP
// / barbell row. StrengthStandards resolves a logged lift (via its aliases) to
// one of these canonical keys and reads the sex-correct ratio table here.
// (Standards harvested in PHASE3-STANDARDS-PROPOSAL §B.2.)

enum CompoundStandards {

    /// Compound lifts that have an explicit multiplier table (canonical keys).
    /// `weighted pullup` resolves here too but is ranked off the skill node's
    /// %bw anchors (SkillStandards), not a table below.
    static let liftKeys: [String] = [
        "back squat",
        "bench press",
        "deadlift",
        "overhead press",
        "barbell row",
        "weighted pullup"
    ]

    /// Per-tier bodyweight multiplier for each compound, MALE column.
    /// Index = RankTier ordinal 0…8. Ordinal 0 is the floor (below novice).
    static let male: [String: [Double]] = [
        //               0     1     2     3     4     5     6     7     8
        "back squat":   [0.00, 0.75, 1.00, 1.25, 1.38, 1.50, 1.88, 2.25, 2.75],
        "bench press":  [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00],
        "deadlift":     [0.00, 1.00, 1.25, 1.50, 1.75, 2.00, 2.25, 2.50, 3.00],
        "overhead press":[0.00, 0.35, 0.45, 0.55, 0.68, 0.80, 0.95, 1.10, 1.40],
        "barbell row":  [0.00, 0.50, 0.63, 0.75, 0.88, 1.00, 1.25, 1.50, 1.75]
    ]

    /// Per-tier bodyweight multiplier for each compound, FEMALE column.
    static let female: [String: [Double]] = [
        //               0     1     2     3     4     5     6     7     8
        "back squat":   [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.38, 1.50, 2.00],
        "bench press":  [0.00, 0.25, 0.38, 0.50, 0.63, 0.75, 0.88, 1.00, 1.50],
        "deadlift":     [0.00, 0.50, 0.75, 1.00, 1.13, 1.25, 1.50, 1.75, 2.50],
        "overhead press":[0.00, 0.20, 0.28, 0.35, 0.43, 0.50, 0.63, 0.75, 1.00],
        "barbell row":  [0.00, 0.25, 0.33, 0.40, 0.53, 0.65, 0.78, 0.90, 1.20]
    ]
}
