import Foundation

// MARK: - RankService
//
// Owns per-lift RankTier state. Triggered from ProgressionEngine on every
// ingested log. Emits `.rankAdvanced` when a lift crosses a new RankTier
// threshold — the UI (RankUpCinematic) listens for this notification.
//
// Bodyweight-multiple lifts (squat/bench/DL/OHP) compute rank from
// bodyweight ratio against StrengthStandards. Weighted pullup uses
// added-load. Bodyweight-rep lifts (pullup/pushup/dip) use rep-based
// anchors. Holds (l-sit, plank) use seconds against the family tier map.

@MainActor
final class RankService: RankServiceProtocol {
    static let shared = RankService()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    // MARK: - SkillTier API (Phase 4.2+)

    func computeTier(
        skill: SkillNode,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> SkillTier {
        // Walk tiers from highest to lowest. First satisfied wins.
        for tier in SkillTier.allCases.reversed() {
            guard let criterion = skill.tierCriteria[tier] else { continue }
            if TierCriterionEvaluator.satisfied(
                criterion: criterion,
                history: history,
                bodyweightKg: bodyweightKg
            ) {
                return tier
            }
        }
        return .initiate
    }

    // MARK: - Ascension Tier Evaluation

    /// Evaluate tier crossings introduced by the new log.
    /// Fetches full log history, recomputes each skill's tier via computeTier,
    /// compares against prior UserSkillTierState, and returns the list of
    /// SkillTierAdvance events. Persists updated state when any crossing occurred.
    func evaluateTierCrossings(log: WorkoutLog, userId: String) async -> [SkillTierAdvance] {
        let tierStore = UserSkillTierStore.shared
        let priorState = tierStore.load(userId: userId)

        // Fetch user profile for bodyweight — same pattern as saveLog / RankService.evaluate.
        let profile: UserProfile? = try? await database.read(collection: "users", documentId: userId)
        let bodyweightKg = profile?.weightKg ?? 70.0

        // Fetch full log history ascending so cumulative tier criteria are correct.
        let allLogs: [WorkoutLog]
        do {
            allLogs = try await database.query(
                collection: "workoutLogs",
                field: "userId",
                isEqualTo: userId,
                orderBy: "startedAt",
                descending: false,
                limit: nil
            )
        } catch {
            logger.log("RankService.evaluateTierCrossings: failed to fetch logs: \(error)", level: .warning)
            return []
        }

        // Flatten all entries across full history. computeTier + TierCriterionEvaluator
        // handle per-exercise filtering internally via criterion exerciseName matching.
        let allEntries = allLogs.flatMap { $0.exerciseEntries }

        var newState = priorState
        var advances: [SkillTierAdvance] = []

        for node in SkillGraph.shared.nodes {
            guard !node.tierCriteria.isEmpty else { continue }

            let newTier = computeTier(skill: node, history: allEntries, bodyweightKg: bodyweightKg)
            let priorTier = priorState.tier(for: node.id)

            if newTier > priorTier {
                advances.append(SkillTierAdvance(skillId: node.id, from: priorTier, to: newTier))
                newState.perSkill[node.id] = newTier
                newState.rankUpsEarned += newTier.rawValue - priorTier.rawValue
                if newTier == .ascendant && !newState.ascendantSkills.contains(node.id) {
                    newState.ascendantSkills.append(node.id)
                }
            }
        }

        if !advances.isEmpty {
            tierStore.save(newState, userId: userId)
        }

        return advances
    }

    // MARK: - State + Aggregate Tier

    /// Load the full UserSkillTierState for a user. Used by views that need
    /// per-skill tier lookups without going through async evaluateTierCrossings.
    func state(userId: String) -> UserSkillTierState {
        UserSkillTierStore.shared.load(userId: userId)
    }

    /// Aggregate skill tier across all per-skill + per-lift states.
    /// Returns the highest tier reached.
    func aggregateTier(userId: String) async -> SkillTier {
        let skillState = UserSkillTierStore.shared.load(userId: userId)
        let skillTiers = Array(skillState.perSkill.values)
        let liftTiers = ["bench press", "back squat", "deadlift", "overhead press"].map {
            LiftTierService.shared.tier(lift: $0, userId: userId)
        }
        let all = skillTiers + liftTiers
        return all.max() ?? .initiate
    }

    // MARK: - Legacy lift-rank Compute

    func computeLiftRank(
        entry: ExerciseLogEntry,
        bodyweightKg: Double,
        sex: BiologicalSex? = nil
    ) -> RankTier? {
        let key = rankExerciseKey(for: entry)
        let workingSets = entry.sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return nil }

        // Explicitly unranked accessories earn XP but no rank badge.
        if StrengthStandards.isUnranked(exerciseKey: key) { return nil }

        // Loaded path: compound (or variant), accessory family, or weighted
        // pullup. StrengthStandards.rank resolves all three and returns the
        // sex-correct RankTier from a bodyweight-relative load ratio.
        if StrengthStandards.isBarbellLift(exerciseKey: key)
            || StrengthStandards.accessoryFamily(for: key) != nil {
            let heaviest = workingSets.compactMap { $0.weightKg }.max() ?? 0
            return StrengthStandards.rank(
                liftKg: heaviest,
                bodyweightKg: bodyweightKg,
                exerciseKey: key,
                sex: sex
            )
        }

        // Weighted pullup path: heaviest added load (weightKg column).
        if key.contains("weighted pullup") || key.contains("weighted pull-up") || key.contains("weighted chin") {
            let heaviest = workingSets.compactMap { $0.weightKg }.max() ?? 0
            return StrengthStandards.rank(
                liftKg: heaviest,
                bodyweightKg: max(bodyweightKg, 1),
                exerciseKey: "weighted pullup",
                sex: sex
            )
        }

        // Bodyweight rep lifts: map peak reps onto an E..S ladder.
        if !isRegressionOnlyBodyweightKey(key),
           let subRank = bodyweightRepRank(exerciseKey: key, entries: workingSets) {
            return subRank
        }

        // Hold-based (l-sit / plank): map peak reps-as-seconds.
        if let subRank = holdRank(exerciseKey: key, entries: workingSets) {
            return subRank
        }

        return nil
    }

    // In-memory session-scoped lift rank cache.
    // LiftRank Firestore persistence removed in rank-cleanup-v1.
    // evaluate() still fires .rankAdvanced so cinematic/badge triggers work.
    private var sessionRanks: [String: RankTier] = [:]

    func evaluate(log: WorkoutLog, bodyweightKg: Double, sex: BiologicalSex? = nil) async {
        guard bodyweightKg > 0 else {
            logger.log("RankService skipping evaluate — bodyweight unknown", level: .debug)
            return
        }
        for entry in log.exerciseEntries where !entry.skipped {
            guard let candidate = computeLiftRank(entry: entry, bodyweightKg: bodyweightKg, sex: sex) else { continue }

            let key = rankExerciseKey(for: entry)

            let existing = sessionRanks[key] ?? .initiate
            if candidate > existing {
                let event = RankAdvance(
                    userId: log.userId,
                    exerciseKey: key,
                    displayName: entry.exerciseName,
                    fromRank: existing,
                    toRank: candidate,
                    at: log.startedAt,
                    userBodyweightKg: bodyweightKg
                )
                sessionRanks[key] = candidate
                NotificationCenter.default.post(
                    name: .rankAdvanced,
                    object: nil,
                    userInfo: ["event": event]
                )
                _ = await BadgeService.shared.evaluate(trigger: .rankAdvanced(event))
                logger.log(
                    "Rank advanced: \(entry.exerciseName) \(existing.displayName) → \(candidate.displayName)",
                    level: .info
                )
            }
        }
    }

    // MARK: BuildIdentity aggregate (Phase 7 — accumulation)

    /// Overall rank = build-weighted, difficulty-weighted mean of the user's
    /// per-movement `RankTier`s, with honest decay. (Phase 7.)
    ///
    /// Each ranked movement contributes `score = ranktier.rawValue` weighted by
    /// `difficultyWeight × buildWeight × freshness`:
    ///   - difficultyWeight `1 + difficulty/8` (range 1.0–2.0): a hard move
    ///     counts up to 2×. Skills use `SkillNode.tier` (1–7); barbell compounds
    ///     use a fixed high intrinsic difficulty (the ratio-band ceiling).
    ///   - buildWeight: +0.5 if the move's top attribute axis == the profile's
    ///     primary build axis, +0.25 if == secondary (cap 1.75). Balanced /
    ///     hybrid builds have no axis to favor → flat 1.0.
    ///   - freshness: 1.0 when the move's axis is fresh, decaying to a 0.5 floor
    ///     once that axis goes stale (reuses `AttributeValue.isStale`). Rank is
    ///     dampened, never erased.
    ///
    /// Coverage guard: fewer than `coverageFloor` ranked movements can't push the
    /// weighted mean above Forged, so a day-1 single-lift spike can't inflate
    /// overall rank.
    func aggregateRank(userId: String) async -> RankTier {
        let entries = rankedMovementEntries(userId: userId)
        guard !entries.isEmpty else { return .initiate }

        let profile = AttributeProfileStore.shared.load(userId: userId)
            ?? .empty(userId: userId, at: .now)
        let build = profile.buildIdentity
        let now = Date()

        var weightedSum = 0.0
        var weightTotal = 0.0
        for entry in entries {
            let score = Double(entry.tier.rawValue)
            let weight = difficultyWeight(entry.difficulty)
                * buildWeight(topAxis: entry.topAxis, build: build)
                * freshness(topAxis: entry.topAxis, profile: profile, asOf: now)
            weightedSum += score * weight
            weightTotal += weight
        }
        guard weightTotal > 0 else { return .initiate }

        var overallRaw = weightedSum / weightTotal

        // Coverage guard: below a minimum of ranked movements, cap the
        // contribution at Forged (rawValue 3) so single-lift spikes can't
        // inflate the overall rank.
        if entries.count < Self.coverageFloor {
            overallRaw = min(overallRaw, Double(RankTier.forged.rawValue))
        }

        return RankTier.nearest(for: overallRaw)
    }

    /// Minimum ranked movements required before the weighted mean can exceed
    /// Forged.
    static let coverageFloor = 4

    /// Fixed intrinsic difficulty for tracked barbell compounds — they sit at
    /// the top of the strength ratio ladder, comparable to elite skill tiers.
    private static let barbellCompoundDifficulty = 6

    /// A ranked movement the user has trained, reduced to the three inputs the
    /// weighted mean needs.
    private struct RankedMovement {
        let tier: RankTier
        let difficulty: Int          // 1…7 (skill node tier) or the compound ceiling
        let topAxis: AttributeKey?   // dominant attributeWeights axis, nil if none
    }

    /// Collect per-movement ranks from the values `computeTier` (skills) and the
    /// lift-tier ladder already produce. Initiate-tier movements are skipped —
    /// they carry no signal.
    private func rankedMovementEntries(userId: String) -> [RankedMovement] {
        var entries: [RankedMovement] = []

        // Skills — per-skill SkillTier from the tier store.
        let skillState = UserSkillTierStore.shared.load(userId: userId)
        for (skillId, tier) in skillState.perSkill where tier > .initiate {
            let difficulty = SkillGraph.shared.node(id: skillId)?.tier ?? 1
            let weights = MovementCatalog.definition(for: "skill.\(skillId)")?.attributeWeights
            entries.append(
                RankedMovement(tier: tier, difficulty: difficulty, topAxis: topAxis(of: weights))
            )
        }

        // Barbell compounds — per-lift SkillTier from the lift-tier ladder.
        for lift in Self.aggregateLiftKeys {
            let tier = LiftTierService.shared.tier(lift: lift, userId: userId)
            guard tier > .initiate else { continue }
            let weights = MovementCatalog.definition(for: lift)?.attributeWeights
                ?? MovementCatalog.definition(for: MovementResolver.resolve(lift).movementId)?.attributeWeights
            entries.append(
                RankedMovement(
                    tier: tier,
                    difficulty: Self.barbellCompoundDifficulty,
                    topAxis: topAxis(of: weights)
                )
            )
        }

        return entries
    }

    private static let aggregateLiftKeys = ["bench press", "back squat", "deadlift", "overhead press"]

    /// `1 + difficulty/8`, clamped to the 1.0–2.0 range.
    private func difficultyWeight(_ difficulty: Int) -> Double {
        let clamped = max(0, min(8, difficulty))
        return min(2.0, max(1.0, 1.0 + Double(clamped) / 8.0))
    }

    /// Build alignment: +0.5 on the primary axis, +0.25 on the secondary, capped
    /// at 1.75. Balanced / hybrid-athlete builds have no axis to favor → 1.0.
    private func buildWeight(topAxis: AttributeKey?, build: BuildIdentity) -> Double {
        guard let topAxis else { return 1.0 }
        var weight = 1.0
        if let primary = build.primary, topAxis == primary { weight += 0.5 }
        else if let secondary = build.secondary, topAxis == secondary { weight += 0.25 }
        return min(1.75, weight)
    }

    /// 1.0 when the move's axis is fresh, 0.5 once it goes stale. Floors at 0.5 —
    /// rank is dampened by a layoff, never erased.
    private func freshness(topAxis: AttributeKey?, profile: AttributeProfile, asOf date: Date) -> Double {
        guard let topAxis else { return 1.0 }
        return profile.value(for: topAxis).isStale(asOf: date) ? 0.5 : 1.0
    }

    /// The highest-weighted attribute axis for a movement's `attributeWeights`.
    private func topAxis(of weights: [AttributeKey: Double]?) -> AttributeKey? {
        weights?.max(by: { $0.value < $1.value })?.key
    }

    // MARK: Private helpers

    /// Rep-based ladder for bodyweight moves: anchors tuned to feel
    /// attainable at C–B and elite at S.
    private func bodyweightRepRank(exerciseKey: String, entries: [SetLog]) -> RankTier? {
        let repsPeak = entries.map(\.reps).max() ?? 0
        guard repsPeak > 0 else { return nil }

        // Anchor reps at each letter: E, D, C, B, A, S.
        let anchors: [Int]?
        switch true {
        case exerciseKey.contains("pullup"), exerciseKey.contains("pull-up"), exerciseKey.contains("chin-up"), exerciseKey.contains("chinup"):
            anchors = [0, 1, 5, 10, 15, 20]
        case exerciseKey.contains("pushup"), exerciseKey.contains("push-up"):
            anchors = [5, 15, 25, 40, 60, 80]
        case exerciseKey.contains("dip"):
            anchors = [0, 3, 8, 15, 25, 35]
        default:
            anchors = nil
        }
        guard let letters = anchors else { return nil }

        // Map rep count against the ladder.
        if repsPeak <= letters[0] { return .initiate }
        if repsPeak >= letters.last! { return .ascendant }

        for i in 0..<(letters.count - 1) {
            let lo = letters[i]
            let hi = letters[i + 1]
            if repsPeak >= lo && repsPeak <= hi {
                let t: Double = hi == lo ? 0 : Double(repsPeak - lo) / Double(hi - lo)
                let pos = Double(1 + 3 * i) + t * Double(3)
                return RankTier.nearest(for: pos / 2.0)
            }
        }
        return .ascendant
    }

    /// Hold-based (seconds logged in the reps column — existing convention).
    private func holdRank(exerciseKey: String, entries: [SetLog]) -> RankTier? {
        let peakSeconds = entries.map(\.reps).max() ?? 0
        guard peakSeconds > 0 else { return nil }

        let anchors: [Int]?
        switch true {
        case exerciseKey.contains("l-sit"), exerciseKey.contains("lsit"):
            anchors = [0, 5, 10, 20, 30, 45]
        case exerciseKey.contains("plank"):
            anchors = [15, 30, 60, 90, 120, 180]
        case exerciseKey.contains("dead hang"):
            anchors = [10, 20, 30, 45, 60, 90]
        case exerciseKey.contains("hollow hold"):
            anchors = [10, 20, 30, 45, 60, 90]
        default:
            anchors = nil
        }
        guard let letters = anchors else { return nil }

        if peakSeconds <= letters[0] { return .initiate }
        if peakSeconds >= letters.last! { return .ascendant }

        for i in 0..<(letters.count - 1) {
            let lo = letters[i]
            let hi = letters[i + 1]
            if peakSeconds >= lo && peakSeconds <= hi {
                let t: Double = hi == lo ? 0 : Double(peakSeconds - lo) / Double(hi - lo)
                let pos = Double(1 + 3 * i) + t * Double(3)
                return RankTier.nearest(for: pos / 2.0)
            }
        }
        return .ascendant
    }

    private func rankExerciseKey(for entry: ExerciseLogEntry) -> String {
        if let key = canonicalMovementExerciseKey(for: entry.rankStandardMovementId) {
            return key
        }
        if let key = canonicalMovementExerciseKey(for: entry.movementId) {
            return key
        }

        let resolved = MovementResolver.resolve(entry.exerciseName)
        if let key = canonicalMovementExerciseKey(for: resolved.rankStandardMovementId) {
            return key
        }
        return normalizedKey(entry.exerciseName)
    }

    private func canonicalMovementExerciseKey(for movementId: String?) -> String? {
        guard let movementId, let definition = MovementCatalog.definition(for: movementId) else {
            return nil
        }
        if let canonical = definition.canonicalExerciseName {
            return normalizedKey(canonical)
        }
        return normalizedKey(definition.displayName)
    }

    private func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isRegressionOnlyBodyweightKey(_ key: String) -> Bool {
        let normalized = MovementCatalog.normalized(key)
        return ["assisted", "band", "banded", "machine", "negative", "jumping", "eccentric", "partial"]
            .contains { normalized.contains($0) }
    }
}

// MARK: - MockRankService (tests + previews)

@MainActor
final class MockRankService: RankServiceProtocol {
    var aggregateRankOverride: RankTier = .forged

    func computeTier(skill: SkillNode, history: [ExerciseLogEntry], bodyweightKg: Double) -> SkillTier { .initiate }
    func evaluateTierCrossings(log: WorkoutLog, userId: String) async -> [SkillTierAdvance] { [] }
    func state(userId: String) -> UserSkillTierState { .empty }
    func aggregateTier(userId: String) async -> SkillTier { .initiate }
    func computeLiftRank(entry: ExerciseLogEntry, bodyweightKg: Double, sex: BiologicalSex? = nil) -> RankTier? { .forged }
    func evaluate(log: WorkoutLog, bodyweightKg: Double, sex: BiologicalSex? = nil) async {}
    func aggregateRank(userId: String) async -> RankTier { aggregateRankOverride }
}
