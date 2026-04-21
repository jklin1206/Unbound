import Foundation

// MARK: - ProgressionEngine
//
// Deterministic RPE-based progression per Hawks' rules:
//
//   • Target RPE is set by the current block
//     - Accumulation: 7
//     - Intensification: 8
//     - Realization: 9
//     - Deload: 6
//   • Add weight when the athlete hits the TOP of the rep range at target
//     RPE for 2 consecutive sessions of the same exercise.
//   • Upper-body compound: +2.5 kg. Lower-body compound: +5 kg.
//   • Accessories: add reps before adding weight. Once max reps hit, then
//     +2.5 kg + reset rep counter to bottom of range.
//   • Bodyweight skills: tracked by reps/time, not weight — handled by
//     SkillProgressService. Engine still records sessions at target.
//
// The engine runs as a side-effect of `WorkoutLogService.saveLog` (already
// hooked in P1). Each logged set becomes a signal; the engine aggregates
// per exercise across the log, evaluates, mutates `ProgressionState` rows,
// and emits `.progressionAdvanced` for every weight bump (home dashboard
// shows a toast).

@MainActor
final class ProgressionEngine {
    static let shared = ProgressionEngine()
    private let logger = LoggingService.shared
    private let database = DatabaseService.shared

    private init() {}

    // MARK: Public entry point

    /// Ingest a freshly-saved WorkoutLog. For each distinct exercise in
    /// the log, update its ProgressionState per the rules. Called from
    /// `WorkoutLogService.saveLog` on success.
    ///
    /// - Parameters:
    ///   - log: the WorkoutLog to ingest.
    ///   - mode: `.advance` (default) performs weight bumps when criteria
    ///     are met. `.preserve` (cut mode) records sessions and unlocks
    ///     tiers but never bumps working weight — used while the user is
    ///     on a cut to hold strength.
    ///   - feedbackMode: optional user feedback preference. When provided
    ///     on first-seen exercises, seeds the ProgressionState's targetRPE
    ///     from `TrainingFeedbackMode.defaultTargetRPE`. `.silent` yields
    ///     `targetRPE = 0`, which makes the engine's RPE check a no-op
    ///     (reduces to pure rep-based progression).
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
    }

    // MARK: Per-exercise evaluation

    private func evaluate(
        entry: ExerciseLogEntry,
        userId: String,
        loggedAt: Date,
        mode: ProgressionMode,
        feedbackMode: TrainingFeedbackMode?
    ) async {
        let key = normalize(entry.exerciseName)

        // Load or seed state
        let state = await loadOrSeedState(
            userId: userId,
            exerciseKey: key,
            displayName: entry.exerciseName,
            entry: entry,
            feedbackMode: feedbackMode
        )

        // Find the best working set for this exercise in the log —
        // highest-RPE top-of-range hit with the most reps. Ignore warmups.
        let workingSets = entry.sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return }

        let bestSet = workingSets.max { a, b in
            // Primary: reps; tiebreak: RPE; tiebreak: weight
            if a.reps != b.reps { return a.reps < b.reps }
            if (a.rpe ?? 0) != (b.rpe ?? 0) { return (a.rpe ?? 0) < (b.rpe ?? 0) }
            return (a.weightKg ?? 0) < (b.weightKg ?? 0)
        } ?? workingSets[0]

        let hitTopOfRange = bestSet.reps >= state.targetRepMax
        let hitTargetRPE = (bestSet.rpe ?? 0) >= state.targetRPE

        var next = state
        next.updatedAt = loggedAt

        if hitTopOfRange && hitTargetRPE {
            next.consecutiveSessionsAtTarget += 1
        } else {
            next.consecutiveSessionsAtTarget = 0
        }

        // Tier unlock: if this exercise belongs to a progression family
        // and the athlete hit the criterion for 2 consecutive sessions,
        // advance the family's unlocked tier.
        if next.consecutiveSessionsAtTarget >= 2 {
            await maybeUnlockTier(
                userId: userId,
                exerciseKey: next.exerciseKey,
                displayName: next.displayName,
                at: loggedAt
            )
        }

        // Threshold hit — apply weight bump per classification.
        // In `.preserve` (cut) mode, we still persist session state and
        // allow tier unlocks, but we do NOT bump weights and do NOT fire
        // the `.progressionAdvanced` toast.
        if next.consecutiveSessionsAtTarget >= 2 {
            let previousWeight = next.currentWorkingWeightKg

            if mode == .advance {
                applyBump(to: &next)
            }
            // In .preserve mode, we persist state but do NOT bump weight.

            try? await database.create(next, collection: "progression_states", documentId: next.id)

            if mode == .advance && next.currentWorkingWeightKg > previousWeight {
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
                    "Progression advanced: \(next.displayName) \(previousWeight)kg → \(next.currentWorkingWeightKg)kg",
                    level: .info
                )
            }
        } else {
            try? await database.create(next, collection: "progression_states", documentId: next.id)
        }
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
            exercise: displayName,
            startingWeightKg: seedWeight
        )
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
            state.currentWorkingWeightKg += classification.weightBumpKg
            state.consecutiveSessionsAtTarget = 0
            state.lastBumpDate = Date()

        case .accessory:
            // Accessories: reps-first strategy. If we're still below the max of
            // an expanded rep window, just extend it; else bump weight + reset.
            let extendedMax = state.targetRepMax + 2
            if state.targetRepMax < extendedMax {
                state.targetRepMax = extendedMax
                state.consecutiveSessionsAtTarget = 0
            } else {
                state.currentWorkingWeightKg += classification.weightBumpKg
                state.targetRepMax = classification.defaultRepRange(for: state.blockType).upperBound
                state.consecutiveSessionsAtTarget = 0
                state.lastBumpDate = Date()
            }

        case .bodyweightSkill:
            // Bodyweight moves progress via skill tree, not weight. Just note
            // that 2 consecutive top-range sessions happened and let the skill
            // tree service act on it.
            state.consecutiveSessionsAtTarget = 0
        }
    }

    // MARK: Exercise name normalization

    private func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    // MARK: Tier unlock (chunk 2B)

    private func maybeUnlockTier(
        userId: String,
        exerciseKey: String,
        displayName: String,
        at: Date
    ) async {
        guard let catalogEntry = ExerciseCatalog.allExercises.first(where: {
            $0.name == exerciseKey || $0.displayName.lowercased() == exerciseKey
        }),
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

        let familyExercises = ExerciseCatalog.progressionFamily(family)
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
