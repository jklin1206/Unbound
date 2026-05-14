import Foundation

// MARK: - RankService
//
// Owns per-lift SubRank state. Triggered from ProgressionEngine on every
// ingested log. Emits `.rankAdvanced` when a lift crosses a new sub-rank
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

    // MARK: - Legacy SubRank Compute

    func computeLiftRank(
        entry: ExerciseLogEntry,
        bodyweightKg: Double
    ) -> SubRank? {
        let key = entry.exerciseName.trimmingCharacters(in: .whitespaces).lowercased()
        let workingSets = entry.sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return nil }

        // Barbell lift path: use heaviest working set.
        if StrengthStandards.isBarbellLift(exerciseKey: key) {
            let heaviest = workingSets.compactMap { $0.weightKg }.max() ?? 0
            return StrengthStandards.subRank(
                liftKg: heaviest,
                bodyweightKg: bodyweightKg,
                exerciseKey: key
            )
        }

        // Weighted pullup path: heaviest added load (weightKg column).
        if key.contains("weighted pullup") || key.contains("weighted pull-up") || key.contains("weighted chin") {
            let heaviest = workingSets.compactMap { $0.weightKg }.max() ?? 0
            return StrengthStandards.subRank(
                liftKg: heaviest,
                bodyweightKg: max(bodyweightKg, 1),
                exerciseKey: "weighted pullup"
            )
        }

        // Bodyweight rep lifts: map peak reps onto an E..S ladder.
        if let subRank = bodyweightRepRank(exerciseKey: key, entries: workingSets) {
            return subRank
        }

        // Hold-based (l-sit / plank): map peak reps-as-seconds.
        if let subRank = holdRank(exerciseKey: key, entries: workingSets) {
            return subRank
        }

        return nil
    }

    func evaluate(log: WorkoutLog, bodyweightKg: Double) async {
        guard bodyweightKg > 0 else {
            logger.log("RankService skipping evaluate — bodyweight unknown", level: .debug)
            return
        }
        for entry in log.exerciseEntries where !entry.skipped {
            guard let candidate = computeLiftRank(entry: entry, bodyweightKg: bodyweightKg) else { continue }

            let key = entry.exerciseName.trimmingCharacters(in: .whitespaces).lowercased()
            let id = "\(log.userId):\(key)"

            var existing: LiftRank? = try? await database.read(
                collection: "lift_ranks",
                documentId: id
            )

            if existing == nil {
                existing = LiftRank(
                    userId: log.userId,
                    exerciseKey: key,
                    displayName: entry.exerciseName,
                    currentRank: candidate,
                    peakRank: candidate,
                    lastAdvanceAt: log.startedAt,
                    lastActivityAt: log.startedAt
                )
                try? await database.create(existing!, collection: "lift_ranks", documentId: id)
                continue
            }

            var next = existing!
            next.lastActivityAt = log.startedAt

            if candidate > next.currentRank {
                let from = next.currentRank
                next.currentRank = candidate
                if candidate > next.peakRank { next.peakRank = candidate }
                next.lastAdvanceAt = log.startedAt
                try? await database.create(next, collection: "lift_ranks", documentId: id)

                let event = RankAdvance(
                    userId: log.userId,
                    exerciseKey: key,
                    displayName: entry.exerciseName,
                    fromRank: from,
                    toRank: candidate,
                    at: log.startedAt,
                    userBodyweightKg: bodyweightKg
                )
                NotificationCenter.default.post(
                    name: .rankAdvanced,
                    object: nil,
                    userInfo: ["event": event]
                )
                _ = await BadgeService.shared.evaluate(trigger: .rankAdvanced(event))
                logger.log(
                    "Rank advanced: \(entry.exerciseName) \(from.displayName) → \(candidate.displayName)",
                    level: .info
                )
            } else {
                try? await database.create(next, collection: "lift_ranks", documentId: id)
            }
        }
    }

    // MARK: BuildIdentity aggregate

    func aggregateRank(userId: String) async -> SubRank {
        // Derive BuildIdentity from the user's current attribute profile.
        let profile = AttributeService.shared.snapshot(userId: userId, asOf: Date.now)
        let identity = profile.buildIdentity

        // Pick the lifts to aggregate over based on shape.
        let lifts: [String]
        switch identity.shape {
        case .balancedAthlete, .hybridAthlete:
            // Top-3 axes by peak; union of their emphasis lifts (deduped).
            let topThree = AttributeKey.allCases
                .sorted { profile.value(for: $0).peak > profile.value(for: $1).peak }
                .prefix(3)
            var seen = Set<String>()
            var union: [String] = []
            for key in topThree {
                for lift in key.emphasisLifts where seen.insert(lift).inserted {
                    union.append(lift)
                }
            }
            lifts = union
        case .specialist, .hybrid, .lean:
            lifts = identity.primary?.emphasisLifts ?? []
        }

        guard !lifts.isEmpty else { return .eMinus }

        // Average currentRank ordinal across tracked emphasis lifts.
        let ranks = await fetchAll(userId: userId)
        let byKey: [String: LiftRank] = Dictionary(uniqueKeysWithValues: ranks.map { ($0.exerciseKey, $0) })
        let tracked: [Double] = lifts.compactMap { byKey[$0].map { Double($0.currentRank.ordinal) } }
        guard !tracked.isEmpty else { return .eMinus }
        let mean = tracked.reduce(0.0, +) / Double(lifts.count)
        return SubRank.nearest(for: mean)
    }

    /// Mean SubRank ordinal derived from family-tier state. Returns nil when
    /// the user has no family-tier records yet.
    private func familyTierOrdinalMean(userId: String) async -> Double? {
        let states = await ProgressionStateStore.shared.allFamilyStates(userId: userId)
        guard !states.isEmpty else { return nil }
        let ordinals = states.map { Double(StrengthStandards.subRank(forFamilyTier: $0.unlockedTier).ordinal) }
        return ordinals.reduce(0.0, +) / Double(ordinals.count)
    }

    func fetchAll(userId: String) async -> [LiftRank] {
        do {
            let ranks: [LiftRank] = try await database.query(
                collection: "lift_ranks",
                field: "userId",
                isEqualTo: userId,
                orderBy: "lastActivityAt",
                descending: true,
                limit: nil
            )
            return ranks
        } catch {
            logger.log("RankService fetchAll failed: \(error)", level: .warning)
            return []
        }
    }

    func save(_ rank: LiftRank) async {
        try? await database.create(rank, collection: "lift_ranks", documentId: rank.id)
    }

    // MARK: Private helpers

    /// Rep-based ladder for bodyweight moves: anchors tuned to feel
    /// attainable at C–B and elite at S.
    private func bodyweightRepRank(exerciseKey: String, entries: [SetLog]) -> SubRank? {
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
        if repsPeak <= letters[0] { return .eMinus }
        if repsPeak >= letters.last! { return .sPlus }

        for i in 0..<(letters.count - 1) {
            let lo = letters[i]
            let hi = letters[i + 1]
            if repsPeak >= lo && repsPeak <= hi {
                let t: Double = hi == lo ? 0 : Double(repsPeak - lo) / Double(hi - lo)
                let pos = Double(1 + 3 * i) + t * Double(3)
                return SubRank.nearest(for: pos)
            }
        }
        return .sPlus
    }

    /// Hold-based (seconds logged in the reps column — existing convention).
    private func holdRank(exerciseKey: String, entries: [SetLog]) -> SubRank? {
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

        if peakSeconds <= letters[0] { return .eMinus }
        if peakSeconds >= letters.last! { return .sPlus }

        for i in 0..<(letters.count - 1) {
            let lo = letters[i]
            let hi = letters[i + 1]
            if peakSeconds >= lo && peakSeconds <= hi {
                let t: Double = hi == lo ? 0 : Double(peakSeconds - lo) / Double(hi - lo)
                let pos = Double(1 + 3 * i) + t * Double(3)
                return SubRank.nearest(for: pos)
            }
        }
        return .sPlus
    }
}

// MARK: - MockRankService (tests + previews)

@MainActor
final class MockRankService: RankServiceProtocol {
    var ranks: [LiftRank] = []
    var aggregateRankOverride: SubRank = .c

    func computeTier(skill: SkillNode, history: [ExerciseLogEntry], bodyweightKg: Double) -> SkillTier { .initiate }
    func evaluateTierCrossings(log: WorkoutLog, userId: String) async -> [SkillTierAdvance] { [] }
    func state(userId: String) -> UserSkillTierState { .empty }
    func aggregateTier(userId: String) async -> SkillTier { .initiate }
    func computeLiftRank(entry: ExerciseLogEntry, bodyweightKg: Double) -> SubRank? { .c }
    func evaluate(log: WorkoutLog, bodyweightKg: Double) async {}
    func aggregateRank(userId: String) async -> SubRank { aggregateRankOverride }
    func fetchAll(userId: String) async -> [LiftRank] { ranks.filter { $0.userId == userId } }
    func save(_ rank: LiftRank) async {
        ranks.removeAll { $0.id == rank.id }
        ranks.append(rank)
    }
}
