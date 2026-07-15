import Foundation

// Double progression: two clean top-range sessions bump load, while explicit
// low-RPE over-performance advances immediately. Accessories climb reps before
// bounded load bumps; timed isometrics use movement-specific seconds ladders.

@MainActor
final class ProgressionEngine {
    static let shared = ProgressionEngine()
    private let logger = LoggingService.shared
    private let database = DatabaseService.shared

    private init() {}

    // MARK: Public entry point

    /// Updates each exercise in a saved log. Preserve mode records evidence and
    /// unlocks tiers without increasing load; silent feedback is rep-only.
    func ingest(
        log: WorkoutLog,
        mode: ProgressionMode = .advance,
        feedbackMode: TrainingFeedbackMode? = nil
    ) async {
        for entry in log.exerciseEntries where !entry.skipped {
            await evaluate(
                entry: entry,
                userId: log.userId,
                loggedAt: log.startedAt,
                mode: mode,
                feedbackMode: feedbackMode
            )
        }

        // Auto-deload: after states are updated, detect plateaus and deload
        // without a Coach tap when warranted (anti-thrash inside the service).
        await AutoDeloadService.shared.evaluate(userId: log.userId)
    }

    // MARK: Per-exercise evaluation

    private func evaluate(
        entry: ExerciseLogEntry,
        userId: String,
        loggedAt: Date,
        mode: ProgressionMode,
        feedbackMode: TrainingFeedbackMode?
    ) async {
        let identity = progressionIdentity(for: entry)
        let key = identity.exerciseKey

        // Load or seed state
        let state = await loadOrSeedState(
            userId: userId,
            exerciseKey: key,
            displayName: identity.displayName,
            entry: entry,
            feedbackMode: feedbackMode
        )

        let workingSets = entry.sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return }

        if workingSets.contains(where: { ($0.durationSeconds ?? 0) > 0 }) {
            await evaluateTimedHold(
                workingSets: workingSets,
                entry: entry,
                state: state,
                identity: identity,
                userId: userId,
                loggedAt: loggedAt,
                mode: mode
            )
            return
        }

        let bestSet = workingSets.max { a, b in
            if a.reps != b.reps { return a.reps < b.reps }
            return (a.weightKg ?? 0) < (b.weightKg ?? 0)
        } ?? workingSets[0]

        let effortAllowed = Self.effortAllowsProgression(
            loggedRPE: bestSet.rpe,
            targetRPE: state.targetRPE
        )
        let hitTarget = Self.sessionHitsTarget(
            bestSetReps: bestSet.reps,
            targetRepMax: state.targetRepMax
        ) && effortAllowed
        let plannedTarget = RepRange.lowerBound(entry.plannedReps) ?? state.currentTargetReps
        let overPerformed = bestSet.rpe.map { $0 <= 7 } == true
            && bestSet.reps >= plannedTarget + 2

        var next = state
        if next.initialWorkingWeightKg == nil {
            next.initialWorkingWeightKg = next.currentWorkingWeightKg
        }
        next.updatedAt = loggedAt
        next.lastSessionReps = bestSet.reps
        next.lastSessionRPE = bestSet.rpe
        next.lastSessionDurationSeconds = nil
        next.lastSessionHitTarget = hitTarget || overPerformed
        next.lastSessionWasGrindy = bestSet.rpe.map { $0 >= 9 && $0 > state.targetRPE } ?? false

        // Easy user-entered load is stronger evidence than a stale suggestion.
        if let loggedWeight = bestSet.weightKg,
           loggedWeight > next.currentWorkingWeightKg,
           bestSet.rpe.map({ $0 <= 7 }) == true {
            next.currentWorkingWeightKg = WeightPlatePolicy.snappedSuggestionKilograms(loggedWeight)
        }

        if overPerformed {
            next.consecutiveSessionsAtTarget = 2
            next.underTargetSessionCount = 0
            next.prescriptionBias = .harder
        } else if hitTarget {
            next.consecutiveSessionsAtTarget += 1
            next.underTargetSessionCount = 0
            next.prescriptionBias = .hold
        } else {
            next.consecutiveSessionsAtTarget = 0
            let misses = (state.underTargetSessionCount ?? 0) + 1
            next.underTargetSessionCount = misses
            next.prescriptionBias = misses >= 2 ? .easier : .hold
        }

        // Advance the movement family's unlocked tier after two proofs.
        if next.consecutiveSessionsAtTarget >= 2 {
            await maybeUnlockTier(
                userId: userId,
                exerciseKey: next.exerciseKey,
                displayName: next.displayName,
                familyUnlockDefinition: identity.familyUnlockDefinition,
                at: loggedAt
            )
        }

        // Preserve mode persists proof without bumping load or emitting a toast.
        if next.consecutiveSessionsAtTarget >= 2 {
            let previousWeight = next.currentWorkingWeightKg

            if mode == .advance {
                applyBump(to: &next)
            }
            // In .preserve mode, we persist state but do NOT bump weight.
            let bumpedWeight = mode == .advance && next.currentWorkingWeightKg > previousWeight
            if bumpedWeight && !overPerformed {
                next.prescriptionBias = .hold
            }
            if mode == .advance && (next.classification == .bodyweightSkill || overPerformed) {
                next.prescriptionBias = .harder
            }

            try? await database.create(next, collection: "progression_states", documentId: next.id)

            if bumpedWeight {
                let unit = WeightPlatePolicy.currentUnit
                let event = ProgressionAdvance(
                    userId: userId,
                    exerciseKey: next.exerciseKey,
                    displayName: next.displayName,
                    previousWeightKg: previousWeight,
                    newWeightKg: next.currentWorkingWeightKg,
                    classification: next.classification,
                    at: loggedAt
                )
                NotificationCenter.default.post(
                    name: .progressionAdvanced,
                    object: nil,
                    userInfo: ["event": event]
                )
                logger.log(
                    "Progression advanced: \(next.displayName) \(WeightPlatePolicy.formatLoggedWeight(previousWeight, unit: unit))\(unit.shortLabel) -> \(WeightPlatePolicy.formatLoggedWeight(next.currentWorkingWeightKg, unit: unit))\(unit.shortLabel)",
                    level: .info
                )
            }
        } else {
            try? await database.create(next, collection: "progression_states", documentId: next.id)
        }
    }

    private func evaluateTimedHold(
        workingSets: [SetLog],
        entry: ExerciseLogEntry,
        state: ProgressionState,
        identity: ProgressionIdentity,
        userId: String,
        loggedAt: Date,
        mode: ProgressionMode
    ) async {
        guard let bestSet = workingSets.max(by: {
            ($0.durationSeconds ?? 0) < ($1.durationSeconds ?? 0)
        }), let duration = bestSet.durationSeconds else { return }

        var next = state
        let target = state.currentTargetDurationSeconds
        let plannedTarget = RepRange.lowerBound(entry.plannedReps) ?? target
        let effortAllowed = Self.effortAllowsProgression(
            loggedRPE: bestSet.rpe,
            targetRPE: state.targetRPE
        )
        let hitTarget = duration >= target && effortAllowed
        let overPerformed = bestSet.rpe.map { $0 <= 7 } == true
            && duration >= IsometricDurationPolicy.nextTarget(
                after: plannedTarget,
                exerciseKey: state.exerciseKey
            )

        next.updatedAt = loggedAt
        next.lastSessionReps = nil
        next.lastSessionDurationSeconds = duration
        next.lastSessionRPE = bestSet.rpe
        next.lastSessionHitTarget = hitTarget || overPerformed
        next.lastSessionWasGrindy = bestSet.rpe.map { $0 >= 9 && $0 > state.targetRPE } ?? false

        if overPerformed {
            next.consecutiveSessionsAtTarget = 2
            next.underTargetSessionCount = 0
            next.prescriptionBias = .harder
        } else if hitTarget {
            next.consecutiveSessionsAtTarget += 1
            next.underTargetSessionCount = 0
            next.prescriptionBias = .hold
        } else {
            next.consecutiveSessionsAtTarget = 0
            let misses = (state.underTargetSessionCount ?? 0) + 1
            next.underTargetSessionCount = misses
            next.prescriptionBias = misses >= 2 ? .easier : .hold
        }

        if next.consecutiveSessionsAtTarget >= 2 {
            await maybeUnlockTier(
                userId: userId,
                exerciseKey: next.exerciseKey,
                displayName: next.displayName,
                familyUnlockDefinition: identity.familyUnlockDefinition,
                at: loggedAt
            )
            if mode == .advance {
                next.targetDurationSeconds = IsometricDurationPolicy.nextTarget(
                    after: max(target, duration),
                    exerciseKey: next.exerciseKey
                )
                next.consecutiveSessionsAtTarget = 0
                next.prescriptionBias = .harder
            }
        }

        try? await database.create(next, collection: "progression_states", documentId: next.id)
    }

    // MARK: Load / seed

    private func loadOrSeedState(
        userId: String,
        exerciseKey: String,
        displayName: String,
        entry: ExerciseLogEntry,
        feedbackMode: TrainingFeedbackMode?
    ) async -> ProgressionState {
        let id = "\(userId):\(exerciseKey)"
        if let existing: ProgressionState = try? await database.read(
            collection: "progression_states",
            documentId: id
        ) {
            return existing
        }
        // First time we've seen this exercise — seed from the log's heaviest working set.
        let workingSets = entry.sets.filter { !$0.isWarmup }
        let seedWeight = workingSets.compactMap { $0.weightKg }.max() ?? 0
        var seeded = ProgressionState.seed(
            userId: userId,
            exercise: exerciseKey,
            startingWeightKg: seedWeight
        )
        seeded.displayName = displayName
        // Override targetRPE from the user's feedback preference when provided.
        // `.silent` → 0 (RPE check becomes a no-op; pure rep-based progression).
        if let feedbackMode {
            seeded.targetRPE = feedbackMode.defaultTargetRPE
        }
        return seeded
    }

    // MARK: Bump logic

    private func applyBump(to state: inout ProgressionState) {
        let classification = state.classification

        switch classification {
        case .upperCompound, .lowerCompound:
            state.currentWorkingWeightKg = WeightPlatePolicy.progressedWeightKilograms(
                from: state.currentWorkingWeightKg,
                classification: classification
            )
            state.consecutiveSessionsAtTarget = 0
            state.lastBumpDate = Date()

        case .accessory:
            // Accessories climb reps to a cap, then bump load and reset the range.
            let ceiling = accessoryRepCeiling(for: state)
            if state.targetRepMax < ceiling {
                state.targetRepMax = min(ceiling, state.targetRepMax + 2)
                state.consecutiveSessionsAtTarget = 0
            } else {
                let candidate = WeightPlatePolicy.progressedWeightKilograms(
                    from: state.currentWorkingWeightKg,
                    classification: classification
                )
                if candidate > state.currentWorkingWeightKg,
                   candidate <= maximumAutomaticAccessoryWeight(for: state) {
                    state.currentWorkingWeightKg = candidate
                    state.targetRepMax = classification.defaultRepRange(for: state.blockType).upperBound
                    state.lastBumpDate = Date()
                }
                state.consecutiveSessionsAtTarget = 0
            }

        case .bodyweightSkill:
            // Bodyweight difficulty advances through the skill tree, not load.
            state.consecutiveSessionsAtTarget = 0
        }
    }

    static func sessionHitsTarget(bestSetReps: Int, targetRepMax: Int) -> Bool {
        bestSetReps >= targetRepMax
    }

    static func effortAllowsProgression(loggedRPE: Int?, targetRPE: Int) -> Bool {
        guard targetRPE > 0, let loggedRPE else { return true }
        return loggedRPE <= targetRPE
    }

    private func accessoryRepCeiling(for state: ProgressionState) -> Int {
        max(20, state.classification.defaultRepRange(for: state.blockType).upperBound)
    }

    /// Bounds automatic ramps; logged proof may still establish a higher load.
    private func maximumAutomaticAccessoryWeight(for state: ProgressionState) -> Double {
        let anchor = max(0, state.initialWorkingWeightKg ?? state.currentWorkingWeightKg)
        guard anchor > 0 else { return 0 }
        let boundedGrowth = min(80, max(anchor * 1.75, anchor + 15))
        return max(state.currentWorkingWeightKg, boundedGrowth)
    }

    // MARK: Exercise name normalization

    private struct ProgressionIdentity {
        let exerciseKey: String
        let displayName: String
        let familyUnlockDefinition: MovementDefinition?
    }

    private func progressionIdentity(for entry: ExerciseLogEntry) -> ProgressionIdentity {
        let resolved = MovementCatalog.resolvedTrainingMovement(
            name: entry.exerciseName,
            movementId: entry.movementId,
            rankStandardMovementId: entry.rankStandardMovementId
        )
        let exactDefinition = resolved?.exact
        let standardDefinition = resolved?.standard

        let familyUnlockDefinition = [
            exactDefinition,
            standardDefinition
        ].compactMap { $0 }.first {
            $0.progressionFamily != nil && $0.progressionTier != nil
        }

        if let definition = standardDefinition ?? exactDefinition {
            return ProgressionIdentity(
                exerciseKey: normalize(definition.canonicalExerciseName ?? definition.displayName),
                displayName: definition.displayName,
                familyUnlockDefinition: familyUnlockDefinition
            )
        }

        return ProgressionIdentity(
            exerciseKey: normalize(entry.exerciseName),
            displayName: entry.exerciseName,
            familyUnlockDefinition: nil
        )
    }

    private func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: Tier unlock (chunk 2B)

    private func maybeUnlockTier(
        userId: String,
        exerciseKey: String,
        displayName: String,
        familyUnlockDefinition: MovementDefinition?,
        at: Date
    ) async {
        guard let catalogEntry = familyUnlockDefinition
                ?? MovementCatalog.canonicalExercise(named: displayName)
                ?? MovementCatalog.canonicalExercise(named: exerciseKey),
              let family = catalogEntry.progressionFamily,
              let tier = catalogEntry.progressionTier else {
            return
        }

        let store = ProgressionStateStore.shared
        let existing = await store.familyState(userId: userId, family: family)
        let current = existing ?? ProgressionFamilyState(
            userId: userId,
            family: family,
            unlockedTier: 0,
            currentTier: 0,
            updatedAt: at
        )

        guard tier == current.unlockedTier else { return }

        let familyExercises = MovementCatalog.progressionDefinitions(family: family)
        let maxTier = familyExercises.compactMap(\.progressionTier).max() ?? tier
        let nextTier = min(tier + 1, maxTier)
        guard nextTier > current.unlockedTier else { return }

        let nextExercise = familyExercises.first(where: { ($0.progressionTier ?? -1) == nextTier })
        let nextDisplayName = nextExercise?.displayName ?? "Tier \(nextTier)"

        var updated = current
        updated.unlockedTier = nextTier
        updated.updatedAt = at
        await store.saveFamilyState(updated)

        let event = TierUnlock(
            userId: userId,
            family: family,
            newTier: nextTier,
            exerciseName: nextDisplayName,
            at: at
        )
        NotificationCenter.default.post(
            name: .tierUnlocked,
            object: nil,
            userInfo: ["event": event]
        )
        logger.log(
            "Tier unlocked: \(family) → tier \(nextTier) (\(nextDisplayName))",
            level: .info
        )
    }
}
