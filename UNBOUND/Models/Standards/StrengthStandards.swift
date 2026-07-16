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
    ///
    /// This is LAYER 2 of variant resolution: a canonical movement key →
    /// bw-ratio compound. `MovementCatalog.variantRankStandardNames` is layer 1
    /// (catalog variant → canonical base); a logged lift is collapsed to its
    /// base before `computeLiftRank` reaches here. The variant-level entries
    /// below are a fallback for free-text logs that never got a resolved
    /// movementId. Where a key lives in BOTH maps the two paths must resolve to
    /// the same compound — locked by `VariantStandardConsistencyTests` (dup#4).
    /// `internal` (not private) so that test can read it.
    static let compoundAliases: [String: String] = [
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
        "box squat": "back squat",
        "zercher squat": "back squat",
        // Per-leg load on roughly half a bilateral leg-press stack lands in
        // the squat table's ballpark — same accepted approximation as leg press.
        "single-leg press": "back squat",
        // lunges / loaded single-leg — StrengthLevel barbell-lunge table
        // (total load). Loaded split squats and step-ups share it; their
        // bodyweight twins still rank via the skill nodes.
        "reverse lunge": "lunge",
        "lateral lunge": "lunge",
        "curtsy lunge": "lunge",
        "front rack lunge": "lunge",
        "bulgarian split squat": "lunge",
        "smith machine split squat": "lunge",
        "dumbbell step up": "lunge",
        // machine dip presses track the close-grip-bench pattern
        "dip machine": "bench press",
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
        "floor press": "bench press",
        "dumbbell floor press": "bench press",
        "decline dumbbell press": "bench press",
        // deadlift / hinge
        "conventional deadlift": "deadlift",
        "trap bar deadlift": "deadlift",
        "romanian deadlift": "deadlift",
        "dumbbell romanian deadlift": "deadlift",
        "smith machine romanian deadlift": "deadlift",
        "single-leg rdl": "deadlift",
        "good morning": "deadlift",
        "sumo deadlift": "deadlift",
        "deficit deadlift": "deadlift",
        "snatch grip deadlift": "deadlift",
        "stiff leg deadlift": "deadlift",
        // olympic / explosive barbell — StrengthLevel power-clean and snatch
        // tables; hang clean and clean & jerk track the clean, high pull runs
        // a touch harsh against the clean table (lighter loads by design).
        "hang clean": "power clean",
        "clean and jerk": "power clean",
        "barbell high pull": "power clean",
        "power snatch": "snatch",
        "thruster": "push press",
        // overhead press / vertical push
        "ohp": "overhead press",
        "military press": "overhead press",
        "barbell ohp": "overhead press",
        "dumbbell overhead press": "overhead press",
        "arnold press": "overhead press",
        "landmine press": "overhead press",
        "smith machine shoulder press": "overhead press",
        "plate loaded shoulder press": "overhead press",
        "seated dumbbell shoulder press": "overhead press",
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
        "seal row": "barbell row",
        "yates row": "barbell row",
        "incline dumbbell row": "barbell row",
        "smith machine row": "barbell row",
        "band row": "barbell row",
        "single-arm cable row": "barbell row",
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

        if value >= anchors[8] { return .unbound }

        for i in 1..<8 {
            let lo = anchors[i]
            let hi = anchors[i + 1]
            if value >= lo && value <= hi {
                let t = (value - lo) / max(hi - lo, 0.0001)
                return RankTier.nearest(for: Double(i) + t)
            }
        }
        return .unbound
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

        if let bodyweightProgress = bodyweightProgress(
            metricValue: metricValue,
            exerciseKey: exerciseKey
        ) {
            return bodyweightProgress
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
        let effectiveMetric = effectiveLoadedMetric(metricValue, exerciseKey: exerciseKey)
        let ratioNow = effectiveMetric / bodyweightKg
        // Initiate (ordinal 0) has no ratio anchor; treat its floor as 0.
        let lo = ratio(exerciseKey: exerciseKey, tier: current, sex: sex) ?? 0
        guard let hi = ratio(exerciseKey: exerciseKey, tier: next, sex: sex) else {
            return (current, next, 1.0)
        }
        return (current, next, clampFraction(value: ratioNow, lo: lo, hi: hi))
    }

    private static func effectiveLoadedMetric(_ metricValue: Double, exerciseKey: String) -> Double {
        let normalized = normalize(exerciseKey)
        return AccessoryStandards.dumbbellPairs.contains(normalized) ? metricValue * 2 : metricValue
    }

    // MARK: Bodyweight exercise fallback

    private enum BodyweightMetricKind {
        case reps
        case seconds
    }

    /// Rankable exercise-library bodyweight reps/holds that are not part of the
    /// canonical SkillStandards subset still need a real ladder. Prefer authored
    /// skill-node criteria when the exercise maps cleanly; otherwise use
    /// conservative movement-family ladders.
    private static func bodyweightProgress(
        metricValue: Double,
        exerciseKey: String
    ) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        let resolved = MovementResolver.resolve(exerciseKey)
        guard resolved.rankable else { return nil }

        let metricKind: BodyweightMetricKind
        switch resolved.rankTemplate {
        case .bodyweightReps:
            metricKind = .reps
        case .holdControl:
            metricKind = .seconds
        default:
            return nil
        }

        if let criteria = matchingBodyweightSkillCriteria(
            for: exerciseKey,
            metricKind: metricKind
        ) {
            return progress(metricValue: metricValue, criteria: criteria, metricKind: metricKind)
        }

        let definition = MovementCatalog.definition(for: resolved.rankStandardMovementId)
            ?? MovementCatalog.definition(for: resolved.movementId)
        guard let anchors = fallbackBodyweightAnchors(
            for: exerciseKey,
            definition: definition,
            metricKind: metricKind
        ) else { return nil }

        return progress(metricValue: metricValue, anchors: anchors)
    }

    private static func matchingBodyweightSkillCriteria(
        for exerciseKey: String,
        metricKind: BodyweightMetricKind
    ) -> [SkillTier: TierCriterion]? {
        for node in SkillGraph.shared.nodes {
            let criteria = node.tierCriteria
            guard !criteria.isEmpty,
                  criteriaContainsMetric(criteria, metricKind: metricKind),
                  criteriaReferencesExercise(criteria, exerciseKey: exerciseKey, metricKind: metricKind)
            else { continue }
            return criteria
        }
        return nil
    }

    private static func criteriaContainsMetric(
        _ criteria: [SkillTier: TierCriterion],
        metricKind: BodyweightMetricKind
    ) -> Bool {
        criteria.values.contains { threshold($0, metricKind: metricKind) != nil }
    }

    private static func criteriaReferencesExercise(
        _ criteria: [SkillTier: TierCriterion],
        exerciseKey: String,
        metricKind: BodyweightMetricKind
    ) -> Bool {
        criteria.values.contains {
            criterionReferencesExercise($0, exerciseKey: exerciseKey, metricKind: metricKind)
        }
    }

    private static func criterionReferencesExercise(
        _ criterion: TierCriterion,
        exerciseKey: String,
        metricKind: BodyweightMetricKind
    ) -> Bool {
        switch criterion {
        case .reps(_, let exerciseName) where metricKind == .reps:
            return exerciseNameMatches(logged: exerciseKey, required: exerciseName)
        case .exerciseSeconds(_, let exerciseName) where metricKind == .seconds:
            return exerciseNameMatches(logged: exerciseKey, required: exerciseName)
        case .compound(let criteria):
            return criteria.contains {
                criterionReferencesExercise($0, exerciseKey: exerciseKey, metricKind: metricKind)
            }
        default:
            return false
        }
    }

    private static let bodyweightCriterionAliases: [String: Set<String>] = [
        "ab wheel kneeling": ["ab wheel", "kneeling ab wheel"],
        "decline sit up": ["decline situp"],
        "inverted sit up": ["inverted situp", "roman chair situp"],
        "jumping squat": ["jump squat", "squat jump"],
        "bodyweight leg extension": ["bodyweight leg extensions", "reverse nordic", "reverse nordic curl", "kneeling leg extension"],
        "weighted pistol": ["weighted pistol squat"],
        "row": ["inverted row", "bodyweight row", "ring row", "australian row"],
        "pullup": ["neutral grip pullup"]
    ]

    private static func exerciseNameMatches(logged: String, required: String) -> Bool {
        if MovementProofMatcher.namesMatch(logged: logged, required: required) {
            return true
        }

        let loggedKey = MovementCatalog.normalized(logged)
        let requiredKey = MovementCatalog.normalized(required)
        if loggedKey == requiredKey { return true }

        if bodyweightCriterionAliases[requiredKey]?.contains(loggedKey) == true {
            return true
        }
        if bodyweightCriterionAliases[loggedKey]?.contains(requiredKey) == true {
            return true
        }
        return false
    }

    private static let namedRepFallbackLevels: [String: [Double]] = [
        "bodyweight squat": [1, 17, 56, 107, 167],
        "assisted squat": [5, 12, 25, 45, 70],
        "parallel squat": [5, 15, 35, 60, 90],
        "walking lunge": [1, 11, 37, 69, 105],
        "split squat": [5, 14, 30, 50, 75],
        "deep step up": [5, 12, 24, 40, 60],
        "cossack squat": [3, 8, 16, 30, 50],
        "partial pistol squat": [3, 6, 12, 20, 32],
        "assisted pistol squat": [3, 8, 15, 25, 40],
        "assisted shrimp squat": [3, 8, 15, 25, 40],
        "beginner shrimp squat": [2, 5, 10, 18, 28],
        "intermediate shrimp squat": [1, 3, 7, 12, 20],
        // Keys are looked up via MovementCatalog.normalized (hyphens become
        // spaces) — hyphenated keys never match.
        "two hand shrimp squat": [1, 2, 4, 8, 12],
        "elevated two hand shrimp squat": [1, 2, 3, 5, 8],
        "nordic curl negative": [1, 3, 5, 8, 12],
        "nordic curl arms overhead": [1, 2, 3, 5, 8],
        "tuck one leg nordic curl": [1, 2, 3, 4, 6],
        "one leg nordic curl": [1, 2, 3, 4, 6],
        "superman pull": [5, 15, 30, 55, 85],
        "captains chair knee raise": [5, 10, 18, 30, 45],
        "captains chair leg raise": [1, 4, 8, 12, 20],
        "hollow rock": [5, 12, 25, 45, 70],
        "roman chair situp": [3, 10, 25, 45, 70],
        // 2026-07 core additions. Sit-up anchors to the StrengthLevel
        // sit-ups row (<1/23/57/99/146); the rest are monotonic bands
        // relative to it and the crunch node, per this file's convention.
        "situp": [1, 23, 57, 99, 146],
        "bicycle crunch": [5, 20, 45, 80, 120],
        "russian twist": [10, 25, 50, 85, 130],
        "v-up": [3, 10, 22, 40, 60],
        "flutter kick": [10, 30, 60, 100, 150],
        "mountain climber": [10, 30, 60, 100, 150],
        "dead bug": [5, 15, 30, 55, 85],
        "bird dog": [5, 15, 30, 55, 85]
    ]

    private static func fallbackBodyweightAnchors(
        for exerciseKey: String,
        definition: MovementDefinition?,
        metricKind: BodyweightMetricKind
    ) -> [Double]? {
        var lookupKeys = [MovementCatalog.normalized(exerciseKey)]
        if let canonical = definition?.canonicalExerciseName {
            lookupKeys.append(MovementCatalog.normalized(canonical))
        }
        if let displayName = definition?.displayName {
            lookupKeys.append(MovementCatalog.normalized(displayName))
        }

        switch metricKind {
        case .reps:
            for key in lookupKeys {
                if let levels = namedRepFallbackLevels[key] {
                    return tierAnchors(from: levels)
                }
            }
            return tierAnchors(from: genericRepLevels(for: definition))
        case .seconds:
            return tierAnchors(from: genericHoldLevels(for: definition))
        }
    }

    private static func genericRepLevels(for definition: MovementDefinition?) -> [Double] {
        switch definition?.difficulty ?? .beginner {
        case .beginner:
            return [5, 12, 25, 45, 70]
        case .intermediate:
            return [3, 8, 16, 28, 45]
        case .advanced:
            return [1, 3, 7, 12, 20]
        case .elite:
            return [1, 2, 4, 7, 12]
        }
    }

    private static func genericHoldLevels(for definition: MovementDefinition?) -> [Double] {
        switch definition?.difficulty ?? .beginner {
        case .beginner:
            return [10, 20, 45, 90, 150]
        case .intermediate:
            return [5, 15, 30, 60, 120]
        case .advanced:
            return [3, 8, 15, 30, 60]
        case .elite:
            return [2, 5, 10, 20, 45]
        }
    }

    private static func tierAnchors(from levels: [Double]) -> [Double]? {
        guard levels.count == 5 else { return nil }
        return SkillTierGenerator.interpolate(levels: levels).map { max(1, $0.rounded()) }
    }

    private static func progress(
        metricValue: Double,
        criteria: [SkillTier: TierCriterion],
        metricKind: BodyweightMetricKind
    ) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        let current = rank(metricValue: metricValue, criteria: criteria, metricKind: metricKind)
        guard let next = current.next else { return (current, nil, 1.0) }
        let lo = current == .initiate ? 0 : (criteria[current].flatMap { threshold($0, metricKind: metricKind) } ?? 0)
        guard let hi = criteria[next].flatMap({ threshold($0, metricKind: metricKind) }) else {
            return (current, next, 1.0)
        }
        return (current, next, clampFraction(value: metricValue, lo: lo, hi: hi))
    }

    private static func rank(
        metricValue: Double,
        criteria: [SkillTier: TierCriterion],
        metricKind: BodyweightMetricKind
    ) -> RankTier {
        for tier in SkillTier.allCases.reversed() {
            guard let criterion = criteria[tier],
                  let value = threshold(criterion, metricKind: metricKind),
                  metricValue >= value
            else { continue }
            return tier
        }
        return .initiate
    }

    private static func threshold(
        _ criterion: TierCriterion,
        metricKind: BodyweightMetricKind
    ) -> Double? {
        switch criterion {
        case .reps(let value, _) where metricKind == .reps:
            return Double(value)
        case .exerciseSeconds(let value, _) where metricKind == .seconds:
            return Double(value)
        case .compound(let criteria):
            let thresholds = criteria.compactMap { threshold($0, metricKind: metricKind) }
            return thresholds.isEmpty ? nil : thresholds.max()
        default:
            return nil
        }
    }

    private static func progress(
        metricValue: Double,
        anchors: [Double]
    ) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        guard anchors.count == 9 else { return nil }
        let current = rank(metricValue: metricValue, anchors: anchors)
        guard let next = current.next else { return (current, nil, 1.0) }
        let lo = current == .initiate ? 0 : anchors[current.rawValue]
        let hi = anchors[next.rawValue]
        return (current, next, clampFraction(value: metricValue, lo: lo, hi: hi))
    }

    private static func rank(metricValue: Double, anchors: [Double]) -> RankTier {
        for tier in RankTier.allCases.reversed() where metricValue >= anchors[tier.rawValue] {
            return tier
        }
        return .initiate
    }

    private static func clampFraction(value: Double, lo: Double, hi: Double) -> Double {
        guard hi > lo else { return 1.0 }
        return max(0.0, min(1.0, (value - lo) / (hi - lo)))
    }
}
