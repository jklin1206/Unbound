import SwiftUI

// MARK: - ActiveWorkoutContainerView session context
//
// The session's data plumbing: the draft-autosave funnel, prior-history +
// working-weight context loading, suggested-weight prefill ghosts, and the
// rest-timer transition fired on each SUGGESTED→LOGGED set edge.

extension ActiveWorkoutContainerView {
    // MARK: - Draft autosave

    /// Single funnel for draft autosave. A failure here means kill/crash
    /// recovery is broken, so it's logged once and surfaced as a calm warning
    /// row instead of failing silently.
    func saveDraft() {
        guard !isRehearsal else { return }
        do {
            try draftStore.save(session)
            draftAutosaveFailed = false
        } catch {
            if !draftAutosaveFailed {
                LoggingService.shared.log(
                    "Workout draft autosave failed: \(error)",
                    level: .error
                )
            }
            draftAutosaveFailed = true
        }
    }

    // MARK: - Rest timer

    private func startRest(ei: Int, si: Int) {
        guard session.exercises.indices.contains(ei) else { return }
        let setRest = session.exercises[ei].sets.indices.contains(si)
            ? session.exercises[ei].sets[si].suggestedRestSeconds
            : nil
        let secs = setRest ?? session.exercises[ei].restSeconds
        let next = session.exercises[ei].name
        restTimer.onElapsed = { UnboundHaptics.success() }
        restTimer.start(seconds: secs, nextLabel: next)
    }

    /// Fired exactly once per set on the SUGGESTED→LOGGED edge.
    func transition(ei: Int, si: Int) {
        UnboundHaptics.success()
        startRest(ei: ei, si: si)
    }

    /// After loadContext resolves history/working-weight, fill each set's
    /// dim suggested weight via the existing SetPrefill ghost.
    private func applySuggestedWeights() {
        for ei in session.exercises.indices {
            for si in session.exercises[ei].sets.indices
            where session.exercises[ei].sets[si].suggestedWeightKg == nil {
                let fallbackWeight = ei == session.currentExerciseIndex ? workingWeightKg : nil
                if let g = SetPrefill.ghost(
                    exerciseName: session.exercises[ei].name,
                    setIndex: si,
                    priorEntries: priorEntries,
                    workingWeightKg: fallbackWeight) {
                    session.exercises[ei].sets[si].suggestedWeightKg = g.weightKg.map {
                        WeightPlatePolicy.snappedSuggestionKilograms(
                            $0,
                            unit: weightUnit,
                            microloadingEnabled: microloadingEnabled
                        )
                    }
                }
            }
        }
    }

    // MARK: - Load context (wired to real APIs)

    func loadContext() async {
        guard let uid = services.auth.currentUserId else { return }

        // Gear for the swap picker's compatibility badges (graceful: nil = no filter).
        if let profileEquipment = (try? await services.user.fetchProfile(userId: uid))?.equipment,
           !profileEquipment.isEmpty {
            swapEquipment = profileEquipment
        }

        // Wire point 1: fetchRecentLogs(userId:limit:) exists on WorkoutLogServiceProtocol.
        // Flatten exerciseEntries from the most-recent logs so SetPrefill can
        // find last-session values per exercise (most-recent last = .last(where:) picks latest).
        let recentLogs: [WorkoutLog] = (try? await services.workoutLog.fetchRecentLogs(userId: uid, limit: 40)) ?? []
        priorEntries = recentLogs
            .sorted { $0.startedAt < $1.startedAt } // oldest first → SetPrefill.last picks newest
            .flatMap { $0.exerciseEntries }

        // Last-performance: most-recent prior WorkoutLogs → per-set reference + prefill source.
        let lookup = LastPerformanceLookup(logs: recentLogs, excludingLogId: nil)  // live session has no persisted WorkoutLog yet
        for ei in session.exercises.indices {
            let mid = session.exercises[ei].movementId
            let name = session.exercises[ei].name
            var workingIndex = 0
            for si in session.exercises[ei].sets.indices {
                guard !session.exercises[ei].sets[si].isWarmup else { continue }
                session.exercises[ei].sets[si].lastPerformance =
                    lookup.lastWorkingSet(movementId: mid, exerciseName: name, workingIndex: workingIndex)
                workingIndex += 1
            }
        }

        // Wire point 2: fetchWeight(userId:exerciseName:) returns WorkingWeight? with .weightKg:Double.
        // Use the normalized name (lowercased, spaces→"_") for the working-weight key.
        if let ex = session.currentExercise {
            let normalized = ex.name.lowercased().replacingOccurrences(of: " ", with: "_")
            if let ww = try? await services.workingWeight.fetchWeight(userId: uid, exerciseName: normalized) {
                workingWeightKg = ww.weightKg
            }
        }
        applySuggestedWeights()
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }
}

extension ActiveWorkoutContainerView {
    var editWeightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }
}
