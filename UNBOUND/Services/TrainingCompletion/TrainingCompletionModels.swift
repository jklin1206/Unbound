import Foundation

struct TrainingCompletionResult: Sendable {
    var savedPerformanceLogId: String?
    var savedWorkoutLogId: String?
    var savedSessionLogIds: [String] = []
    var wasAlreadyCompleted: Bool = false
    var movementAPGains: [MovementAPGain] = []
    var movementProgressStates: [MovementProgressState] = []
    /// Per-standard state BEFORE this log, for prior-rank (rank-up) detection.
    var movementProgressPriorStates: [String: MovementProgressState] = [:]
    var updatedMovementProgressIds: [String] = []
    var attributeRewards: [AttributeProgressionReward] = []
    var attributeProfileBefore: AttributeProfile?
    var attributeProfileAfter: AttributeProfile?
    var attributeRankUpEventCount: Int = 0
    var bodyMapNoveltyMultiplier: Double = 1.0
    var bodyMapRegionRewards: [BodyMapRegionReward] = []
    var overallLevelReward: OverallLevelReward?
    var overallLevelXPGained: Double = 0
    var skillXPGained: Int = 0
    /// Currency earned for the session. Legacy storage still uses "vows" keys,
    /// but the surfaced shop currency is Arcs.
    var arcsEarned: Int = 0
    var proofEngineResult: ProofEngineResult?
    var skillTrainingReviews: [SkillTrainingAgentReview] = []

    /// Day-streak after counting this session, and whether this session extended
    /// it (false = a same-day session that holds, or already-completed).
    var streakCount: Int = 0
    var streakExtended: Bool = false

    /// Skill-tree skins this session's rank progress unlocked (surfaced in the
    /// reward flow instead of a silent toast).
    var unlockedSkins: [SkillTreeSkin] = []

    /// User bodyweight + sex at completion, captured so the per-movement reward
    /// lines can derive each movement's "% to next rank" via StrengthStandards.
    var bodyweightKg: Double = 0
    var biologicalSex: BiologicalSex?

    var totalMovementAP: Double {
        movementAPGains.reduce(0) { $0 + $1.rawAP }
    }

    var totalAttributeXPGained: Double {
        attributeRewards.reduce(0) { $0 + $1.xpGained }
    }

    init() {}

    init(record: TrainingCompletionRecord, wasAlreadyCompleted: Bool) {
        self.savedPerformanceLogId = record.performanceLogId
        self.savedWorkoutLogId = record.workoutLogId
        self.savedSessionLogIds = record.sessionLogIds
        if let replay = record.replay {
            self.apply(replay: replay)
        }
        self.wasAlreadyCompleted = wasAlreadyCompleted
    }

    init(receipt: TrainingCompletionReplayReceipt, wasAlreadyCompleted: Bool) {
        self.savedPerformanceLogId = receipt.performanceLogId
        self.savedWorkoutLogId = receipt.workoutLogId
        self.savedSessionLogIds = receipt.sessionLogIds
        self.apply(replay: receipt.replay)
        self.wasAlreadyCompleted = wasAlreadyCompleted
    }

    init(progressionReceipt: TrainingCompletionProgressionReceipt, wasAlreadyCompleted: Bool) {
        self.savedPerformanceLogId = progressionReceipt.performanceLogId
        self.apply(replay: progressionReceipt.replay)
        self.wasAlreadyCompleted = wasAlreadyCompleted
    }

    mutating func apply(replay: TrainingCompletionReplay) {
        movementAPGains = replay.movementAPGains
        movementProgressStates = replay.movementProgressStates
        movementProgressPriorStates = replay.movementProgressPriorStates
        updatedMovementProgressIds = replay.updatedMovementProgressIds
        attributeRewards = replay.attributeRewards
        attributeProfileBefore = replay.attributeProfileBefore
        attributeProfileAfter = replay.attributeProfileAfter
        attributeRankUpEventCount = replay.attributeRankUpEventCount
        bodyMapNoveltyMultiplier = replay.bodyMapNoveltyMultiplier
        bodyMapRegionRewards = replay.bodyMapRegionRewards
        overallLevelReward = replay.overallLevelReward
        overallLevelXPGained = replay.overallLevelXPGained
        skillXPGained = replay.skillXPGained
        arcsEarned = replay.arcsEarned ?? 0
        proofEngineResult = replay.proofEngineResult
        skillTrainingReviews = replay.skillTrainingReviews ?? []
        streakCount = replay.streakCount
        streakExtended = replay.streakExtended
        unlockedSkins = replay.unlockedSkins
        bodyweightKg = replay.bodyweightKg
        biologicalSex = replay.biologicalSex
    }

    mutating func mergeProgression(from other: TrainingCompletionResult) {
        movementAPGains = other.movementAPGains
        movementProgressStates = other.movementProgressStates
        movementProgressPriorStates = other.movementProgressPriorStates
        updatedMovementProgressIds = other.updatedMovementProgressIds
        attributeRewards = other.attributeRewards
        attributeProfileBefore = other.attributeProfileBefore
        attributeProfileAfter = other.attributeProfileAfter
        attributeRankUpEventCount = other.attributeRankUpEventCount
        bodyMapNoveltyMultiplier = other.bodyMapNoveltyMultiplier
        bodyMapRegionRewards = other.bodyMapRegionRewards
        overallLevelReward = other.overallLevelReward
        overallLevelXPGained = other.overallLevelXPGained
        proofEngineResult = other.proofEngineResult
        skillTrainingReviews = other.skillTrainingReviews
        bodyweightKg = other.bodyweightKg
        biologicalSex = other.biologicalSex
    }

    mutating func appendOverallLevelReward(_ reward: OverallLevelReward) {
        guard reward.xpGained > 0 else { return }

        if let existing = overallLevelReward {
            overallLevelReward = OverallLevelReward(
                xpGained: existing.xpGained + reward.xpGained,
                noveltyMultiplier: existing.noveltyMultiplier,
                previousXP: existing.previousXP,
                currentXP: reward.currentXP,
                previousLevel: existing.previousLevel,
                currentLevel: reward.currentLevel,
                previousProgressToNextLevel: existing.previousProgressToNextLevel,
                currentProgressToNextLevel: reward.currentProgressToNextLevel
            )
            overallLevelXPGained = existing.xpGained + reward.xpGained
        } else {
            overallLevelReward = reward
            overallLevelXPGained = reward.xpGained
        }
    }
}

extension WorkoutProofSource {
    init(_ source: TrainingSessionSource) {
        switch source {
        case .program:
            self = .generated
        case .skill:
            self = .skillPractice
        case .custom, .routine, .cardio:
            self = .custom
        case .vow:
            self = .vow
        case .overallRankTrial:
            self = .retest
        }
    }
}

struct TrainingCompletionRecord: Codable, Identifiable, Sendable {
    let id: String
    let performanceLogId: String
    let userId: String
    let completedAt: Date
    let workoutLogId: String?
    let sessionLogIds: [String]
    let replay: TrainingCompletionReplay?

    init(result: TrainingCompletionResult, performanceLog: PerformanceLog) {
        self.id = performanceLog.id
        self.performanceLogId = performanceLog.id
        self.userId = performanceLog.userId
        self.completedAt = performanceLog.completedAt
        self.workoutLogId = result.savedWorkoutLogId
        self.sessionLogIds = result.savedSessionLogIds
        self.replay = TrainingCompletionReplay(result: result)
    }
}

struct TrainingCompletionReplayReceipt: Codable, Identifiable, Sendable {
    let id: String
    let performanceLogId: String
    let userId: String
    let completedAt: Date
    let workoutLogId: String?
    let sessionLogIds: [String]
    let replay: TrainingCompletionReplay

    init(result: TrainingCompletionResult, performanceLog: PerformanceLog) {
        self.id = performanceLog.id
        self.performanceLogId = performanceLog.id
        self.userId = performanceLog.userId
        self.completedAt = performanceLog.completedAt
        self.workoutLogId = result.savedWorkoutLogId
        self.sessionLogIds = result.savedSessionLogIds
        self.replay = TrainingCompletionReplay(result: result)
    }
}

struct TrainingCompletionProgressionReceipt: Codable, Identifiable, Sendable {
    let id: String
    let performanceLogId: String
    let userId: String
    let completedAt: Date
    let replay: TrainingCompletionReplay

    init(result: TrainingCompletionResult, performanceLog: PerformanceLog) {
        self.id = performanceLog.id
        self.performanceLogId = performanceLog.id
        self.userId = performanceLog.userId
        self.completedAt = performanceLog.completedAt
        self.replay = TrainingCompletionReplay(result: result)
    }
}

struct TrainingCompletionOverloadReceipt: Codable, Identifiable, Sendable {
    let id: String
    let performanceLogId: String
    let workoutLogId: String
    let userId: String
    let completedAt: Date

    init(performanceLog: PerformanceLog, workoutLog: WorkoutLog) {
        self.id = performanceLog.id
        self.performanceLogId = performanceLog.id
        self.workoutLogId = workoutLog.id
        self.userId = performanceLog.userId
        self.completedAt = performanceLog.completedAt
    }
}

struct TrainingCompletionReplay: Codable, Sendable {
    var movementAPGains: [MovementAPGain]
    var movementProgressStates: [MovementProgressState]
    var movementProgressPriorStates: [String: MovementProgressState]
    var updatedMovementProgressIds: [String]
    var attributeRewards: [AttributeProgressionReward]
    var attributeProfileBefore: AttributeProfile?
    var attributeProfileAfter: AttributeProfile?
    var attributeRankUpEventCount: Int
    var bodyMapNoveltyMultiplier: Double
    var bodyMapRegionRewards: [BodyMapRegionReward]
    var overallLevelReward: OverallLevelReward?
    var overallLevelXPGained: Double
    var skillXPGained: Int
    var arcsEarned: Int?
    var proofEngineResult: ProofEngineResult?
    var skillTrainingReviews: [SkillTrainingAgentReview]?
    var streakCount: Int
    var streakExtended: Bool
    var unlockedSkins: [SkillTreeSkin]
    var bodyweightKg: Double
    var biologicalSex: BiologicalSex?

    init(result: TrainingCompletionResult) {
        movementAPGains = result.movementAPGains
        movementProgressStates = result.movementProgressStates
        movementProgressPriorStates = result.movementProgressPriorStates
        updatedMovementProgressIds = result.updatedMovementProgressIds
        attributeRewards = result.attributeRewards
        attributeProfileBefore = result.attributeProfileBefore
        attributeProfileAfter = result.attributeProfileAfter
        attributeRankUpEventCount = result.attributeRankUpEventCount
        bodyMapNoveltyMultiplier = result.bodyMapNoveltyMultiplier
        bodyMapRegionRewards = result.bodyMapRegionRewards
        overallLevelReward = result.overallLevelReward
        overallLevelXPGained = result.overallLevelXPGained
        skillXPGained = result.skillXPGained
        arcsEarned = result.arcsEarned
        proofEngineResult = result.proofEngineResult
        skillTrainingReviews = result.skillTrainingReviews
        streakCount = result.streakCount
        streakExtended = result.streakExtended
        unlockedSkins = result.unlockedSkins
        bodyweightKg = result.bodyweightKg
        biologicalSex = result.biologicalSex
    }
}

extension TrainingCompletionResult {
    var progressionReceipt: ProgressionReceipt {
        let statesByStandard = Dictionary(uniqueKeysWithValues: movementProgressStates.map { ($0.rankStandardMovementId, $0) })
        let movementLines = Dictionary(grouping: movementAPGains, by: \.rankStandardMovementId)
            .compactMap { standardId, gains -> ProgressionMovementLine? in
                guard let first = gains.first else { return nil }
                let gained = gains.reduce(0) { $0 + $1.rawAP }
                let afterState = statesByStandard[standardId]
                let priorState = movementProgressPriorStates[standardId]

                // Current rank + "% to next" from the user's best metric for this
                // movement (lifetime, post-log). Rank-up = current rank strictly
                // above the rank derived from the pre-log best metric.
                let progress = TrainingCompletionResult.rankProgress(
                    state: afterState,
                    template: first.rankTemplate,
                    exerciseKey: first.standardDisplayName,
                    bodyweightKg: bodyweightKg,
                    sex: biologicalSex
                )
                let priorRank = TrainingCompletionResult.rankProgress(
                    state: priorState,
                    template: first.rankTemplate,
                    exerciseKey: first.standardDisplayName,
                    bodyweightKg: bodyweightKg,
                    sex: biologicalSex
                )?.current
                let didRankUp: Bool = {
                    guard let current = progress?.current else { return false }
                    return current.rawValue > (priorRank?.rawValue ?? -1) && priorRank != nil
                }()

                return ProgressionMovementLine(
                    id: standardId,
                    name: first.standardDisplayName,
                    xpGained: TrainingCompletionResult.rounded(gained, places: 0),
                    currentRank: progress?.current,
                    nextRank: progress?.next,
                    fractionToNextRank: progress?.fraction ?? 0,
                    didRankUp: didRankUp
                )
            }
            .sorted { lhs, rhs in
                if lhs.xpGained == rhs.xpGained {
                    return lhs.name < rhs.name
                }
                return lhs.xpGained > rhs.xpGained
            }
            .prefix(3)

        let attributeLines = attributeRewards
            .sorted { lhs, rhs in
                if lhs.xpGained == rhs.xpGained {
                    return lhs.key.shortCode < rhs.key.shortCode
                }
                return lhs.xpGained > rhs.xpGained
            }
            .prefix(3)
            .map {
                ProgressionAttributeLine(
                    key: $0.key,
                    xpGained: TrainingCompletionResult.rounded($0.xpGained, places: 0),
                    levelBefore: $0.previousLevel,
                    levelAfter: $0.currentLevel,
                    progressBefore: AttributeLevelCurve.progressFraction(forXP: $0.previousXP),
                    progressAfter: AttributeLevelCurve.progressFraction(forXP: $0.currentXP),
                    tierAfter: $0.currentTier
                )
            }

        let bodyRegionLines = bodyMapRegionRewards
            .sorted { lhs, rhs in
                if lhs.loadAdded == rhs.loadAdded {
                    return lhs.region.displayName < rhs.region.displayName
                }
                return lhs.loadAdded > rhs.loadAdded
            }
            .prefix(4)
            .map {
                ProgressionBodyRegionLine(
                    name: $0.region.displayName,
                    loadAdded: TrainingCompletionResult.rounded($0.loadAdded, places: 1)
                )
            }

        let overall = overallLevelReward
        return ProgressionReceipt(
            totalMovementAP: TrainingCompletionResult.rounded(totalMovementAP, places: 0),
            totalAttributeXP: TrainingCompletionResult.rounded(totalAttributeXPGained, places: 0),
            overallLevelXPGained: TrainingCompletionResult.rounded(overallLevelXPGained, places: 0),
            overallLevelBefore: overall?.previousLevel ?? 0,
            overallLevelAfter: overall?.currentLevel ?? 0,
            overallLevelProgressBefore: overall?.previousProgressToNextLevel ?? 0,
            overallLevelProgressAfter: overall?.currentProgressToNextLevel ?? 0,
            noveltyMultiplier: TrainingCompletionResult.rounded(bodyMapNoveltyMultiplier, places: 2),
            skillXPGained: skillXPGained,
            movementLines: Array(movementLines),
            attributeLines: Array(attributeLines),
            bodyRegionLines: Array(bodyRegionLines)
        )
    }

    private static func rounded(_ value: Double, places: Int) -> Double {
        let scale = pow(10.0, Double(max(0, places)))
        return (value * scale).rounded() / scale
    }

    /// Derive a movement's current RankTier + "% to next" from its best logged
    /// metric. The metric depends on the rank template: load for strength,
    /// added-load for weighted bodyweight, reps for bodyweight reps, seconds for
    /// holds. Cardio / carry / mobility / routine / unranked → nil (no rank bar).
    static func rankProgress(
        state: MovementProgressState?,
        template: MovementRankTemplate,
        exerciseKey: String,
        bodyweightKg: Double,
        sex: BiologicalSex?
    ) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        guard let state else { return nil }
        let metric: Double?
        switch template {
        case .barbellStrength, .machineStrength:
            metric = state.bestEstimatedOneRepMaxKg ?? state.bestLoadKg
        case .weightedBodyweight:
            metric = state.bestEstimatedOneRepMaxKg ?? state.bestLoadKg
        case .bodyweightReps:
            metric = state.bestReps.map(Double.init)
        case .holdControl:
            metric = state.bestHoldSeconds.map(Double.init)
        case .carrySled, .cardioPerformance, .mobilityDuration, .routineCompletion, .unranked:
            return nil
        }
        guard let metric, metric > 0 else { return nil }
        return StrengthStandards.progressToNextRank(
            metricValue: metric,
            bodyweightKg: bodyweightKg,
            exerciseKey: exerciseKey,
            sex: sex
        )
    }
}
