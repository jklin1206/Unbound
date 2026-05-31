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

    // MARK: Standard tables (single source — split by category)
    //
    // Compound ratio tables live in CompoundStandards; accessory families + their
    // ratio tables + membership in AccessoryStandards; the explicit unranked set
    // in UnrankedMovements; weighted pull-up's %bw anchors on the
    // pp.weighted-pullup skill node (SkillStandards). This type is the resolver +
    // ranker that reads from them.

    /// Accessory family — re-exported so the public `accessoryFamily(for:)` and
    /// the rank/ratio bodies keep their existing names.
    typealias AccessoryFamily = AccessoryStandards.Family

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

    private static func normalize(_ exerciseKey: String) -> String {
        MovementResolution.normalizedKey(exerciseKey)
    }

    /// Canonical compound key for lookup — exact, alias, or substring match.
    static func canonicalKey(for exerciseKey: String) -> String? {
        let normalized = normalize(exerciseKey)
        if CompoundStandards.male[normalized] != nil { return normalized }
        if normalized.contains("weighted pullup") || normalized.contains("weighted pull") {
            return "weighted pullup"
        }
        if let alias = compoundAliases[normalized] { return alias }
        for key in CompoundStandards.male.keys where normalized.contains(key) { return key }
        return nil
    }

    /// True if the exercise is a tracked barbell-ratio compound (not weighted pullup).
    static func isBarbellLift(exerciseKey: String) -> Bool {
        let key = canonicalKey(for: exerciseKey)
        return key != nil && key != "weighted pullup"
    }

    /// Accessory family for an exercise, or nil if it isn't a load-ranked accessory.
    static func accessoryFamily(for exerciseKey: String) -> AccessoryFamily? {
        AccessoryStandards.membership[normalize(exerciseKey)]
    }

    /// True if the movement is explicitly unranked (earns XP, no rank badge).
    static func isUnranked(exerciseKey: String) -> Bool {
        UnrankedMovements.contains(normalize(exerciseKey))
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
        if UnrankedMovements.contains(normalized) { return nil }

        // Weighted pullup / dip — added load as %bodyweight (single source:
        // pp.weighted-pullup skill node).
        if canonicalKey(for: exerciseKey) == "weighted pullup" {
            guard let anchors = SkillStandards.weightedPullupRatioAnchors else { return nil }
            return interpolate(value: liftKg / bodyweightKg, anchors: anchors)
        }

        // Compound (or compound variant) — bodyweight ratio.
        if let key = canonicalKey(for: exerciseKey) {
            let table = (sex == .female ? CompoundStandards.female : CompoundStandards.male)
            guard let anchors = table[key] else { return nil }
            return interpolate(value: liftKg / bodyweightKg, anchors: anchors)
        }

        // Accessory family — bodyweight ratio (with DB ×2 for F1 dumbbell curls).
        if let family = AccessoryStandards.membership[normalized] {
            let effectiveLoad = AccessoryStandards.dumbbellPairs.contains(normalized) ? liftKg * 2 : liftKg
            let table = (sex == .female ? AccessoryStandards.female : AccessoryStandards.male)
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
        if UnrankedMovements.contains(normalized) { return nil }

        if let key = canonicalKey(for: exerciseKey) {
            if key == "weighted pullup" { return SkillStandards.weightedPullupRatio(tier: tier) }
            let table = (sex == .female ? CompoundStandards.female : CompoundStandards.male)
            return table[key]?[ord]
        }
        if let family = AccessoryStandards.membership[normalized] {
            let table = (sex == .female ? AccessoryStandards.female : AccessoryStandards.male)
            return table[family]?[ord]
        }
        return nil
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
        if UnrankedMovements.contains(normalized) { return nil }

        // Reps / hold bodyweight skills — ranked by the skill graph's tier
        // criteria (the single source, SkillStandards), so the reward bar
        // matches the tier the skill tree shows. `metricValue` is reps for rep
        // nodes and seconds for holds; SkillStandards reads whichever the node
        // uses.
        if SkillStandards.isBodyweightSkill(exerciseKey: exerciseKey) {
            let value = Int(metricValue.rounded())
            return SkillStandards.bodyweightProgress(
                exerciseKey: exerciseKey,
                peakReps: value,
                peakSeconds: value
            )
        }

        // Loaded — requires bodyweight.
        guard bodyweightKg > 0 else { return nil }

        // Compound / accessory / weighted pull-up — bodyweight ratio.
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
