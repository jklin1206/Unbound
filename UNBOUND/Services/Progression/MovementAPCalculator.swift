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
