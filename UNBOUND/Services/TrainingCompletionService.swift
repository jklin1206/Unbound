import Foundation

@MainActor
final class TrainingCompletionService {
    static let shared = TrainingCompletionService()

    private let squadMission: SquadMissionServiceProtocol
    private let friendChallenge: FriendChallengeServiceProtocol

    // Idempotency guard for the squad/challenge progress cascade. complete()
    // already short-circuits on the persisted training_completion_records gate,
    // but a re-flush within the same process (before that record write lands)
    // could double-count, so we also track recorded performanceLog ids here —
    // mirroring SquadActivityService.recordedVowCompletionIds.
    private var recordedSquadProgressLogIds = Set<String>()
    private var activeCompletionLogIds = Set<String>()
    private var completionWaiters: [String: [CheckedContinuation<TrainingCompletionResult, Error>]] = [:]

    convenience init() {
        self.init(
            squadMission: SquadMissionService.shared,
            friendChallenge: FriendChallengeService.shared
        )
    }

    init(
        squadMission: SquadMissionServiceProtocol,
        friendChallenge: FriendChallengeServiceProtocol
    ) {
        self.squadMission = squadMission
        self.friendChallenge = friendChallenge
    }

    /// Records squad-mission + friend-challenge progress for a completed
    /// workout, exactly once per performanceLog id. This is the canonical
    /// trigger now that the legacy WorkoutLogService.saveLog cascade is deleted.
    func recordSquadProgress(workoutLog: WorkoutLog, performanceLogId: String) async {
        guard !recordedSquadProgressLogIds.contains(performanceLogId) else { return }
        recordedSquadProgressLogIds.insert(performanceLogId)
        await squadMission.recordProgress(
            log: workoutLog,
            userId: workoutLog.userId,
            sourceLogId: performanceLogId
        )
        await friendChallenge.recordProgress(
            log: workoutLog,
            userId: workoutLog.userId,
            sourceLogId: performanceLogId
        )
    }

    @discardableResult
    func complete(
        _ performanceLog: PerformanceLog,
        services: ServiceContainer,
        skillXPAwarded: Int? = nil
    ) async throws -> TrainingCompletionResult {
        if activeCompletionLogIds.contains(performanceLog.id) {
            let completed = try await waitForActiveCompletion(performanceLogId: performanceLog.id)
            return alreadyCompletedResult(from: completed)
        }

        activeCompletionLogIds.insert(performanceLog.id)
        do {
            let result = try await completeOnce(
                performanceLog,
                services: services,
                skillXPAwarded: skillXPAwarded
            )
            finishActiveCompletion(performanceLogId: performanceLog.id, result: .success(result))
            return result
        } catch {
            finishActiveCompletion(performanceLogId: performanceLog.id, result: .failure(error))
            throw error
        }
    }

    private func completeOnce(
        _ performanceLog: PerformanceLog,
        services: ServiceContainer,
        skillXPAwarded: Int? = nil
    ) async throws -> TrainingCompletionResult {
        if let existing: TrainingCompletionRecord = try? await services.database.read(
            collection: "training_completion_records",
            documentId: performanceLog.id
        ) {
            return TrainingCompletionResult(record: existing, wasAlreadyCompleted: true)
        }
        if let receipt: TrainingCompletionReplayReceipt = try? await services.database.read(
            collection: "training_completion_replay_receipts",
            documentId: performanceLog.id
        ) {
            let replayed = TrainingCompletionResult(receipt: receipt, wasAlreadyCompleted: false)
            let record = TrainingCompletionRecord(result: replayed, performanceLog: performanceLog)
            try await services.database.create(
                record,
                collection: "training_completion_records",
                documentId: record.id
            )
            return replayed
        }

        let resumedOrFreshResult: TrainingCompletionResult
        if let progressionReceipt: TrainingCompletionProgressionReceipt = try? await services.database.read(
            collection: "training_completion_progression_receipts",
            documentId: performanceLog.id
        ) {
            resumedOrFreshResult = TrainingCompletionResult(progressionReceipt: progressionReceipt, wasAlreadyCompleted: false)
        } else {
            var seededResult = TrainingCompletionResult()

            try await services.database.create(
                performanceLog,
                collection: "performanceLogs",
                documentId: performanceLog.id
            )
            seededResult.savedPerformanceLogId = performanceLog.id

            do {
                let progression = try await runWithTimeout(seconds: 8, step: "progression persistence") {
                    try await self.progressionResult(from: performanceLog, services: services)
                }
                seededResult.mergeProgression(from: progression)
                try await services.database.create(
                    TrainingCompletionProgressionReceipt(result: seededResult, performanceLog: performanceLog),
                    collection: "training_completion_progression_receipts",
                    documentId: performanceLog.id
                )
                resumedOrFreshResult = seededResult
            } catch {
                LoggingService.shared.log(
                    "TrainingCompletionService progression persistence failed: \(error)",
                    level: .error,
                    context: ["performanceLogId": performanceLog.id]
                )
                throw error
            }
        }

        var result = resumedOrFreshResult

        if let workoutLog = TrainingSessionAdapters.workoutLog(from: performanceLog) {
            try await saveCompatibleWorkoutLog(
                workoutLog,
                performanceLogId: performanceLog.id,
                services: services
            )
            try await recordLoadProgression(
                workoutLog: workoutLog,
                performanceLog: performanceLog,
                services: services
            )
            result.savedWorkoutLogId = workoutLog.id
            let currentTierState = services.userSkillTier.load(userId: performanceLog.userId)
            result.proofEngineResult = ProofEngine.evaluate(
                log: workoutLog,
                source: WorkoutProofSource(performanceLog.source),
                currentTierState: currentTierState,
                bodyweightKg: result.bodyweightKg
            )

            // Squad cluster: a real finished workout advances squad-mission and
            // friend-challenge progress. The legacy WorkoutLogService.saveLog
            // path that used to do this is now deleted, so this is the canonical
            // trigger. Idempotency-guarded so a re-flush of the same session
            // can't double-count.
            await recordSquadProgress(workoutLog: workoutLog, performanceLogId: performanceLog.id)
        }

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: performanceLog, xpAwarded: skillXPAwarded ?? 25)
        for sessionLog in sessionLogs {
            if let existing: SessionLog = try? await services.database.read(
                collection: "sessionLogs",
                documentId: sessionLog.id
            ) {
                if existing.xpAwarded > 0 {
                    result.skillXPGained += existing.xpAwarded
                }
                result.savedSessionLogIds.append(existing.id)
                continue
            }

            try await services.database.create(sessionLog, collection: "sessionLogs", documentId: sessionLog.id)
            // Session XP feeds the overall/attribute level + reward display.
            // The former per-skill 1-5 leveling (awardSessionXP) is gone — a
            // skill's real progression is its earned RankTier from logged proof.
            if sessionLog.xpAwarded > 0 {
                result.skillXPGained += sessionLog.xpAwarded
            }
            result.savedSessionLogIds.append(sessionLog.id)
        }

        result.skillTrainingReviews = try await recordSkillTrainingReviews(
            performanceLog: performanceLog,
            services: services
        )

        // Cosmetic unlocks earned by this session's rank progress (skill-tree
        // skins). evaluateUnlocks is idempotent and only returns the new ones.
        result.unlockedSkins = await services.skin.evaluateUnlocks(userId: performanceLog.userId)

        // Session/streak state is source-idempotent so retries after partial
        // persistence can replay the original streak outcome without counting
        // another session.
        let streakDelta = await services.sessionXP.recordSession(
            userId: performanceLog.userId,
            at: performanceLog.completedAt,
            sourceId: performanceLog.id
        )
        result.streakCount = streakDelta.updated.currentStreak
        result.streakExtended = streakDelta.streakExtended

        let receipt = TrainingCompletionReplayReceipt(result: result, performanceLog: performanceLog)
        try await services.database.create(
            receipt,
            collection: "training_completion_replay_receipts",
            documentId: receipt.id
        )

        let record = TrainingCompletionRecord(result: result, performanceLog: performanceLog)
        try await services.database.create(
            record,
            collection: "training_completion_records",
            documentId: record.id
        )

        return result
    }

    func previewProgression(
        for performanceLog: PerformanceLog,
        services: ServiceContainer
    ) -> TrainingCompletionResult {
        var result = TrainingCompletionResult()
        let gains = MovementAPCalculator.gains(from: performanceLog)
        result.movementAPGains = gains
        result.movementProgressStates = Dictionary(grouping: gains, by: \.rankStandardMovementId)
            .compactMap { standardId, standardGains in
                guard let first = standardGains.first else { return nil }
                return MovementProgressState(
                    userId: performanceLog.userId,
                    rankStandardMovementId: standardId,
                    displayName: first.standardDisplayName,
                    rankTemplate: first.rankTemplate,
                    totalAP: standardGains.reduce(0) { $0 + $1.rawAP },
                    lastGainedAP: standardGains.reduce(0) { $0 + $1.rawAP },
                    updatedAt: performanceLog.completedAt
                )
            }

        result.bodyMapRegionRewards = previewBodyRegionRewards(
            from: gains,
            trainingLoads: BodyRegionTrainingLedger.loads(for: performanceLog),
            at: performanceLog.completedAt
        )
        // Real region-novelty from the user's last-known body-map profile (cached
        // in memory by BodyMapProgressService) so the timed-out preview credits
        // the same novelty bonus the live path would — not a flat 1.0.
        let noveltyMultiplier = BodyMapProgressService.shared.previewNoveltyMultiplier(
            for: result.bodyMapRegionRewards.map(\.region),
            userId: performanceLog.userId,
            at: performanceLog.completedAt
        )
        result.bodyMapNoveltyMultiplier = noveltyMultiplier

        var attributeProfile = services.attribute.snapshot(
            userId: performanceLog.userId,
            asOf: performanceLog.completedAt
        )
        let attributeProfileBefore = attributeProfile
        let xpDeltas = AttributeIngest.xpDeltas(
            for: gains,
            catalog: AttributeCatalog.shared,
            noveltyMultiplier: noveltyMultiplier
        )
        var attributeProgress = AttributeIngest.applyXPDeltas(
            &attributeProfile,
            xpDeltas: xpDeltas,
            at: performanceLog.completedAt
        )
        let vitalityAward = VitalityRewardPolicy.previewAward(for: performanceLog)
        if vitalityAward.totalXP > 0 {
            let vitalityProgress = AttributeIngest.applyXPDeltas(
                &attributeProfile,
                xpDeltas: [.vitality: vitalityAward.totalXP],
                at: performanceLog.completedAt
            )
            attributeProgress.rewards.append(contentsOf: vitalityProgress.rewards)
            attributeProgress.rankUpEvents.append(contentsOf: vitalityProgress.rankUpEvents)
        }
        result.attributeProfileBefore = attributeProfileBefore
        result.attributeProfileAfter = attributeProfile
        result.attributeRewards = attributeProgress.rewards
        result.attributeRankUpEventCount = attributeProgress.rankUpEvents.count

        let overallXPGained = RewardLedgerQuantizer.wholePoints(
            from: gains.reduce(0) { $0 + $1.rawAP } * noveltyMultiplier
        )
        let previousOverallXP = OverallLevelService.shared.cachedTotalXP(userId: performanceLog.userId) ?? 0.0
        let currentOverallXP = previousOverallXP + overallXPGained
        result.overallLevelReward = OverallLevelReward(
            xpGained: overallXPGained,
            noveltyMultiplier: noveltyMultiplier,
            previousXP: previousOverallXP,
            currentXP: currentOverallXP,
            previousLevel: OverallLevelCurve.level(forXP: previousOverallXP),
            currentLevel: OverallLevelCurve.level(forXP: currentOverallXP),
            previousProgressToNextLevel: OverallLevelCurve.progressFraction(forXP: previousOverallXP),
            currentProgressToNextLevel: OverallLevelCurve.progressFraction(forXP: currentOverallXP)
        )
        result.overallLevelXPGained = overallXPGained

        return result
    }

    private func progressionResult(
        from performanceLog: PerformanceLog,
        services: ServiceContainer
    ) async throws -> TrainingCompletionResult {
        var result = TrainingCompletionResult()

        // Bodyweight + sex for the per-movement "% to next rank" derivation.
        let profile: UserProfile? = try? await services.database.read(
            collection: "users",
            documentId: performanceLog.userId
        )
        result.bodyweightKg = profile?.weightKg ?? 0
        result.biologicalSex = profile?.biologicalSex

        let movementProgress = try await MovementProgressService.shared.ingestStrict(
            performanceLog,
            database: services.database
        )
        result.movementAPGains = movementProgress.gains
        result.movementProgressStates = movementProgress.updatedStates
        result.movementProgressPriorStates = movementProgress.priorStates
        result.updatedMovementProgressIds = movementProgress.updatedStates.map(\.id)

        let bodyMapProgress = try await BodyMapProgressService.shared.ingestStrict(
            movementAPGains: movementProgress.gains,
            userId: performanceLog.userId,
            sourceLogId: performanceLog.id,
            at: performanceLog.completedAt,
            trainingLoads: BodyRegionTrainingLedger.loads(for: performanceLog),
            database: services.database
        )
        result.bodyMapNoveltyMultiplier = bodyMapProgress.noveltyMultiplier
        result.bodyMapRegionRewards = bodyMapProgress.regionRewards

        let attributeProfileBefore = services.attribute.snapshot(
            userId: performanceLog.userId,
            asOf: performanceLog.completedAt
        )
        let attributeProgress = await services.attribute.ingest(
            movementAPGains: movementProgress.gains,
            userId: performanceLog.userId,
            at: performanceLog.completedAt,
            noveltyMultiplier: bodyMapProgress.noveltyMultiplier,
            sourceId: "movement:\(performanceLog.id)"
        )
        var attributeRewards = attributeProgress.rewards
        var attributeRankUpEventCount = attributeProgress.rankUpEvents.count
        var attributeProfileAfter = attributeProgress.profileAfter
        let vitalityAward = await VitalityRewardPolicy.award(
            for: performanceLog,
            database: services.database
        )
        if vitalityAward.totalXP > 0 {
            let vitalityProgress = await services.attribute.applyXPDeltas(
                [.vitality: vitalityAward.totalXP],
                userId: performanceLog.userId,
                at: performanceLog.completedAt,
                sourceId: "vitality:\(performanceLog.id)"
            )
            attributeRewards.append(contentsOf: vitalityProgress.rewards)
            attributeRankUpEventCount += vitalityProgress.rankUpEvents.count
            attributeProfileAfter = vitalityProgress.profileAfter ?? attributeProfileAfter
            await VitalityRewardPolicy.record(
                award: vitalityAward,
                performanceLog: performanceLog,
                database: services.database
            )
        }
        result.attributeProfileBefore = attributeProgress.profileBefore ?? attributeProfileBefore
        result.attributeProfileAfter = attributeProfileAfter ?? services.attribute.snapshot(
            userId: performanceLog.userId,
            asOf: performanceLog.completedAt
        )
        result.attributeRewards = attributeRewards
        result.attributeRankUpEventCount = attributeRankUpEventCount

        let overallLevelProgress = try await OverallLevelService.shared.ingestStrict(
            rawAP: movementProgress.totalAP,
            noveltyMultiplier: bodyMapProgress.noveltyMultiplier,
            sourceLogId: performanceLog.id,
            userId: performanceLog.userId,
            at: performanceLog.completedAt,
            gains: movementProgress.gains,
            rankUpEvents: attributeRankUpEventCount,
            database: services.database
        )
        result.overallLevelReward = overallLevelProgress
        result.overallLevelXPGained = overallLevelProgress.xpGained
        return result
    }

    private func waitForActiveCompletion(performanceLogId: String) async throws -> TrainingCompletionResult {
        try await withCheckedThrowingContinuation { continuation in
            completionWaiters[performanceLogId, default: []].append(continuation)
        }
    }

    private func finishActiveCompletion(
        performanceLogId: String,
        result: Result<TrainingCompletionResult, Error>
    ) {
        activeCompletionLogIds.remove(performanceLogId)
        let waiters = completionWaiters.removeValue(forKey: performanceLogId) ?? []
        for waiter in waiters {
            switch result {
            case .success(let completion):
                waiter.resume(returning: completion)
            case .failure(let error):
                waiter.resume(throwing: error)
            }
        }
    }

    private func alreadyCompletedResult(from result: TrainingCompletionResult) -> TrainingCompletionResult {
        var completed = result
        completed.wasAlreadyCompleted = true
        return completed
    }

    private func previewBodyRegionRewards(
        from gains: [MovementAPGain],
        trainingLoads: [BodyRegionTrainingLoad] = [],
        at date: Date
    ) -> [BodyMapRegionReward] {
        let loadsByRegion = previewRegionLoads(from: gains, trainingLoads: trainingLoads)

        return loadsByRegion
            .map { region, loadAdded in
                BodyMapRegionReward(
                    region: region,
                    loadAdded: (loadAdded * 10).rounded() / 10,
                    recentLoad: (loadAdded * 10).rounded() / 10,
                    lifetimeLoad: (loadAdded * 10).rounded() / 10,
                    lastTrainedAt: date
                )
            }
            .sorted { $0.region.rawValue < $1.region.rawValue }
    }

    private func previewRegionLoads(
        from gains: [MovementAPGain],
        trainingLoads: [BodyRegionTrainingLoad]
    ) -> [BodyRegion: Double] {
        let totalAP = gains.reduce(0) { $0 + max(0, $1.rawAP) }
        let apRegions = Set(gains.flatMap { bodyRegions(for: $0) })
        let roleWeightedLoads = mergedTrainingLoads(trainingLoads)
            .filter { region, load in
                apRegions.contains(region) && load.coachLoadScore > 0
            }
        let totalCoachLoad = roleWeightedLoads.values.reduce(0) { $0 + $1.coachLoadScore }
        if totalAP > 0, totalCoachLoad > 0 {
            return roleWeightedLoads.reduce(into: [:]) { result, entry in
                result[entry.key] = totalAP * (entry.value.coachLoadScore / totalCoachLoad)
            }
        }
        if totalAP == 0, !trainingLoads.isEmpty {
            return mergedTrainingLoads(trainingLoads).reduce(into: [:]) { result, entry in
                let load = entry.value.coachLoadScore * 10
                if load > 0 {
                    result[entry.key] = load
                }
            }
        }

        var loadsByRegion: [BodyRegion: Double] = [:]
        for gain in gains where gain.rawAP > 0 {
            let regions = bodyRegions(for: gain)
            guard !regions.isEmpty else { continue }

            let loadShare = gain.rawAP / Double(regions.count)
            for region in regions {
                loadsByRegion[region, default: 0] += loadShare
            }
        }

        return loadsByRegion
    }

    private func mergedTrainingLoads(
        _ trainingLoads: [BodyRegionTrainingLoad]
    ) -> [BodyRegion: BodyRegionTrainingLoad] {
        trainingLoads.reduce(into: [:]) { result, load in
            var current = result[load.region] ?? BodyRegionTrainingLoad(region: load.region)
            current.merge(load)
            result[load.region] = current
        }
    }

    private func bodyRegions(for gain: MovementAPGain) -> [BodyRegion] {
        let exactRegions = MovementCatalog.definition(for: gain.movementId)?.bodyRegions ?? []
        let standardRegions = MovementCatalog.definition(for: gain.rankStandardMovementId)?.bodyRegions ?? []
        let regions = exactRegions.isEmpty ? standardRegions : exactRegions
        return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
    }

    private func saveCompatibleWorkoutLog(
        _ workoutLog: WorkoutLog,
        performanceLogId: String,
        services: ServiceContainer
    ) async throws {
        if let compatibilityWriter = services.workoutLog as? WorkoutLogCompatibilityHistoryWriting {
            try await compatibilityWriter.saveCompatibleHistoryLog(workoutLog)
            LoggingService.shared.log(
                "TrainingCompletionService wrote compatible WorkoutLog through quarantined history writer",
                level: .info,
                context: ["performanceLogId": performanceLogId, "workoutLogId": workoutLog.id]
            )
            return
        }

        // MIGRATION(Phase 9): when a service doesn't provide a dedicated
        // compatibility writer, compatible history is quarantined to a direct
        // database write so completion never re-runs any legacy save cascade.
        try await services.database.create(workoutLog, collection: "workoutLogs", documentId: workoutLog.id)
        LoggingService.shared.log(
            "TrainingCompletionService wrote compatible WorkoutLog through database quarantine",
            level: .warning,
            context: ["performanceLogId": performanceLogId, "workoutLogId": workoutLog.id]
        )
    }

    private func recordLoadProgression(
        workoutLog: WorkoutLog,
        performanceLog: PerformanceLog,
        services: ServiceContainer
    ) async throws {
        if let _: TrainingCompletionOverloadReceipt = try? await services.database.read(
            collection: "training_completion_overload_receipts",
            documentId: performanceLog.id
        ) {
            return
        }

        try await services.database.create(
            TrainingCompletionOverloadReceipt(performanceLog: performanceLog, workoutLog: workoutLog),
            collection: "training_completion_overload_receipts",
            documentId: performanceLog.id
        )

        let profile: UserProfile? = try? await services.database.read(
            collection: "users",
            documentId: performanceLog.userId
        )
        await ProgressionEngine.shared.ingest(
            log: workoutLog,
            mode: profile?.cutMode.enabled == true ? .preserve : .advance,
            feedbackMode: profile?.trainingFeedbackMode
        )
        try await services.workingWeight.updateFromLog(workoutLog, userId: workoutLog.userId)
    }

    private func recordSkillTrainingReviews(
        performanceLog: PerformanceLog,
        services: ServiceContainer
    ) async throws -> [SkillTrainingAgentReview] {
        let reviews = SkillTrainingReviewAgent.evaluate(performanceLog: performanceLog)
        for review in reviews {
            try await SkillTrainingReviewStore.shared.record(review, database: services.database)
        }
        return reviews
    }

    private func runWithTimeout<T: Sendable>(
        seconds: TimeInterval,
        step: String,
        operation: @escaping @Sendable @MainActor () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: nanoseconds)
                throw TrainingCompletionTimeout(step: step, seconds: seconds)
            }

            do {
                if let value = try await group.next() {
                    group.cancelAll()
                    return value
                }
                group.cancelAll()
                throw TrainingCompletionTimeout(step: step, seconds: seconds)
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }
}

private struct TrainingCompletionTimeout: Error, LocalizedError {
    let step: String
    let seconds: TimeInterval

    var errorDescription: String? {
        "\(step) timed out after \(Int(seconds)) seconds"
    }
}

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
}

private extension WorkoutProofSource {
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
