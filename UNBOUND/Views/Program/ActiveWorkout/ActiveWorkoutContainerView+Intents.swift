import SwiftUI

// MARK: - ActiveWorkoutContainerView intents
//
// Overflow-menu intent handling (warmup toggle / add-remove set / skip /
// notes / swap) plus the DEBUG fill-planned-sets helper.

extension ActiveWorkoutContainerView {
    #if DEBUG
    func debugFillPlannedSets() {
        session.objectWillChange.send()
        for exerciseIndex in session.exercises.indices where !session.exercises[exerciseIndex].skipped {
            for setIndex in session.exercises[exerciseIndex].sets.indices {
                guard !session.exercises[exerciseIndex].sets[setIndex].isWarmup else { continue }
                var set = session.exercises[exerciseIndex].sets[setIndex]
                switch session.exercises[exerciseIndex].metricKind {
                case .reps:
                    set.reps = set.suggestedReps ?? RepRange.lowerBound(session.exercises[exerciseIndex].plannedReps) ?? 8
                    set.weightKg = set.lastPerformance?.weightKg ?? set.suggestedWeightKg ?? debugWeightKg(exerciseIndex: exerciseIndex, setIndex: setIndex)
                case .holdSeconds:
                    set.holdSeconds = set.suggestedHoldSeconds ?? 30
                case .durationSeconds:
                    set.durationSeconds = set.suggestedDurationSeconds ?? 600
                case .distanceMeters:
                    set.distanceMeters = set.suggestedDistanceMeters ?? 400
                case .calories:
                    set.calories = set.suggestedCalories ?? 20
                }
                set.rpe = set.suggestedRPE ?? session.exercises[exerciseIndex].targetRPE ?? 8
                set.logged = true
                session.exercises[exerciseIndex].sets[setIndex] = set
            }
        }
        saveDraft()
        UnboundHaptics.success()
    }

    func debugWeightKg(exerciseIndex: Int, setIndex: Int) -> Double {
        let base = 45 + (exerciseIndex * 15) + (setIndex * 2)
        return Double(base)
    }
    #endif

    // MARK: - Intent handler

    func handleIntent(_ ei: Int, _ intent: OverflowIntent) {
        if isRankTrial {
            switch intent {
            case .toggleWarmup, .editNotes:
                break
            case .addSet, .removeSet, .skipExercise, .swapExercise:
                return
            }
        }

        switch intent {
        case .toggleWarmup:
            if session.exercises.indices.contains(ei),
               let s0 = session.exercises[ei].sets.indices.first {
                session.exercises[ei].sets[s0].isWarmup.toggle()
            }

        case .addSet:
            session.addSet(toExerciseIndex: ei)

        case .removeSet:
            session.removeLastSet(fromExerciseIndex: ei)

        case .skipExercise:
            if session.exercises.indices.contains(ei) {
                session.exercises[ei].skipped = true
            }

        case .editNotes:
            notesEditingIndex = ei
            notesEditingText = session.exercises.indices.contains(ei)
                ? session.exercises[ei].notes : ""
            showNotesSheet = true
            return // draft save happens in the sheet's onSave closure

        case .swapExercise:
            guard session.exercises.indices.contains(ei) else { return }
            swapAlternatives = MovementCatalog.catalogAlternatives(to: session.exercises[ei].name)
            swapExerciseIndex = ei
            return // draft save happens in swap onSelect closure
        }
        saveDraft()
    }
}
