import Foundation

// MARK: - StrengthStandards
//
// One metric: every LOADED movement resolves to a single `RankTier` from a
// bodyweight-relative load ratio. Three resolution paths:
//
//   1. Compounds (bench/squat/deadlift/OHP/barbell row) + their variants
//      (incline→bench, front squat→squat, RDL→deadlift, …) — StrengthLevel-
//      anchored 9-tier ratio tables, male + female (PHASE3-STANDARDS-PROPOSAL §B.2).
//   2. Weighted pullup/dip — added-kg anchors (unchanged).
//   3. Accessory families F1–F9 — per-family 9-tier ratio tables, male + female
//      (PHASE3-ACCESSORY-RATIOS §3 male / §4 female).
//
// Movements in the explicit UNRANKED set return nil (lateral/front/upright raise,
// glute kickback/abduction machines, pallof/landmine, kettlebell swing). They
// earn XP but no rank badge. Bodyweight-rep / hold / cardio / carry movements
// keep their existing paths in RankService — this type is load-only.
//
// Band → ordinal anchoring (StrengthLevel 5 bands → our 9 tiers): Beginner=1
// (novice), Novice=3 (forged), Intermediate=5 (master), Advanced=7, Elite=8;
// ordinals 2/4/6 are interpolated midpoints; ordinal 0 = below Beginner.
// (RankTier ordinal 8 displays "Unbound", ordinal 7 "Ascendant".)

enum StrengthStandards {

    // MARK: Accessory families

    /// Loaded accessory families (PHASE3-ACCESSORY-RATIOS §1). Each has a
    /// 9-tier total-load ratio table, except F3 which is per-hand.
    enum AccessoryFamily {
        case curl            // F1 — total barbell/cable load (DB ×2 rule applies)
        case triceps         // F2 — total stack
        case legExtension    // F4 — total stack
        case legCurl         // F5 — total stack
        case calfRaise       // F6 — added load excl. bodyweight
        case verticalPull    // F7 — machine vertical pull, total stack
        case hipThrust       // F8 — total load incl. bar
        case loadedAb        // F9 — total stack
    }

    // MARK: Lift keys (barbell compounds with a ratio table)

    /// Compound lifts that have an explicit multiplier table (canonical keys).
    static let liftKeys: [String] = [
        "back squat",
        "bench press",
        "deadlift",
        "overhead press",
        "barbell row",
        "weighted pullup"
    ]

    // MARK: Compound ratio tables (9-tier, bodyweight multiples) — §B.2

    /// Per-tier bodyweight multiplier for each compound, MALE column.
    /// Index = RankTier ordinal 0…8. Ordinal 0 is the floor (below novice).
    private static let compoundMale: [String: [Double]] = [
        //               0     1     2     3     4     5     6     7     8
        "back squat":   [0.00, 0.75, 1.00, 1.25, 1.38, 1.50, 1.88, 2.25, 2.75],
        "bench press":  [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00],
        "deadlift":     [0.00, 1.00, 1.25, 1.50, 1.75, 2.00, 2.25, 2.50, 3.00],
        "overhead press":[0.00, 0.35, 0.45, 0.55, 0.68, 0.80, 0.95, 1.10, 1.40],
        "barbell row":  [0.00, 0.50, 0.63, 0.75, 0.88, 1.00, 1.25, 1.50, 1.75]
    ]

    /// Per-tier bodyweight multiplier for each compound, FEMALE column.
    private static let compoundFemale: [String: [Double]] = [
        //               0     1     2     3     4     5     6     7     8
        "back squat":   [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.38, 1.50, 2.00],
        "bench press":  [0.00, 0.25, 0.38, 0.50, 0.63, 0.75, 0.88, 1.00, 1.50],
        "deadlift":     [0.00, 0.50, 0.75, 1.00, 1.13, 1.25, 1.50, 1.75, 2.50],
        "overhead press":[0.00, 0.20, 0.28, 0.35, 0.43, 0.50, 0.63, 0.75, 1.00],
        "barbell row":  [0.00, 0.25, 0.33, 0.40, 0.53, 0.65, 0.78, 0.90, 1.20]
    ]

    /// Weighted pullup/dip added-load (kg) per tier. Bodyweight alone = novice.
    /// Index = RankTier ordinal 0…8.
    private static let weightedPullupAddedKg: [Double] =
        [0.0, 0.0, 5.0, 12.0, 18.0, 25.0, 32.0, 40.0, 60.0]

    // MARK: Accessory ratio tables (9-tier) — §3 male / §4 female

    /// MALE per-tier ratios for each accessory family. Index = ordinal 0…8.
    private static let accessoryMale: [AccessoryFamily: [Double]] = [
        //                   0     1     2     3     4     5     6     7     8
        .curl:           [0.00, 0.20, 0.30, 0.40, 0.50, 0.60, 0.73, 0.85, 1.15],
        .triceps:        [0.00, 0.25, 0.38, 0.50, 0.63, 0.75, 0.88, 1.00, 1.50],
        .legExtension:   [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.50, 1.75, 2.50],
        .legCurl:        [0.00, 0.50, 0.63, 0.75, 0.88, 1.00, 1.25, 1.50, 2.00],
        .calfRaise:      [0.00, 0.25, 0.50, 0.75, 1.00, 1.25, 1.63, 2.00, 3.00],
        .verticalPull:   [0.00, 0.50, 0.63, 0.75, 0.88, 1.00, 1.25, 1.50, 1.75],
        .hipThrust:      [0.00, 0.50, 0.75, 1.00, 1.38, 1.75, 2.13, 2.50, 3.50],
        .loadedAb:       [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.25, 1.50, 2.25]
    ]

    /// FEMALE per-tier ratios, authored from the cited per-family female bands
    /// (PHASE3-ACCESSORY-RATIOS §2 female / §4), same anchoring rule. Index 0…8.
    private static let accessoryFemale: [AccessoryFamily: [Double]] = [
        //                   0     1     2     3     4     5     6     7     8
        .curl:           [0.00, 0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.60, 0.85],
        .triceps:        [0.00, 0.15, 0.20, 0.25, 0.38, 0.50, 0.63, 0.75, 1.05],
        .legExtension:   [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.13, 1.25, 2.00],
        .legCurl:        [0.00, 0.25, 0.35, 0.45, 0.60, 0.75, 0.90, 1.05, 1.45],
        .calfRaise:      [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.38, 1.75, 2.50],
        .verticalPull:   [0.00, 0.30, 0.38, 0.45, 0.58, 0.70, 0.83, 0.95, 1.30],
        .hipThrust:      [0.00, 0.50, 0.75, 1.00, 1.25, 1.50, 1.88, 2.25, 3.00],
        .loadedAb:       [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.25, 1.50, 2.25]
    ]

    // MARK: Name resolution

    /// Compound aliases — variants inherit the compound parent's ratio table.
    /// Keyed by normalized exercise name (space-lowercase).
    private static let compoundAliases: [String: String] = [
        // squat / quad-dominant barbell+machine that track the squat ratio
        "squat": "back squat",
        "barbell back squat": "back squat",
        "front squat": "back squat",
        "safety bar squat": "back squat",
        "smith machine squat": "back squat",
        "goblet squat": "back squat",
        "hack squat": "back squat",
        "leg press": "back squat",
        "pendulum squat": "back squat",
        "v-squat machine": "back squat",
        "belt squat": "back squat",
        // bench / horizontal push
        "bench": "bench press",
        "barbell bench press": "bench press",
        "incline bench press": "bench press",
        "decline bench press": "bench press",
        "dumbbell bench press": "bench press",
        "incline dumbbell press": "bench press",
        "machine chest press": "bench press",
        "machine incline chest press": "bench press",
        "smith machine bench press": "bench press",
        "smith machine incline press": "bench press",
        "seated machine press": "overhead press",
        "close grip bench press": "bench press",
        // deadlift / hinge
        "conventional deadlift": "deadlift",
        "trap bar deadlift": "deadlift",
        "romanian deadlift": "deadlift",
        "dumbbell romanian deadlift": "deadlift",
        "smith machine romanian deadlift": "deadlift",
        "single-leg rdl": "deadlift",
        "good morning": "deadlift",
        // overhead press / vertical push
        "ohp": "overhead press",
        "military press": "overhead press",
        "barbell ohp": "overhead press",
        "dumbbell overhead press": "overhead press",
        "arnold press": "overhead press",
        "landmine press": "overhead press",
        "smith machine shoulder press": "overhead press",
        "plate loaded shoulder press": "overhead press",
        // barbell row / horizontal pull
        "bent-over row": "barbell row",
        "pendlay row": "barbell row",
        "t-bar row": "barbell row",
        "dumbbell row": "barbell row",
        "meadows row": "barbell row",
        "landmine row": "barbell row",
        "cable row (seated)": "barbell row",
        "wide grip cable row": "barbell row",
        "chest supported row": "barbell row",
        "machine row": "barbell row",
        "machine chest supported row": "barbell row",
        "plate loaded row": "barbell row",
        "hammer strength row": "barbell row",
        "hammer strength high row": "barbell row",
        "hammer strength low row": "barbell row",
        // weighted bodyweight (added-kg path)
        "weighted pull-up": "weighted pullup",
        "weighted chin": "weighted pullup",
        "weighted chin-up": "weighted pullup",
        "weighted dip": "weighted pullup"
    ]

    /// Accessory family members, keyed by normalized exercise name.
    private static let accessoryFamilyMap: [String: AccessoryFamily] = {
        var map: [String: AccessoryFamily] = [:]
        func add(_ names: [String], _ family: AccessoryFamily) {
            for name in names { map[name] = family }
        }
        // F1 — biceps curl (total)
        add([
            "barbell curl", "ez bar curl", "dumbbell curl", "incline dumbbell curl",
            "concentration curl", "spider curl", "cable curl", "rope cable curl",
            "hammer curl", "rope hammer curl", "preacher curl", "machine biceps curl",
            "band curl"
        ], .curl)
        // F2 — triceps extension (total)
        add([
            "tricep pushdown", "rope tricep pushdown", "straight bar tricep pushdown",
            "overhead tricep extension", "rope overhead tricep extension",
            "machine triceps extension", "band tricep extension", "skull crushers"
        ], .triceps)
        // F4 — leg extension (total)
        add(["leg extension", "single-leg extension"], .legExtension)
        // F5 — leg curl (total)
        add(["leg curl (lying)", "leg curl (seated)", "single-leg curl"], .legCurl)
        // F6 — calf raise (added load)
        add([
            "standing calf raise", "seated calf raise", "leg press calf raise",
            "smith machine calf raise", "donkey calf raise", "tibialis raise"
        ], .calfRaise)
        // F7 — machine vertical pull (total)
        add([
            "lat pulldown", "lat pulldown (neutral)", "wide grip lat pulldown",
            "close grip lat pulldown", "reverse grip lat pulldown", "single arm pulldown",
            "straight arm pulldown", "machine pullover", "band lat pull",
            "assisted pullup machine"
        ], .verticalPull)
        // F8 — hip thrust / glute (total incl. bar)
        add([
            "hip thrust", "smith machine hip thrust", "glute bridge", "cable pull through"
        ], .hipThrust)
        // F9 — loaded ab / trunk (total)
        add(["cable crunch", "machine crunch"], .loadedAb)
        return map
    }()

    /// Movements that earn XP but are explicitly NOT rank-badged (PHASE3-
    /// ACCESSORY-RATIOS §6). They must NOT inherit a wrong parent.
    private static let unrankedNames: Set<String> = [
        // F3 lateral / front / upright (momentum, not strength)
        "lateral raise (db)", "lateral raise (cable)", "machine lateral raise",
        "dumbbell front raise", "cable front raise", "cable y raise", "upright row",
        // F8 mis-routed isolation glute
        "cable glute kickback", "machine glute kickback",
        "hip abductor machine", "hip adductor machine", "cable hip abduction",
        // F9 anti-rotation / positional
        "pallof press", "landmine rotation",
        // ballistic
        "kettlebell swing"
    ]

    /// Dumbbell-pair movements logged per-hand that compare to a TOTAL-load
    /// family table → multiply logged load ×2 (PHASE3-ACCESSORY-RATIOS §3.1).
    /// Only F1 curls need this; F3 lateral stays per-hand (and is unranked).
    private static let dumbbellPairCurls: Set<String> = [
        "dumbbell curl", "incline dumbbell curl", "hammer curl"
    ]

    private static func normalize(_ exerciseKey: String) -> String {
        exerciseKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Canonical compound key for lookup — exact, alias, or substring match.
    static func canonicalKey(for exerciseKey: String) -> String? {
        let normalized = normalize(exerciseKey)
        if compoundMale[normalized] != nil { return normalized }
        if normalized.contains("weighted pullup") || normalized.contains("weighted pull") {
            return "weighted pullup"
        }
        if let alias = compoundAliases[normalized] { return alias }
        for key in compoundMale.keys where normalized.contains(key) { return key }
        return nil
    }

    /// True if the exercise is a tracked barbell-ratio compound (not weighted pullup).
    static func isBarbellLift(exerciseKey: String) -> Bool {
        let key = canonicalKey(for: exerciseKey)
        return key != nil && key != "weighted pullup"
    }

    /// Accessory family for an exercise, or nil if it isn't a load-ranked accessory.
    static func accessoryFamily(for exerciseKey: String) -> AccessoryFamily? {
        accessoryFamilyMap[normalize(exerciseKey)]
    }

    /// True if the movement is explicitly unranked (earns XP, no rank badge).
    static func isUnranked(exerciseKey: String) -> Bool {
        unrankedNames.contains(normalize(exerciseKey))
    }

    // MARK: Rank resolution

    /// Single entry point for LOADED movements: compound | accessory | weighted
    /// pullup. Returns nil for unranked / unrecognized / bodyweight-path movements.
    /// `liftKg` = heaviest working set. `sex` selects the male/female column
    /// (male default when nil). Preserves the `bodyweightKg > 0` guard.
    static func rank(
        liftKg: Double,
        bodyweightKg: Double,
        exerciseKey: String,
        sex: BiologicalSex?
    ) -> RankTier? {
        guard bodyweightKg > 0, liftKg > 0 else { return nil }
        let normalized = normalize(exerciseKey)

        // Unranked set must not inherit a parent.
        if unrankedNames.contains(normalized) { return nil }

        // Weighted pullup / dip — added-kg anchors.
        if canonicalKey(for: exerciseKey) == "weighted pullup" {
            return interpolate(value: max(0, liftKg), anchors: weightedPullupAddedKg)
        }

        // Compound (or compound variant) — bodyweight ratio.
        if let key = canonicalKey(for: exerciseKey) {
            let table = (sex == .female ? compoundFemale : compoundMale)
            guard let anchors = table[key] else { return nil }
            return interpolate(value: liftKg / bodyweightKg, anchors: anchors)
        }

        // Accessory family — bodyweight ratio (with DB ×2 for F1 dumbbell curls).
        if let family = accessoryFamilyMap[normalized] {
            let effectiveLoad = dumbbellPairCurls.contains(normalized) ? liftKg * 2 : liftKg
            let table = (sex == .female ? accessoryFemale : accessoryMale)
            guard let anchors = table[family] else { return nil }
            return interpolate(value: effectiveLoad / bodyweightKg, anchors: anchors)
        }

        return nil
    }

    /// Bodyweight-multiple ratio required to reach `tier` on a compound (or
    /// variant) or accessory family. Returns nil for weighted pullup (added-kg,
    /// not a ratio), unranked, and unrecognized movements. Used to build the
    /// library "next benchmark" text. ordinal 0 returns nil (no floor target).
    static func ratio(exerciseKey: String, tier: RankTier, sex: BiologicalSex?) -> Double? {
        let ord = tier.rawValue
        guard ord >= 1 else { return nil }
        let normalized = normalize(exerciseKey)
        if unrankedNames.contains(normalized) { return nil }

        if let key = canonicalKey(for: exerciseKey) {
            if key == "weighted pullup" { return nil }
            let table = (sex == .female ? compoundFemale : compoundMale)
            return table[key]?[ord]
        }
        if let family = accessoryFamilyMap[normalized] {
            let table = (sex == .female ? accessoryFemale : accessoryMale)
            return table[family]?[ord]
        }
        return nil
    }

    /// Added-load (kg) required to reach `tier` on the weighted pullup/dip path.
    static func weightedPullupAdded(tier: RankTier) -> Double? {
        let ord = tier.rawValue
        guard ord >= 1, ord < weightedPullupAddedKg.count else { return nil }
        return weightedPullupAddedKg[ord]
    }

    /// True for the weighted-pullup added-kg path (no bodyweight ratio).
    static func isWeightedPullup(exerciseKey: String) -> Bool {
        canonicalKey(for: exerciseKey) == "weighted pullup"
    }

    /// Back-compat shim: barbell + weighted-pullup path, male column.
    /// Retained for any caller that has no sex context.
    static func subRank(
        liftKg: Double,
        bodyweightKg: Double,
        exerciseKey: String
    ) -> RankTier? {
        rank(liftKg: liftKg, bodyweightKg: bodyweightKg, exerciseKey: exerciseKey, sex: nil)
    }

    // MARK: Interpolation

    /// Place a value on the 9-tier anchor ladder (index = ordinal 0…8) and
    /// return the nearest RankTier. Linear interpolation between adjacent
    /// anchors; below ordinal-1 ramps toward initiate; at/above top = ascendant.
    private static func interpolate(value: Double, anchors: [Double]) -> RankTier {
        guard anchors.count == 9 else { return .initiate }

        // Below the novice (ordinal 1) anchor — floor toward initiate.
        let novice = anchors[1]
        if value <= novice {
            // At half the novice anchor or below → initiate; ramp to novice at the anchor.
            let half = novice * 0.5
            if value <= half { return .initiate }
            let t = (value - half) / max(novice - half, 0.0001)
            return RankTier.nearest(for: t) // 0…1 → initiate…novice
        }

        if value >= anchors[8] { return .ascendant }

        for i in 1..<8 {
            let lo = anchors[i]
            let hi = anchors[i + 1]
            if value >= lo && value <= hi {
                let t = (value - lo) / max(hi - lo, 0.0001)
                return RankTier.nearest(for: Double(i) + t)
            }
        }
        return .ascendant
    }

    // MARK: Reps / hold ladders (mirror RankService bodyweightRepRank / holdRank)
    //
    // Bodyweight-rep and hold movements rank off their reps/seconds ladders, not
    // a load ratio. These anchors mirror `RankService.bodyweightRepRank` /
    // `holdRank` exactly (6 anchors: E, D, C, B, A, S → ordinals 0,1,4,7,10,16 on
    // the 1+3i ladder). Each anchor entry is `[6 ints]`; interpolation matches
    // RankService's `pos = 1 + 3i + t*3`, then `nearest(for: pos/2)`.

    /// Per-name reps ladder (peak reps → tier). Keyed by a name substring, in
    /// match order. Mirrors RankService.bodyweightRepRank.
    private static let repLadders: [(match: [String], anchors: [Int])] = [
        (["pullup", "pull-up", "chin-up", "chinup"], [0, 1, 5, 10, 15, 20]),
        (["pushup", "push-up"],                      [5, 15, 25, 40, 60, 80]),
        (["dip"],                                    [0, 3, 8, 15, 25, 35])
    ]

    /// Per-name hold ladder (peak seconds → tier). Mirrors RankService.holdRank.
    private static let holdLadders: [(match: [String], anchors: [Int])] = [
        (["l-sit", "lsit"],     [0, 5, 10, 20, 30, 45]),
        (["plank"],             [15, 30, 60, 90, 120, 180]),
        (["dead hang"],         [10, 20, 30, 45, 60, 90]),
        (["hollow hold"],       [10, 20, 30, 45, 60, 90])
    ]

    private static func ladderAnchors(for exerciseKey: String) -> [Int]? {
        let normalized = normalize(exerciseKey)
        for ladder in repLadders where ladder.match.contains(where: normalized.contains) {
            return ladder.anchors
        }
        for ladder in holdLadders where ladder.match.contains(where: normalized.contains) {
            return ladder.anchors
        }
        return nil
    }

    /// Continuous ladder position (0…8) for a reps/seconds value against a
    /// 6-anchor ladder, matching RankService's `pos = 1 + 3i + t*3` mapping.
    private static func ladderPosition(value: Int, anchors: [Int]) -> Double {
        guard let last = anchors.last else { return 0 }
        if value <= anchors[0] { return 0 }
        if value >= last { return 8 }
        for i in 0..<(anchors.count - 1) {
            let lo = anchors[i]
            let hi = anchors[i + 1]
            if value >= lo && value <= hi {
                let t = hi == lo ? 0 : Double(value - lo) / Double(hi - lo)
                return min(8, (Double(1 + 3 * i) + t * 3) / 2.0)
            }
        }
        return 8
    }

    // MARK: Progress to next rank (the reward "% to next" bar)
    //
    // Single derivation used by the post-workout reward flow: given the user's
    // best metric for a movement, how far between the current and next RankTier
    // they sit, plus what the next tier is.
    //
    //   - Loaded (compound / accessory / weighted pullup): fraction =
    //     (currentRatio − ratio(current)) / (ratio(next) − ratio(current)),
    //     where currentRatio = metricValue / bodyweight. Weighted pullup uses
    //     the added-kg anchors instead of a bodyweight ratio.
    //   - Rep / hold: same idea on the reps/seconds ladder — current value vs the
    //     current-tier threshold vs the next-tier threshold.
    //   - At peak (next == nil): fraction 1.0, "MAXED".
    //   - Unranked / unrecognized / cardio / carry: nil → reward shows "+X XP"
    //     with no rank bar.
    static func progressToNextRank(
        metricValue: Double,
        bodyweightKg: Double,
        exerciseKey: String,
        sex: BiologicalSex?
    ) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        guard metricValue > 0 else { return nil }
        let normalized = normalize(exerciseKey)
        if unrankedNames.contains(normalized) { return nil }

        // Reps / hold ladders — bodyweight-independent.
        if let anchors = ladderAnchors(for: exerciseKey) {
            let value = Int(metricValue.rounded())
            let position = ladderPosition(value: value, anchors: anchors)
            // The cleared tier is the floor of the ladder position; the fraction
            // is the distance toward the next integer tier.
            let current = RankTier(rawValue: Int(floor(position))) ?? .initiate
            return progress(current: current, position: position)
        }

        // Loaded — requires bodyweight.
        guard bodyweightKg > 0 else { return nil }

        // Weighted pullup / dip — added-kg anchors.
        if canonicalKey(for: exerciseKey) == "weighted pullup" {
            guard let current = rank(
                liftKg: metricValue,
                bodyweightKg: bodyweightKg,
                exerciseKey: "weighted pullup",
                sex: sex
            ) else { return nil }
            guard let next = current.next else { return (current, nil, 1.0) }
            let lo = weightedPullupAdded(tier: current) ?? weightedPullupAddedKg[current.rawValue]
            let hi = weightedPullupAdded(tier: next) ?? weightedPullupAddedKg[next.rawValue]
            return (current, next, clampFraction(value: metricValue, lo: lo, hi: hi))
        }

        // Compound / accessory — bodyweight ratio.
        guard let current = rank(
            liftKg: metricValue,
            bodyweightKg: bodyweightKg,
            exerciseKey: exerciseKey,
            sex: sex
        ) else { return nil }
        guard let next = current.next else { return (current, nil, 1.0) }
        let ratioNow = metricValue / bodyweightKg
        // Initiate (ordinal 0) has no ratio anchor; treat its floor as 0.
        let lo = ratio(exerciseKey: exerciseKey, tier: current, sex: sex) ?? 0
        guard let hi = ratio(exerciseKey: exerciseKey, tier: next, sex: sex) else {
            return (current, next, 1.0)
        }
        return (current, next, clampFraction(value: ratioNow, lo: lo, hi: hi))
    }

    /// Build the progress tuple from a continuous ladder position (reps/hold).
    private static func progress(
        current: RankTier,
        position: Double
    ) -> (current: RankTier, next: RankTier?, fraction: Double) {
        guard let next = current.next, current.rawValue < 8 else {
            return (current, nil, 1.0)
        }
        // Position is on the 0…8 ladder; the fraction between two adjacent tiers
        // is just the fractional part toward the next integer tier.
        let fraction = max(0.0, min(1.0, position - Double(current.rawValue)))
        return (current, next, fraction)
    }

    private static func clampFraction(value: Double, lo: Double, hi: Double) -> Double {
        guard hi > lo else { return 1.0 }
        return max(0.0, min(1.0, (value - lo) / (hi - lo)))
    }

    // MARK: Bodyweight-skill family mapping (unchanged)

    /// Map a ProgressionFamilyState tier (0–7) to a representative RankTier.
    static func subRank(forFamilyTier tier: Int) -> RankTier {
        switch max(0, tier) {
        case 0: return RankTier.nearest(for: 1.0 / 2.0)   // E  → initiate
        case 1: return RankTier.nearest(for: 4.0 / 2.0)   // D  → apprentice
        case 2: return RankTier.nearest(for: 7.0 / 2.0)   // C  → forged
        case 3: return RankTier.nearest(for: 8.0 / 2.0)   // C+ → veteran
        case 4: return RankTier.nearest(for: 10.0 / 2.0)  // B  → master
        case 5: return RankTier.nearest(for: 11.0 / 2.0)  // B+ → master
        case 6: return RankTier.nearest(for: 13.0 / 2.0)  // A  → vessel
        default: return RankTier.nearest(for: 16.0 / 2.0) // S  → ascendant
        }
    }
}
