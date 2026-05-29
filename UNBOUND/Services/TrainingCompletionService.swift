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

    init(
        squadMission: SquadMissionServiceProtocol = SquadMissionService.shared,
        friendChallenge: FriendChallengeServiceProtocol = FriendChallengeService.shared
    ) {
        self.squadMission = squadMission
        self.friendChallenge = friendChallenge
    }

    /// Records squad-mission + friend-challenge progress for a completed
    /// workout, exactly once per performanceLog id. Mirrors the legacy
    /// WorkoutLogService.saveLog cascade that is now side-effect-free.
    func recordSquadProgress(workoutLog: WorkoutLog, performanceLogId: String) async {
        guard !recordedSquadProgressLogIds.contains(performanceLogId) else { return }
        recordedSquadProgressLogIds.insert(performanceLogId)
        await squadMission.recordProgress(log: workoutLog, userId: workoutLog.userId)
        await friendChallenge.recordProgress(log: workoutLog, userId: workoutLog.userId)
    }

    @discardableResult
    func complete(
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

        var result = TrainingCompletionResult()

        try await services.database.create(
            performanceLog,
            collection: "performanceLogs",
            documentId: performanceLog.id
        )
        result.savedPerformanceLogId = performanceLog.id

        do {
            let progression = try await runWithTimeout(seconds: 8, step: "progression persistence") {
                await self.progressionResult(from: performanceLog, services: services)
            }
            result.mergeProgression(from: progression)
        } catch {
            let preview = previewProgression(for: performanceLog, services: services)
            result.mergeProgression(from: preview)
            LoggingService.shared.log(
                "TrainingCompletionService progression persistence timed out; using reward preview: \(error)",
                level: .warning,
                context: ["performanceLogId": performanceLog.id]
            )
        }

        if let workoutLog = TrainingSessionAdapters.workoutLog(from: performanceLog) {
            try await saveCompatibleWorkoutLog(
                workoutLog,
                performanceLogId: performanceLog.id,
                services: services
            )
            result.savedWorkoutLogId = workoutLog.id
            result.proofEngineResult = ProofEngine.evaluate(
                log: workoutLog,
                source: WorkoutProofSource(performanceLog.source)
            )

            // Squad cluster: a real finished workout advances squad-mission and
            // friend-challenge progress. The legacy WorkoutLogService.saveLog
            // path that used to do this is now side-effect-free, so this is the
            // canonical trigger. Idempotency-guarded so a re-flush of the same
            // session can't double-count.
            await recordSquadProgress(workoutLog: workoutLog, performanceLogId: performanceLog.id)
        }

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: performanceLog, xpAwarded: skillXPAwarded ?? 25)
        for sessionLog in sessionLogs {
            if let existing: SessionLog = try? await services.database.read(
                collection: "sessionLogs",
                documentId: sessionLog.id
            ) {
                result.savedSessionLogIds.append(existing.id)
                continue
            }

            try await services.database.create(sessionLog, collection: "sessionLogs", documentId: sessionLog.id)
            if sessionLog.xpAwarded > 0 {
                let awarded = await SkillProgressService.shared.awardSessionXP(
                    forNodeId: sessionLog.skillId,
                    xpAmount: sessionLog.xpAwarded
                )
                result.skillXPGained += awarded
            }
            result.savedSessionLogIds.append(sessionLog.id)
        }

        let record = TrainingCompletionRecord(result: result, performanceLog: performanceLog)
        try await services.database.create(
            record,
            collection: "training_completion_records",
            documentId: record.id
        )

        return result
    }

    @discardableResult
    func recordProgressionForLegacyWorkout(
        _ performanceLog: PerformanceLog,
        compatibleWorkoutLog: WorkoutLog? = nil,
        services: ServiceContainer
    ) async -> TrainingCompletionResult {
        if let existing: TrainingCompletionRecord = try? await services.database.read(
            collection: "training_completion_records",
            documentId: performanceLog.id
        ) {
            return TrainingCompletionResult(record: existing, wasAlreadyCompleted: true)
        }

        var result = TrainingCompletionResult()

        try? await services.database.create(
            performanceLog,
            collection: "performanceLogs",
            documentId: performanceLog.id
        )
        result.savedPerformanceLogId = performanceLog.id

        // MIGRATION(Phase 9): the legacy WorkoutLoggingViewModel route must NOT
        // write attribute/movement/overall-level/body-map progression — that is
        // the canonical complete() path's job. Double-writing here awarded AP
        // twice. We keep a side-effect-free reward preview so the legacy receipt
        // still renders, then persist only compatible history + the receipt.
        let progression = previewProgression(for: performanceLog, services: services)
        result.mergeProgression(from: progression)

        if let compatibleWorkoutLog {
            do {
                try await saveCompatibleWorkoutLog(
                    compatibleWorkoutLog,
                    performanceLogId: performanceLog.id,
                    services: services
                )
                result.savedWorkoutLogId = compatibleWorkoutLog.id
                result.proofEngineResult = ProofEngine.evaluate(
                    log: compatibleWorkoutLog,
                    source: WorkoutProofSource(performanceLog.source)
                )
            } catch {
                LoggingService.shared.log(
                    "TrainingCompletionService failed to write legacy-compatible WorkoutLog: \(error)",
                    level: .warning,
                    context: ["performanceLogId": performanceLog.id, "workoutLogId": compatibleWorkoutLog.id]
                )
            }
        }

        let record = TrainingCompletionRecord(result: result, performanceLog: performanceLog)
        do {
            try await services.database.create(
                record,
                collection: "training_completion_records",
                documentId: record.id
            )
        } catch {
            LoggingService.shared.log(
                "TrainingCompletionService failed to write legacy completion receipt: \(error)",
                level: .warning,
                context: ["performanceLogId": performanceLog.id]
            )
        }

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

        let noveltyMultiplier = 1.0
        result.bodyMapNoveltyMultiplier = noveltyMultiplier
        result.bodyMapRegionRewards = previewBodyRegionRewards(
            from: gains,
            trainingLoads: BodyRegionTrainingLedger.loads(for: performanceLog),
            at: performanceLog.completedAt
        )

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
        let previousOverallXP = 0.0
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
    ) async -> TrainingCompletionResult {
        var result = TrainingCompletionResult()
        let movementProgress = await MovementProgressService.shared.ingest(
            performanceLog,
            database: services.database
        )
        result.movementAPGains = movementProgress.gains
        result.movementProgressStates = movementProgress.updatedStates
        result.updatedMovementProgressIds = movementProgress.updatedStates.map(\.id)

        let bodyMapProgress = await BodyMapProgressService.shared.ingest(
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
            noveltyMultiplier: bodyMapProgress.noveltyMultiplier
        )
        var attributeRewards = attributeProgress.rewards
        var attributeRankUpEventCount = attributeProgress.rankUpEvents.count
        let vitalityAward = await VitalityRewardPolicy.award(
            for: performanceLog,
            database: services.database
        )
        if vitalityAward.totalXP > 0 {
            let vitalityProgress = await services.attribute.applyXPDeltas(
                [.vitality: vitalityAward.totalXP],
                userId: performanceLog.userId,
                at: performanceLog.completedAt
            )
            attributeRewards.append(contentsOf: vitalityProgress.rewards)
            attributeRankUpEventCount += vitalityProgress.rankUpEvents.count
            await VitalityRewardPolicy.record(
                award: vitalityAward,
                performanceLog: performanceLog,
                database: services.database
            )
        }
        result.attributeProfileBefore = attributeProfileBefore
        result.attributeProfileAfter = services.attribute.snapshot(
            userId: performanceLog.userId,
            asOf: performanceLog.completedAt
        )
        result.attributeRewards = attributeRewards
        result.attributeRankUpEventCount = attributeRankUpEventCount

        let overallLevelProgress = await OverallLevelService.shared.ingest(
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

        // MIGRATION(Phase 9): unified completion must never fall back to
        // WorkoutLogServiceProtocol.saveLog(_:). That method still owns the
        // old side-effect cascade for legacy callers, so compatible history is
        // quarantined to a direct database write when a dedicated writer is
        // unavailable.
        try await services.database.create(workoutLog, collection: "workoutLogs", documentId: workoutLog.id)
        LoggingService.shared.log(
            "TrainingCompletionService wrote compatible WorkoutLog through database quarantine",
            level: .warning,
            context: ["performanceLogId": performanceLogId, "workoutLogId": workoutLog.id]
        )
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
        self.wasAlreadyCompleted = wasAlreadyCompleted
    }

    mutating func mergeProgression(from other: TrainingCompletionResult) {
        movementAPGains = other.movementAPGains
        movementProgressStates = other.movementProgressStates
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

    init(result: TrainingCompletionResult, performanceLog: PerformanceLog) {
        self.id = performanceLog.id
        self.performanceLogId = performanceLog.id
        self.userId = performanceLog.userId
        self.completedAt = performanceLog.completedAt
        self.workoutLogId = result.savedWorkoutLogId
        self.sessionLogIds = result.savedSessionLogIds
    }
}

extension TrainingCompletionResult {
    var progressionReceipt: ProgressionReceipt {
        let statesByStandard = Dictionary(uniqueKeysWithValues: movementProgressStates.map { ($0.rankStandardMovementId, $0) })
        let movementLines = Dictionary(grouping: movementAPGains, by: \.rankStandardMovementId)
            .compactMap { standardId, gains -> ProgressionMovementLine? in
                guard let first = gains.first else { return nil }
                let gained = gains.reduce(0) { $0 + $1.rawAP }
                let currentAP = statesByStandard[standardId]?.totalAP ?? gained
                let previousAP = max(0, currentAP - gained)
                return ProgressionMovementLine(
                    id: standardId,
                    name: first.standardDisplayName,
                    apGained: TrainingCompletionResult.rounded(gained, places: 0),
                    totalAPBefore: TrainingCompletionResult.rounded(previousAP, places: 0),
                    totalAPAfter: TrainingCompletionResult.rounded(currentAP, places: 0)
                )
            }
            .sorted { lhs, rhs in
                if lhs.apGained == rhs.apGained {
                    return lhs.name < rhs.name
                }
                return lhs.apGained > rhs.apGained
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
}
