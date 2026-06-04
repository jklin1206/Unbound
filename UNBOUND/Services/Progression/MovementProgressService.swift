import Foundation

enum MovementAPCalculator {
    private static let baseAP = 10.0

    static func rankStandardMovementIds(from log: PerformanceLog) -> [String] {
        var ids = Set<String>()

        for block in log.blocks {
            for exercise in block.exercises where !exercise.skipped {
                if let resolved = resolveMovement(
                    name: exercise.name,
                    movementId: exercise.movementId,
                    rankStandardMovementId: exercise.rankStandardMovementId
                ) {
                    ids.insert(resolved.standard.id)
                }
            }

            if block.exercises.isEmpty {
                if let cardioType = block.cardioType,
                   let definition = MovementCatalog.definition(for: "cardio.\(cardioType.rawValue)") {
                    ids.insert(definition.rankStandardMovementId)
                } else if let resolved = MovementCatalog.resolvedTrainingMovement(name: block.title),
                          let standard = resolved.standard,
                          standard.rankable {
                    ids.insert(standard.id)
                }
            }
        }

        return ids.sorted()
    }

    static func rankStandardMovementIds(from log: WorkoutLog) -> [String] {
        var ids = Set<String>()
        for entry in log.exerciseEntries where !entry.skipped {
            if let resolved = resolveMovement(
                name: entry.exerciseName,
                movementId: entry.movementId,
                rankStandardMovementId: entry.rankStandardMovementId
            ) {
                ids.insert(resolved.standard.id)
            }
        }
        return ids.sorted()
    }

    static func gains(
        from log: PerformanceLog,
        priorStates: [String: MovementProgressState] = [:]
    ) -> [MovementAPGain] {
        var gains: [MovementAPGain] = []

        for (blockIndex, block) in log.blocks.enumerated() {
            for (exerciseIndex, exercise) in block.exercises.enumerated() where !exercise.skipped {
                let resolved = resolveMovement(
                    name: exercise.name,
                    movementId: exercise.movementId,
                    rankStandardMovementId: exercise.rankStandardMovementId
                )
                guard let resolved else { continue }

                let prior = priorStates[resolved.standard.id]
                for set in exercise.sets where !set.isWarmup {
                    guard let rawAP = rawAP(
                        set: set,
                        exact: resolved.exact,
                        priorState: prior
                    ), rawAP > 0 else { continue }

                    gains.append(
                        MovementAPGain(
                            id: gainId(
                                sourceLogId: log.id,
                                sourceExerciseId: exercise.id,
                                rankStandardMovementId: resolved.standard.id,
                                sourceSlotId: sourceSlotId(
                                    blockIndex: blockIndex,
                                    exerciseIndex: exerciseIndex,
                                    movementId: resolved.exact.id
                                ),
                                ordinal: set.setNumber
                            ),
                            userId: log.userId,
                            sourceLogId: log.id,
                            sourceExerciseId: exercise.id,
                            movementId: resolved.exact.id,
                            rankStandardMovementId: resolved.standard.id,
                            movementDisplayName: resolved.exact.displayName,
                            standardDisplayName: resolved.standard.displayName,
                            rankTemplate: resolved.standard.rankTemplate,
                            rawAP: rawAP,
                            reps: set.reps,
                            loadKg: set.weightKg,
                            holdSeconds: set.holdSeconds,
                            durationSeconds: set.durationSeconds,
                            distanceMeters: set.distanceMeters,
                            calories: set.calories,
                            estimatedOneRepMaxKg: estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps),
                            occurredAt: log.completedAt
                        )
                    )
                }
            }

            if block.exercises.isEmpty,
               let blockGain = gain(fromMetricOnlyBlock: block, blockIndex: blockIndex, log: log, priorStates: priorStates) {
                gains.append(blockGain)
            }
        }

        return gains
    }

    static func gains(
        from log: WorkoutLog,
        priorStates: [String: MovementProgressState] = [:]
    ) -> [MovementAPGain] {
        let completedAt = log.completedAt ?? log.startedAt
        var gains: [MovementAPGain] = []

        for (entryIndex, entry) in log.exerciseEntries.enumerated() where !entry.skipped {
            let resolved = resolveMovement(
                name: entry.exerciseName,
                movementId: entry.movementId,
                rankStandardMovementId: entry.rankStandardMovementId
            )
            guard let resolved else { continue }

            let prior = priorStates[resolved.standard.id]
            for set in entry.sets where !set.isWarmup {
                guard let rawAP = rawAP(
                    reps: set.reps,
                    weightKg: set.weightKg,
                    rpe: set.rpe,
                    exact: resolved.exact,
                    priorState: prior
                ), rawAP > 0 else { continue }

                gains.append(
                    MovementAPGain(
                        id: gainId(
                            sourceLogId: log.id,
                            sourceExerciseId: entry.id,
                            rankStandardMovementId: resolved.standard.id,
                            sourceSlotId: sourceSlotId(
                                blockIndex: 0,
                                exerciseIndex: entryIndex,
                                movementId: resolved.exact.id
                            ),
                            ordinal: set.setNumber
                        ),
                        userId: log.userId,
                        sourceLogId: log.id,
                        sourceExerciseId: entry.id,
                        movementId: resolved.exact.id,
                        rankStandardMovementId: resolved.standard.id,
                        movementDisplayName: resolved.exact.displayName,
                        standardDisplayName: resolved.standard.displayName,
                        rankTemplate: resolved.standard.rankTemplate,
                        rawAP: rawAP,
                        reps: set.reps,
                        loadKg: set.weightKg,
                        estimatedOneRepMaxKg: estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps),
                        occurredAt: completedAt
                    )
                )
            }
        }

        return gains
    }

    private static func gain(
        fromMetricOnlyBlock block: PerformanceBlock,
        blockIndex: Int,
        log: PerformanceLog,
        priorStates: [String: MovementProgressState]
    ) -> MovementAPGain? {
        let movement: MovementDefinition?
        if let cardioType = block.cardioType {
            movement = MovementCatalog.definition(for: "cardio.\(cardioType.rawValue)")
        } else {
            movement = MovementCatalog.resolvedTrainingMovement(name: block.title)?.exact
        }

        guard let exact = movement,
              exact.rankable,
              let standard = MovementCatalog.definition(for: exact.rankStandardMovementId) else {
            return nil
        }

        let prior = priorStates[standard.id]
        let rawAP = rawAP(
            reps: nil,
            weightKg: nil,
            holdSeconds: nil,
            durationSeconds: block.durationSeconds,
            distanceMeters: block.distanceMeters,
            calories: block.calories,
            rpe: nil,
            exact: exact,
            priorState: prior
        )
        guard let rawAP, rawAP > 0 else { return nil }

        return MovementAPGain(
            id: gainId(
                sourceLogId: log.id,
                sourceExerciseId: block.id,
                rankStandardMovementId: standard.id,
                sourceSlotId: "block-\(blockIndex):metric:\(exact.id)",
                ordinal: 0
            ),
            userId: log.userId,
            sourceLogId: log.id,
            sourceExerciseId: block.id,
            movementId: exact.id,
            rankStandardMovementId: standard.id,
            movementDisplayName: exact.displayName,
            standardDisplayName: standard.displayName,
            rankTemplate: standard.rankTemplate,
            rawAP: rawAP,
            durationSeconds: block.durationSeconds,
            distanceMeters: block.distanceMeters,
            calories: block.calories,
            occurredAt: log.completedAt
        )
    }

    private static func gainId(
        sourceLogId: String,
        sourceExerciseId: String?,
        rankStandardMovementId: String,
        sourceSlotId: String,
        ordinal: Int
    ) -> String {
        [
            sourceLogId,
            rankStandardMovementId,
            sourceSlotId,
            String(ordinal)
        ].joined(separator: ":")
    }

    private static func sourceSlotId(blockIndex: Int, exerciseIndex: Int, movementId: String) -> String {
        "block-\(blockIndex):exercise-\(exerciseIndex):\(movementId)"
    }

    private static func rawAP(
        set: PerformanceSet,
        exact: MovementDefinition,
        priorState: MovementProgressState?
    ) -> Double? {
        rawAP(
            reps: set.reps,
            weightKg: set.weightKg,
            holdSeconds: set.holdSeconds,
            durationSeconds: set.durationSeconds,
            distanceMeters: set.distanceMeters,
            calories: set.calories,
            rpe: set.rpe,
            exact: exact,
            priorState: priorState,
            qualityFlags: set.qualityFlags
        )
    }

    private static func rawAP(
        reps: Int?,
        weightKg: Double?,
        holdSeconds: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        calories: Int? = nil,
        rpe: Int?,
        exact: MovementDefinition,
        priorState: MovementProgressState?,
        qualityFlags: Set<PerformanceQualityFlag> = []
    ) -> Double? {
        let metric = metricFactor(
            reps: reps,
            holdSeconds: holdSeconds,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            calories: calories
        )
        guard metric > 0 else { return nil }

        let intensity = intensityFactor(weightKg: weightKg, reps: reps, priorState: priorState)
        let rpe = rpeFactor(rpe)
        let quality = qualityFactor(flags: qualityFlags)
        let variation = variationFactor(for: exact)
        let rawScore = baseAP * metric * intensity * rpe * quality * variation
        return RewardLedgerQuantizer.wholePoints(from: rawScore)
    }

    private static func metricFactor(
        reps: Int?,
        holdSeconds: Int?,
        durationSeconds: Int?,
        distanceMeters: Int?,
        calories: Int?
    ) -> Double {
        let repScore = reps.map { log1p(Double(max($0, 0))) } ?? 0
        let holdScore = holdSeconds.map { log1p(Double(max($0, 0)) / 5.0) } ?? 0
        let durationScore = durationSeconds.map { log1p(Double(max($0, 0)) / 60.0) } ?? 0
        let distanceScore = distanceMeters.map { log1p(Double(max($0, 0)) / 100.0) } ?? 0
        let calorieScore = calories.map { log1p(Double(max($0, 0)) / 10.0) } ?? 0
        return max(repScore, holdScore, durationScore, distanceScore, calorieScore)
    }

    private static func intensityFactor(
        weightKg: Double?,
        reps: Int?,
        priorState: MovementProgressState?
    ) -> Double {
        guard let estimate = estimatedOneRepMaxKg(weightKg: weightKg, reps: reps), estimate > 0 else {
            return 1.0
        }
        let baseline = max(priorState?.bestEstimatedOneRepMaxKg ?? estimate, 1.0)
        let ratio = min(1.25, max(0.35, estimate / baseline))
        return pow(ratio, 1.5)
    }

    private static func rpeFactor(_ rpe: Int?) -> Double {
        guard let rpe else { return 1.0 }
        return min(1.15, max(0.8, 0.7 + Double(rpe) * 0.05))
    }

    private static func qualityFactor(flags: Set<PerformanceQualityFlag>) -> Double {
        var factor = flags.contains(.clean) ? 1.05 : 1.0
        if flags.contains(.assisted) { factor *= 0.75 }
        if flags.contains(.partialRange) { factor *= 0.75 }
        if flags.contains(.formBreak) { factor *= 0.85 }
        if flags.contains(.pain) { factor *= 0.5 }
        return factor
    }

    private static func variationFactor(for definition: MovementDefinition) -> Double {
        let normalized = MovementCatalog.normalized(definition.displayName)
        if normalized.contains("assisted") || normalized.contains("band") || normalized.contains("negative") || normalized.contains("eccentric") {
            return 0.8
        }
        return 1.0
    }

    private static func estimatedOneRepMaxKg(weightKg: Double?, reps: Int?) -> Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        let reps = max(reps ?? 1, 1)
        guard reps > 1 else { return weightKg }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    private static func resolveMovement(
        name: String,
        movementId: String?,
        rankStandardMovementId: String?
    ) -> (exact: MovementDefinition, standard: MovementDefinition)? {
        guard let resolved = MovementCatalog.resolvedTrainingMovement(
            name: name,
            movementId: movementId,
            rankStandardMovementId: rankStandardMovementId
        ),
              resolved.exact.rankable,
              let standard = resolved.standard,
              standard.rankable else {
            return nil
        }
        return (resolved.exact, standard)
    }
}

private enum ProgressionPersistenceMode {
    case bestEffort
    case strict
}

@MainActor
final class MovementProgressService {
    static let shared = MovementProgressService()

    private init() {}

    func ingest(
        _ log: PerformanceLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> MovementProgressIngestResult {
        do {
            return try await ingest(log, database: database, persistenceMode: .bestEffort)
        } catch {
            LoggingService.shared.log(
                "Movement progress best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": log.id]
            )
            return MovementProgressIngestResult()
        }
    }

    func ingestStrict(
        _ log: PerformanceLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> MovementProgressIngestResult {
        try await ingest(log, database: database, persistenceMode: .strict)
    }

    private func ingest(
        _ log: PerformanceLog,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> MovementProgressIngestResult {
        let priorStates = await loadPriorStates(
            userId: log.userId,
            standardIds: MovementAPCalculator.rankStandardMovementIds(from: log),
            database: database
        )
        let gains = MovementAPCalculator.gains(from: log, priorStates: priorStates)
        return try await persist(
            gains: gains,
            userId: log.userId,
            sourceLogId: log.id,
            priorStates: priorStates,
            database: database,
            persistenceMode: persistenceMode
        )
    }

    func ingest(
        _ log: WorkoutLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> MovementProgressIngestResult {
        do {
            return try await ingest(log, database: database, persistenceMode: .bestEffort)
        } catch {
            LoggingService.shared.log(
                "Movement progress best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": log.id]
            )
            return MovementProgressIngestResult()
        }
    }

    func ingestStrict(
        _ log: WorkoutLog,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> MovementProgressIngestResult {
        try await ingest(log, database: database, persistenceMode: .strict)
    }

    private func ingest(
        _ log: WorkoutLog,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> MovementProgressIngestResult {
        let priorStates = await loadPriorStates(
            userId: log.userId,
            standardIds: MovementAPCalculator.rankStandardMovementIds(from: log),
            database: database
        )
        let gains = MovementAPCalculator.gains(from: log, priorStates: priorStates)
        return try await persist(
            gains: gains,
            userId: log.userId,
            sourceLogId: log.id,
            priorStates: priorStates,
            database: database,
            persistenceMode: persistenceMode
        )
    }

    private func persist(
        gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        priorStates: [String: MovementProgressState] = [:],
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> MovementProgressIngestResult {
        let grouped = Dictionary(grouping: gains, by: \.rankStandardMovementId)
        var updatedStates: [MovementProgressState] = []
        var persistedGains: [MovementAPGain] = []
        var replayPriorStates = priorStates
        let profile = await loadUserProfile(userId: userId, database: database)

        for (standardId, standardGains) in grouped {
            guard let first = standardGains.first else { continue }
            var state = await loadState(
                userId: userId,
                standardId: standardId,
                fallback: first,
                database: database
            )

            if state.processedSourceLogIds.contains(sourceLogId) {
                if persistenceMode == .strict {
                    if let receipt = await loadPersistedMovementReceipt(
                        sourceLogId: sourceLogId,
                        standardId: standardId,
                        database: database
                    ) {
                        replayPriorStates[standardId] = receipt.priorState
                        updatedStates.append(receipt.updatedState)
                        persistedGains.append(contentsOf: receipt.gains)
                    } else {
                        let replayGains = await loadPersistedGains(
                            fallbackGains: standardGains,
                            database: database
                        )
                        if let replayPriorState = await loadPersistedPriorState(
                            sourceLogId: sourceLogId,
                            standardId: standardId,
                            database: database
                        ) {
                            replayPriorStates[standardId] = replayPriorState
                        }
                        updatedStates.append(state)
                        persistedGains.append(contentsOf: replayGains)
                    }
                }
                continue
            }

            let priorState = state
            state.apply(gains: standardGains, sourceLogId: sourceLogId)
            state.refreshProvenTier(
                bodyweightKg: profile?.weightKg,
                sex: profile?.biologicalSex
            )
            try await persistMovementArtifacts(
                priorState: priorState,
                state: state,
                gains: standardGains,
                sourceLogId: sourceLogId,
                database: database,
                persistenceMode: persistenceMode
            )

            updatedStates.append(state)
            persistedGains.append(contentsOf: standardGains)
        }

        if !updatedStates.isEmpty {
            NotificationCenter.default.post(
                name: .movementProgressUpdated,
                object: nil,
                userInfo: ["states": updatedStates]
            )
        }

        return MovementProgressIngestResult(
            gains: persistedGains,
            updatedStates: updatedStates,
            priorStates: replayPriorStates
        )
    }

    private func persistMovementArtifacts(
        priorState: MovementProgressState,
        state: MovementProgressState,
        gains: [MovementAPGain],
        sourceLogId: String,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws {
        switch persistenceMode {
        case .strict:
            try await database.create(
                priorState,
                collection: "movement_progress_prior_states",
                documentId: movementPriorStateDocumentId(
                    sourceLogId: sourceLogId,
                    standardId: state.rankStandardMovementId
                )
            )
            for gain in gains {
                try await database.create(gain, collection: "movement_ap_gains", documentId: gain.id)
            }
            try await database.create(
                MovementProgressSourceReceipt(
                    sourceLogId: sourceLogId,
                    userId: state.userId,
                    rankStandardMovementId: state.rankStandardMovementId,
                    gains: gains,
                    priorState: priorState,
                    updatedState: state
                ),
                collection: "movement_progress_source_receipts",
                documentId: movementPriorStateDocumentId(
                    sourceLogId: sourceLogId,
                    standardId: state.rankStandardMovementId
                )
            )
            try await database.create(state, collection: "movement_progress", documentId: state.id)
        case .bestEffort:
            do {
                try await database.create(state, collection: "movement_progress", documentId: state.id)
            } catch {
                LoggingService.shared.log(
                    "Movement progress state write failed: \(error)",
                    level: .warning,
                    context: ["documentId": state.id]
                )
            }
            for gain in gains {
                do {
                    try await database.create(gain, collection: "movement_ap_gains", documentId: gain.id)
                } catch {
                    LoggingService.shared.log(
                        "Movement AP gain write failed: \(error)",
                        level: .warning,
                        context: ["documentId": gain.id]
                    )
                }
            }
        }
    }

    private func loadPersistedPriorState(
        sourceLogId: String,
        standardId: String,
        database: any DatabaseServiceProtocol
    ) async -> MovementProgressState? {
        try? await database.read(
            collection: "movement_progress_prior_states",
            documentId: movementPriorStateDocumentId(sourceLogId: sourceLogId, standardId: standardId)
        )
    }

    private func loadPersistedMovementReceipt(
        sourceLogId: String,
        standardId: String,
        database: any DatabaseServiceProtocol
    ) async -> MovementProgressSourceReceipt? {
        try? await database.read(
            collection: "movement_progress_source_receipts",
            documentId: movementPriorStateDocumentId(sourceLogId: sourceLogId, standardId: standardId)
        )
    }

    private func movementPriorStateDocumentId(sourceLogId: String, standardId: String) -> String {
        "\(sourceLogId):\(standardId)"
    }

    private func loadPersistedGains(
        fallbackGains: [MovementAPGain],
        database: any DatabaseServiceProtocol
    ) async -> [MovementAPGain] {
        var gains: [MovementAPGain] = []
        for fallback in fallbackGains {
            if let persisted: MovementAPGain = try? await database.read(
                collection: "movement_ap_gains",
                documentId: fallback.id
            ) {
                gains.append(persisted)
            } else {
                gains.append(fallback)
            }
        }
        return gains
    }

    private func loadState(
        userId: String,
        standardId: String,
        fallback: MovementAPGain,
        database: any DatabaseServiceProtocol
    ) async -> MovementProgressState {
        let documentId = "\(userId):\(standardId)"
        if var existing: MovementProgressState = try? await database.read(
            collection: "movement_progress",
            documentId: documentId
        ) {
            if existing.displayName != fallback.standardDisplayName || existing.rankTemplate != fallback.rankTemplate {
                existing.displayName = fallback.standardDisplayName
                existing.rankTemplate = fallback.rankTemplate
                existing.updatedAt = Date()
            }
            return existing
        }

        return MovementProgressState(
            userId: userId,
            rankStandardMovementId: standardId,
            displayName: fallback.standardDisplayName,
            rankTemplate: fallback.rankTemplate
        )
    }

    private func loadUserProfile(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> UserProfile? {
        try? await database.read(collection: "users", documentId: userId)
    }

    private func loadPriorStates(
        userId: String,
        standardIds: [String],
        database: any DatabaseServiceProtocol
    ) async -> [String: MovementProgressState] {
        var states: [String: MovementProgressState] = [:]
        for standardId in standardIds {
            let documentId = "\(userId):\(standardId)"
            if let existing: MovementProgressState = try? await database.read(
                collection: "movement_progress",
                documentId: documentId
            ) {
                states[standardId] = existing
            }
        }
        return states
    }
}

@MainActor
final class OverallLevelService {
    static let shared = OverallLevelService()

    private init() {}

    /// Last-known persisted progress per user, kept in memory so the reward
    /// preview can baseline the overall-level bar correctly (instead of from 0)
    /// when the async progression path times out.
    private var cachedProgress: [String: OverallLevelProgress] = [:]

    /// Synchronous read of the user's last-known total XP, or nil if unseen
    /// this launch. Used only by `previewProgression`.
    func cachedTotalXP(userId: String) -> Double? { cachedProgress[userId]?.totalXP }

    @discardableResult
    func ingest(
        rawAP: Double,
        noveltyMultiplier: Double,
        sourceLogId: String,
        userId: String,
        at date: Date,
        gains: [MovementAPGain] = [],
        rankUpEvents: Int = 0,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> OverallLevelReward {
        do {
            return try await ingest(
                rawAP: rawAP,
                noveltyMultiplier: noveltyMultiplier,
                sourceLogId: sourceLogId,
                userId: userId,
                at: date,
                gains: gains,
                rankUpEvents: rankUpEvents,
                database: database,
                persistenceMode: .bestEffort
            )
        } catch {
            LoggingService.shared.log(
                "Overall level best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": sourceLogId]
            )
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: noveltyMultiplier,
                previousXP: 0,
                currentXP: 0,
                previousLevel: 0,
                currentLevel: 0,
                previousProgressToNextLevel: 0,
                currentProgressToNextLevel: 0
            )
        }
    }

    @discardableResult
    func ingestStrict(
        rawAP: Double,
        noveltyMultiplier: Double,
        sourceLogId: String,
        userId: String,
        at date: Date,
        gains: [MovementAPGain] = [],
        rankUpEvents: Int = 0,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> OverallLevelReward {
        try await ingest(
            rawAP: rawAP,
            noveltyMultiplier: noveltyMultiplier,
            sourceLogId: sourceLogId,
            userId: userId,
            at: date,
            gains: gains,
            rankUpEvents: rankUpEvents,
            database: database,
            persistenceMode: .strict
        )
    }

    private func ingest(
        rawAP: Double,
        noveltyMultiplier: Double,
        sourceLogId: String,
        userId: String,
        at date: Date,
        gains: [MovementAPGain],
        rankUpEvents: Int,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> OverallLevelReward {
        var progress = await loadProgress(userId: userId, database: database)
        let previousXP = progress.totalXP
        let previousLevel = progress.level
        let previousProgress = progress.progressToNextLevel

        // Velocity layer: when the per-movement gains are supplied, weight LV by
        // each movement's skill + compound factors instead of crediting flat
        // volume. Falls back to the scalar `rawAP` for callers that don't pass
        // gains (previews, legacy paths).
        let effectiveAP = gains.isEmpty
            ? rawAP
            : VelocityWeighting.weightedAP(gains: gains)
        let bolus = VelocityWeighting.rankUpBolus(rankUpEvents: rankUpEvents)

        if progress.processedSourceLogIds.contains(sourceLogId) {
            if persistenceMode == .strict {
                return progress.processedSourceRewards[sourceLogId]
                    ?? duplicateReward(
                        from: progress,
                        noveltyMultiplier: noveltyMultiplier
                    )
            }
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: noveltyMultiplier,
                previousXP: previousXP,
                currentXP: previousXP,
                previousLevel: previousLevel,
                currentLevel: previousLevel,
                previousProgressToNextLevel: previousProgress,
                currentProgressToNextLevel: previousProgress
            )
        }

        guard effectiveAP > 0 || bolus > 0 else {
            return OverallLevelReward(
                xpGained: 0,
                noveltyMultiplier: noveltyMultiplier,
                previousXP: previousXP,
                currentXP: previousXP,
                previousLevel: previousLevel,
                currentLevel: previousLevel,
                previousProgressToNextLevel: previousProgress,
                currentProgressToNextLevel: previousProgress
            )
        }

        // Comeback bonus only applies to a returning user (a prior session
        // exists); a first-ever session is always neutral.
        let comeback: Double = {
            guard !progress.processedSourceLogIds.isEmpty else { return 1.0 }
            let days = max(0, date.timeIntervalSince(progress.updatedAt)) / 86_400
            return VelocityWeighting.comebackMultiplier(daysSinceLastSession: days)
        }()

        let xpGained = RewardLedgerQuantizer.wholePoints(
            from: effectiveAP * max(1.0, noveltyMultiplier) * comeback
        ) + bolus
        progress.apply(xpGained: xpGained, sourceLogId: sourceLogId, at: date)

        let reward = OverallLevelReward(
            xpGained: xpGained,
            noveltyMultiplier: noveltyMultiplier,
            previousXP: previousXP,
            currentXP: progress.totalXP,
            previousLevel: previousLevel,
            currentLevel: progress.level,
            previousProgressToNextLevel: previousProgress,
            currentProgressToNextLevel: progress.progressToNextLevel
        )
        progress.processedSourceRewards[sourceLogId] = reward
        try await persistOverallProgress(
            progress,
            database: database,
            persistenceMode: persistenceMode
        )
        cachedProgress[userId] = progress

        NotificationCenter.default.post(
            name: .overallLevelProgressUpdated,
            object: reward,
            userInfo: ["progress": progress]
        )

        return reward
    }

    private func duplicateReward(
        from progress: OverallLevelProgress,
        noveltyMultiplier: Double
    ) -> OverallLevelReward {
        let xpGained = max(0, progress.lastGainedXP)
        let previousXP = max(0, progress.totalXP - xpGained)
        return OverallLevelReward(
            xpGained: xpGained,
            noveltyMultiplier: noveltyMultiplier,
            previousXP: previousXP,
            currentXP: progress.totalXP,
            previousLevel: OverallLevelCurve.level(forXP: previousXP),
            currentLevel: progress.level,
            previousProgressToNextLevel: OverallLevelCurve.progressFraction(forXP: previousXP),
            currentProgressToNextLevel: progress.progressToNextLevel
        )
    }

    private func persistOverallProgress(
        _ progress: OverallLevelProgress,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws {
        switch persistenceMode {
        case .strict:
            try await database.create(
                progress,
                collection: "overall_level_progress",
                documentId: progress.id
            )
        case .bestEffort:
            do {
                try await database.create(
                    progress,
                    collection: "overall_level_progress",
                    documentId: progress.id
                )
            } catch {
                LoggingService.shared.log(
                    "Overall level progress write failed: \(error)",
                    level: .warning,
                    context: ["documentId": progress.id]
                )
            }
        }
    }

    private func loadProgress(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> OverallLevelProgress {
        if let existing: OverallLevelProgress = try? await database.read(
            collection: "overall_level_progress",
            documentId: userId
        ) {
            cachedProgress[userId] = existing
            return existing
        }

        let fresh = OverallLevelProgress(userId: userId)
        cachedProgress[userId] = fresh
        return fresh
    }
}

@MainActor
final class BodyMapProgressService {
    static let shared = BodyMapProgressService()

    private static let recentHalfLifeSeconds: TimeInterval = 14 * 24 * 60 * 60
    private static let recentFullSaturationLoad: Double = 500
    private static let lifetimeFullSaturationLoad: Double = 5_000
    private static let maxLifetimeBaseline: Double = 0.2

    private init() {}

    /// Last-known body-map profile per user, kept in memory so the reward
    /// preview can compute the real region-novelty multiplier (instead of a flat
    /// 1.0) when the async progression path times out.
    private var cachedProfiles: [String: BodyMapProfile] = [:]

    /// Synchronous novelty multiplier from the user's last-known profile, for
    /// `previewProgression`. Returns the neutral 1.0 if unseen this launch.
    func previewNoveltyMultiplier(for regions: [BodyRegion], userId: String, at date: Date) -> Double {
        guard let profile = cachedProfiles[userId] else { return 1.0 }
        return noveltyMultiplier(for: regions, profile: profile, at: date)
    }

    func profile(
        userId: String,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> BodyMapProfile {
        await loadProfile(userId: userId, database: database)
    }

    @discardableResult
    func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        at date: Date,
        trainingLoads: [BodyRegionTrainingLoad] = [],
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async -> BodyMapIngestResult {
        do {
            return try await ingest(
                movementAPGains: gains,
                userId: userId,
                sourceLogId: sourceLogId,
                at: date,
                trainingLoads: trainingLoads,
                database: database,
                persistenceMode: .bestEffort
            )
        } catch {
            LoggingService.shared.log(
                "Body-map best-effort ingest failed: \(error)",
                level: .warning,
                context: ["sourceLogId": sourceLogId]
            )
            return BodyMapIngestResult()
        }
    }

    @discardableResult
    func ingestStrict(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        at date: Date,
        trainingLoads: [BodyRegionTrainingLoad] = [],
        database: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) async throws -> BodyMapIngestResult {
        try await ingest(
            movementAPGains: gains,
            userId: userId,
            sourceLogId: sourceLogId,
            at: date,
            trainingLoads: trainingLoads,
            database: database,
            persistenceMode: .strict
        )
    }

    private func ingest(
        movementAPGains gains: [MovementAPGain],
        userId: String,
        sourceLogId: String,
        at date: Date,
        trainingLoads: [BodyRegionTrainingLoad],
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws -> BodyMapIngestResult {
        guard !gains.isEmpty || !trainingLoads.isEmpty else { return BodyMapIngestResult() }

        var profile = await loadProfile(userId: userId, database: database)
        if profile.processedSourceLogIds.contains(sourceLogId) {
            if persistenceMode == .strict {
                if let receipt = await loadPersistedBodyMapReceipt(
                    sourceLogId: sourceLogId,
                    database: database
                ) {
                    return receipt.result
                }
                return duplicateResult(
                    from: profile,
                    gains: gains,
                    trainingLoads: trainingLoads,
                    at: date
                )
            }
            return BodyMapIngestResult(wasDuplicate: true)
        }

        let loadsByRegion = regionLoads(from: gains, trainingLoads: trainingLoads)
        let trainingLoadsByRegion = mergedTrainingLoads(trainingLoads)
        let novelty = noveltyMultiplier(for: Array(loadsByRegion.keys), profile: profile, at: date)
        var rewards: [BodyMapRegionReward] = []

        for (region, loadAdded) in loadsByRegion {
            var load = profile.load(for: region)
            let decayFactor = recentDecayFactor(for: load, at: date)
            load.recentLoad = load.recentLoad * decayFactor + loadAdded
            load.lifetimeLoad += loadAdded
            load.decayRecentRoleSets(by: decayFactor)
            if let trainingLoad = trainingLoadsByRegion[region] {
                load.addRecentRoleSets(trainingLoad)
            }
            load.lastTrainedAt = date
            profile.setLoad(load, for: region)
            rewards.append(
                BodyMapRegionReward(
                    region: region,
                    loadAdded: (loadAdded * 10).rounded() / 10,
                    recentLoad: (load.recentLoad * 10).rounded() / 10,
                    lifetimeLoad: (load.lifetimeLoad * 10).rounded() / 10,
                    lastTrainedAt: date
                )
            )
        }

        if !profile.processedSourceLogIds.contains(sourceLogId) {
            profile.processedSourceLogIds.append(sourceLogId)
        }
        if profile.processedSourceLogIds.count > 250 {
            profile.processedSourceLogIds.removeFirst(profile.processedSourceLogIds.count - 250)
        }
        profile.updatedAt = date

        let result = BodyMapIngestResult(
            noveltyMultiplier: novelty,
            regionRewards: rewards.sorted { $0.region.rawValue < $1.region.rawValue },
            wasDuplicate: false
        )

        if persistenceMode == .strict {
            try await database.create(
                BodyMapSourceReceipt(
                    sourceLogId: sourceLogId,
                    userId: userId,
                    noveltyMultiplier: result.noveltyMultiplier,
                    regionRewards: result.regionRewards
                ),
                collection: "body_map_source_receipts",
                documentId: sourceLogId
            )
        }

        try await persistBodyMapProfile(
            profile,
            database: database,
            persistenceMode: persistenceMode
        )
        cachedProfiles[userId] = profile

        if !rewards.isEmpty {
            NotificationCenter.default.post(
                name: .bodyMapProgressUpdated,
                object: result,
                userInfo: ["profile": profile]
            )
        }

        return result
    }

    private func loadPersistedBodyMapReceipt(
        sourceLogId: String,
        database: any DatabaseServiceProtocol
    ) async -> BodyMapSourceReceipt? {
        try? await database.read(
            collection: "body_map_source_receipts",
            documentId: sourceLogId
        )
    }

    private func persistBodyMapProfile(
        _ profile: BodyMapProfile,
        database: any DatabaseServiceProtocol,
        persistenceMode: ProgressionPersistenceMode
    ) async throws {
        switch persistenceMode {
        case .strict:
            try await database.create(
                profile,
                collection: "body_map_profiles",
                documentId: profile.id
            )
        case .bestEffort:
            do {
                try await database.create(
                    profile,
                    collection: "body_map_profiles",
                    documentId: profile.id
                )
            } catch {
                LoggingService.shared.log(
                    "Body-map profile write failed: \(error)",
                    level: .warning,
                    context: ["documentId": profile.id]
                )
            }
        }
    }

    private func duplicateResult(
        from profile: BodyMapProfile,
        gains: [MovementAPGain],
        trainingLoads: [BodyRegionTrainingLoad],
        at date: Date
    ) -> BodyMapIngestResult {
        let loadsByRegion = regionLoads(from: gains, trainingLoads: trainingLoads)
        guard !loadsByRegion.isEmpty else {
            return BodyMapIngestResult(wasDuplicate: true)
        }

        var approximatePrior = profile
        for (region, loadAdded) in loadsByRegion {
            var load = approximatePrior.load(for: region)
            load.recentLoad = max(0, load.recentLoad - loadAdded)
            load.lifetimeLoad = max(0, load.lifetimeLoad - loadAdded)
            approximatePrior.setLoad(load, for: region)
        }
        let novelty = noveltyMultiplier(
            for: Array(loadsByRegion.keys),
            profile: approximatePrior,
            at: date
        )

        let rewards = loadsByRegion.map { region, loadAdded in
            let load = profile.load(for: region)
            return BodyMapRegionReward(
                region: region,
                loadAdded: (loadAdded * 10).rounded() / 10,
                recentLoad: (load.recentLoad * 10).rounded() / 10,
                lifetimeLoad: (load.lifetimeLoad * 10).rounded() / 10,
                lastTrainedAt: load.lastTrainedAt ?? date
            )
        }
        .sorted { $0.region.rawValue < $1.region.rawValue }

        return BodyMapIngestResult(
            noveltyMultiplier: novelty,
            regionRewards: rewards,
            wasDuplicate: true
        )
    }

    private func loadProfile(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> BodyMapProfile {
        if let existing: BodyMapProfile = try? await database.read(
            collection: "body_map_profiles",
            documentId: userId
        ) {
            cachedProfiles[userId] = existing
            return existing
        }

        let fresh = BodyMapProfile(userId: userId)
        cachedProfiles[userId] = fresh
        return fresh
    }

    private func regionLoads(
        from gains: [MovementAPGain],
        trainingLoads: [BodyRegionTrainingLoad] = []
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

        var loads: [BodyRegion: Double] = [:]

        for gain in gains where gain.rawAP > 0 {
            let regions = bodyRegions(for: gain)
            guard !regions.isEmpty else { continue }

            let loadShare = gain.rawAP / Double(regions.count)
            for region in regions {
                loads[region, default: 0] += loadShare
            }
        }

        return loads
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

    private func noveltyMultiplier(
        for regions: [BodyRegion],
        profile: BodyMapProfile,
        at date: Date
    ) -> Double {
        guard !regions.isEmpty else { return 1.0 }

        let multipliers = regions.map { region in
            let saturation = saturationNormalized(for: profile.load(for: region), at: date)
            return 1.0 + (1.0 - saturation) * 0.5
        }
        let average = multipliers.reduce(0, +) / Double(multipliers.count)
        return (average * 1_000).rounded() / 1_000
    }

    private func saturationNormalized(for load: BodyRegionLoad, at date: Date) -> Double {
        let recent = decayedRecentLoad(for: load, at: date)
        let recentSaturation = recent / Self.recentFullSaturationLoad
        let lifetimeBaseline = min(Self.maxLifetimeBaseline, load.lifetimeLoad / Self.lifetimeFullSaturationLoad)
        return min(1.0, max(0.0, recentSaturation + lifetimeBaseline))
    }

    private func decayedRecentLoad(for load: BodyRegionLoad, at date: Date) -> Double {
        load.recentLoad * recentDecayFactor(for: load, at: date)
    }

    private func recentDecayFactor(for load: BodyRegionLoad, at date: Date) -> Double {
        guard let lastTrainedAt = load.lastTrainedAt else { return 1.0 }
        let elapsed = max(0, date.timeIntervalSince(lastTrainedAt))
        return pow(0.5, elapsed / Self.recentHalfLifeSeconds)
    }
}

extension ResolvedMovement {
    var definition: MovementDefinition? {
        MovementCatalog.definition(for: movementId)
    }
}
