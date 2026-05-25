import Foundation

@MainActor
final class TrainingCompletionService {
    static let shared = TrainingCompletionService()

    private init() {}

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

        let progression = await progressionResult(from: performanceLog, services: services)
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
        if let vitalityXP = VitalityRewardPolicy.xp(for: performanceLog) {
            let vitalityProgress = AttributeIngest.applyXPDeltas(
                &attributeProfile,
                xpDeltas: [.agility: vitalityXP],
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
        if let vitalityXP = VitalityRewardPolicy.xp(for: performanceLog) {
            let vitalityProgress = await services.attribute.applyXPDeltas(
                [.agility: vitalityXP],
                userId: performanceLog.userId,
                at: performanceLog.completedAt
            )
            attributeRewards.append(contentsOf: vitalityProgress.rewards)
            attributeRankUpEventCount += vitalityProgress.rankUpEvents.count
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
            database: services.database
        )
        result.overallLevelReward = overallLevelProgress
        result.overallLevelXPGained = overallLevelProgress.xpGained
        return result
    }

    private func previewBodyRegionRewards(
        from gains: [MovementAPGain],
        at date: Date
    ) -> [BodyMapRegionReward] {
        var loadsByRegion: [BodyRegion: Double] = [:]

        for gain in gains where gain.rawAP > 0 {
            let exactRegions = MovementCatalog.definition(for: gain.movementId)?.bodyRegions ?? []
            let standardRegions = MovementCatalog.definition(for: gain.rankStandardMovementId)?.bodyRegions ?? []
            let regions = Array(Set(exactRegions.isEmpty ? standardRegions : exactRegions))
            guard !regions.isEmpty else { continue }

            let loadShare = gain.rawAP / Double(regions.count)
            for region in regions {
                loadsByRegion[region, default: 0] += loadShare
            }
        }

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

private enum VitalityRewardPolicy {
    static func xp(for performanceLog: PerformanceLog) -> Double? {
        let text = searchableText(for: performanceLog)
        if text.contains("vitality:rest-day") || text.contains("rest day recovery") {
            return 8
        }
        if text.contains("deload") {
            return 10
        }
        if text.contains("vitality:recovery-check-in")
            || text.contains("recovery check-in")
            || text.contains("active recovery") {
            return 5
        }
        return nil
    }

    private static func searchableText(for performanceLog: PerformanceLog) -> String {
        var parts: [String] = [
            performanceLog.title,
            performanceLog.notes ?? ""
        ]
        for block in performanceLog.blocks {
            parts.append(block.title)
            parts.append(block.notes ?? "")
            for exercise in block.exercises {
                parts.append(exercise.name)
                parts.append(exercise.plannedTarget)
                parts.append(exercise.notes ?? "")
            }
        }
        return parts.joined(separator: " ").lowercased()
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
