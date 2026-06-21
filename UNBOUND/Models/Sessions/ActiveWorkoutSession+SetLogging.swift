import Foundation
import Combine

extension ActiveWorkoutSession {
    private func advanceAfterLogging(exerciseIndex ei: Int, setIndex si: Int) {
        guard currentExerciseIndex == ei, currentSetIndex == si else { return }

        if let nextSet = exercises[ei].sets.indices.first(where: { $0 > si && !exercises[ei].sets[$0].logged }) {
            currentSetIndex = nextSet
            return
        }

        markExerciseCompletedIfReady(exerciseIndex: ei)

        if let nextExercise = exercises.indices.first(where: { idx in
            idx > ei && !exercises[idx].skipped && exercises[idx].sets.contains(where: { !$0.logged })
        }) {
            currentExerciseIndex = nextExercise
            currentSetIndex = exercises[nextExercise].sets.firstIndex(where: { !$0.logged }) ?? 0
            markCurrentExerciseStarted()
        }
    }

    // MARK: Index-addressed mutators (grid logs any set in any order)

    func logSet(exerciseIndex ei: Int, setIndex si: Int, weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        markExerciseStarted(exerciseIndex: ei)
        exercises[ei].sets[si].weightKg = weightKg
        exercises[ei].sets[si].reps = reps
        exercises[ei].sets[si].logged = true
        markExerciseCompletedIfReady(exerciseIndex: ei)
    }

    func setRPE(exerciseIndex ei: Int, setIndex si: Int, _ rpe: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        exercises[ei].sets[si].rpe = rpe
    }

    func toggleQualityFlag(_ flag: PerformanceQualityFlag, exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        if exercises[ei].sets[si].qualityFlags.contains(flag) {
            exercises[ei].sets[si].qualityFlags.remove(flag)
        } else {
            exercises[ei].sets[si].qualityFlags.insert(flag)
            exercises[ei].sets[si].qualityFlags.remove(.clean)
        }
    }

    /// One-tap confirmation: preserve any values the user entered, fill only
    /// missing fields from the plan, then mark the set logged.
    func confirmAsPlanned(exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si),
              !exercises[ei].sets[si].logged else { return }
        objectWillChange.send()
        markExerciseStarted(exerciseIndex: ei)
        if exercises[ei].sets[si].weightKg == nil {
            // Last-performance drives the weight prefill (spec Option A); suggested is the fallback.
            exercises[ei].sets[si].weightKg = exercises[ei].sets[si].lastPerformance?.weightKg
                ?? exercises[ei].sets[si].suggestedWeightKg
        }
        if exercises[ei].sets[si].reps == nil {
            exercises[ei].sets[si].reps = exercises[ei].sets[si].suggestedReps
        }
        if exercises[ei].sets[si].holdSeconds == nil {
            exercises[ei].sets[si].holdSeconds = exercises[ei].sets[si].suggestedHoldSeconds
        }
        if exercises[ei].sets[si].durationSeconds == nil {
            exercises[ei].sets[si].durationSeconds = exercises[ei].sets[si].suggestedDurationSeconds
        }
        if exercises[ei].sets[si].distanceMeters == nil {
            exercises[ei].sets[si].distanceMeters = exercises[ei].sets[si].suggestedDistanceMeters
        }
        if exercises[ei].sets[si].calories == nil {
            exercises[ei].sets[si].calories = exercises[ei].sets[si].suggestedCalories
        }
        if exercises[ei].sets[si].rpe == nil {
            exercises[ei].sets[si].rpe = exercises[ei].sets[si].suggestedRPE
        }
        exercises[ei].sets[si].logged = true
        markExerciseCompletedIfReady(exerciseIndex: ei)
        advanceAfterLogging(exerciseIndex: ei, setIndex: si)
    }

    /// Implicit logging follows the set's required fields. Returns true only
    /// on the false→true edge so the caller can fire haptic/rest once.
    @discardableResult
    func recomputeLogged(exerciseIndex ei: Int, setIndex si: Int) -> Bool {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return false }
        let was = exercises[ei].sets[si].logged
        let complete = exercises[ei].sets[si].hasRequiredLogFields(exercises[ei].metricKind)
        if complete {
            objectWillChange.send()
            markExerciseStarted(exerciseIndex: ei)
            if exercises[ei].sets[si].rpe == nil {
                exercises[ei].sets[si].rpe = exercises[ei].sets[si].suggestedRPE
            }
            exercises[ei].sets[si].logged = true
            markExerciseCompletedIfReady(exerciseIndex: ei)
            if !was {
                advanceAfterLogging(exerciseIndex: ei, setIndex: si)
            }
        } else if was {
            objectWillChange.send()
            exercises[ei].sets[si].logged = false
            exercises[ei].completedAt = nil
        }
        return complete && !was
    }

    func addSet(toExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei) else { return }
        let exercise = exercises[ei]
        objectWillChange.send()
        exercises[ei].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      rpe: nil, isWarmup: false, logged: false,
                      suggestedReps: exercise.metricKind == .reps ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedHoldSeconds: exercise.metricKind == .holdSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDurationSeconds: exercise.metricKind == .durationSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDistanceMeters: exercise.metricKind == .distanceMeters ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedCalories: exercise.metricKind == .calories ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedRPE: exercise.targetRPE,
                      suggestedRestSeconds: exercise.restSeconds))
    }

    func removeLastSet(fromExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.count > 1 else { return }
        objectWillChange.send()
        exercises[ei].sets.removeLast()
    }
}

private extension ActiveWorkoutSession.ActiveSet {
    func hasRequiredLogFields(_ metricKind: TrainingMetricKind) -> Bool {
        switch metricKind {
        case .reps:
            guard reps != nil else { return false }
            return suggestedWeightKg == nil || weightKg != nil
        case .holdSeconds: return holdSeconds != nil
        case .durationSeconds: return durationSeconds != nil
        case .distanceMeters: return distanceMeters != nil
        case .calories: return calories != nil
        }
    }
}
