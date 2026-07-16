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
        "weighted pullup",
        "power clean",
        "snatch",
        "rack pull",
        "push press",
        "lunge"
    ]

    /// Per-tier bodyweight multiplier for each compound, MALE column.
    /// Index = RankTier ordinal 0…8. Ordinal 0 is the floor (below novice).
    ///
    /// The 2026-07 rows are StrengthLevel-anchored at 80 kg male / 60 kg
    /// female (same 5-band → ordinal 1/3/5/7/8 anchoring as the original
    /// five): power clean 1,069,314 lifts; snatch 443,273; rack pull
    /// 273,085; push press 344,818; barbell lunge 192,645.
    static let male: [String: [Double]] = [
        //               0     1     2     3     4     5     6     7     8
        "back squat":   [0.00, 0.75, 1.00, 1.25, 1.38, 1.50, 1.88, 2.25, 2.75],
        "bench press":  [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00],
        "deadlift":     [0.00, 1.00, 1.25, 1.50, 1.75, 2.00, 2.25, 2.50, 3.00],
        "overhead press":[0.00, 0.35, 0.45, 0.55, 0.68, 0.80, 0.95, 1.10, 1.40],
        "barbell row":  [0.00, 0.50, 0.63, 0.75, 0.88, 1.00, 1.25, 1.50, 1.75],
        "power clean":  [0.00, 0.65, 0.75, 0.85, 0.98, 1.10, 1.25, 1.40, 1.70],
        "snatch":       [0.00, 0.46, 0.56, 0.66, 0.80, 0.93, 1.08, 1.23, 1.55],
        "rack pull":    [0.00, 1.24, 1.48, 1.73, 2.02, 2.31, 2.65, 2.99, 3.71],
        "push press":   [0.00, 0.53, 0.63, 0.74, 0.86, 0.99, 1.13, 1.28, 1.59],
        "lunge":        [0.00, 0.43, 0.56, 0.69, 0.86, 1.03, 1.24, 1.45, 1.91]
    ]

    /// Per-tier bodyweight multiplier for each compound, FEMALE column.
    static let female: [String: [Double]] = [
        //               0     1     2     3     4     5     6     7     8
        "back squat":   [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.38, 1.50, 2.00],
        "bench press":  [0.00, 0.25, 0.38, 0.50, 0.63, 0.75, 0.88, 1.00, 1.50],
        "deadlift":     [0.00, 0.50, 0.75, 1.00, 1.13, 1.25, 1.50, 1.75, 2.50],
        "overhead press":[0.00, 0.20, 0.28, 0.35, 0.43, 0.50, 0.63, 0.75, 1.00],
        "barbell row":  [0.00, 0.25, 0.33, 0.40, 0.53, 0.65, 0.78, 0.90, 1.20],
        "power clean":  [0.00, 0.45, 0.54, 0.63, 0.74, 0.85, 0.98, 1.10, 1.37],
        "snatch":       [0.00, 0.35, 0.43, 0.50, 0.60, 0.70, 0.81, 0.92, 1.17],
        "rack pull":    [0.00, 0.87, 1.08, 1.28, 1.54, 1.80, 2.11, 2.42, 3.07],
        "push press":   [0.00, 0.37, 0.45, 0.53, 0.63, 0.72, 0.84, 0.95, 1.20],
        "lunge":        [0.00, 0.32, 0.43, 0.53, 0.68, 0.82, 0.99, 1.15, 1.53]
    ]
}
