import Foundation

enum TrainingPrescriptionResolver {
    static func resolve(
        draft: TrainingSessionDraft,
        progressionStates: [String: ProgressionState]
    ) -> TrainingSessionDraft {
        guard !progressionStates.isEmpty else { return draft }
        var resolved = draft
        resolved.blocks = draft.blocks.map { block in
            guard block.kind != .routine else { return block }
            var updated = block
            updated.prescriptions = block.prescriptions.map {
                resolve(prescription: $0, progressionStates: progressionStates)
            }
            return updated
        }
        return resolved
    }

    private static func resolve(
        prescription: TrainingBlockPrescription,
        progressionStates: [String: ProgressionState]
    ) -> TrainingBlockPrescription {
        guard let state = state(for: prescription, progressionStates: progressionStates) else {
            return prescription
        }

        var updated = prescription
        if state.currentWorkingWeightKg > 0, updated.suggestedWeightKg == nil {
            updated.suggestedWeightKg = suggestedWeight(for: state)
        }
        // RPE-free: the engine no longer prescribes or displays RPE, so we do not
        // re-add a stored targetRPE here (it would leak RPE back onto the card).
        if state.targetRepMin > 0, state.targetRepMax >= state.targetRepMin {
            updated.target = resolvedTarget(current: updated.target, state: state)
        }
        updated = applyBias(to: updated, state: state)
        return updated
    }

    private static func resolvedTarget(
        current: TrainingTarget,
        state: ProgressionState
    ) -> TrainingTarget {
        switch current {
        case .reps, .repsRange, .amrap:
            return .repsRange(state.targetRepMin, state.targetRepMax)
        case .holdSeconds, .distanceMeters, .calories, .timedSeconds:
            return current
        }
    }

    private static func applyBias(
        to prescription: TrainingBlockPrescription,
        state: ProgressionState
    ) -> TrainingBlockPrescription {
        var updated = prescription
        let isPrimary = isPrimaryPrescription(prescription)

        switch state.prescriptionBias {
        case .easier:
            updated.restSeconds = min(240, updated.restSeconds + (isPrimary ? 30 : 15))
            if let weight = updated.suggestedWeightKg, weight > 0 {
                updated.suggestedWeightKg = WeightPlatePolicy.snappedSuggestionKilograms(max(0, weight * 0.95))
            }
            updated.notes = appendNote("Progression adjusted: easier target after recent grind.", to: updated.notes)
        case .harder:
            updated.restSeconds = min(240, updated.restSeconds + (isPrimary ? 15 : 0))
            updated.notes = appendNote("Progression adjusted: harder option unlocked; keep every rep strict.", to: updated.notes)
        case .hold:
            if state.consecutiveSessionsAtTarget == 1 {
                updated.notes = appendNote(
                    "Progression hold: repeat one more clean top-range session before adding difficulty.",
                    to: updated.notes
                )
            }
        case .none:
            break
        }

        return updated
    }

    private static func state(
        for prescription: TrainingBlockPrescription,
        progressionStates: [String: ProgressionState]
    ) -> ProgressionState? {
        var keys: [String] = [
            prescription.exerciseName,
            prescription.movementId,
            prescription.rankStandardMovementId
        ].compactMap { $0 }

        if let movementId = prescription.movementId,
           let definition = MovementCatalog.definition(for: movementId) {
            keys.append(definition.displayName)
            if let canonical = definition.canonicalExerciseName {
                keys.append(canonical)
            }
            keys.append(definition.rankStandardMovementId)
        }

        if let rankId = prescription.rankStandardMovementId,
           let definition = MovementCatalog.definition(for: rankId) {
            keys.append(definition.displayName)
            if let canonical = definition.canonicalExerciseName {
                keys.append(canonical)
            }
        }

        for key in keys.map(MovementCatalog.normalized) {
            if let state = progressionStates[key] {
                return state
            }
        }
        return nil
    }

    private static func suggestedWeight(for state: ProgressionState) -> Double? {
        guard state.currentWorkingWeightKg > 0 else { return nil }
        return WeightPlatePolicy.snappedSuggestionKilograms(state.currentWorkingWeightKg)
    }

    private static func isPrimaryPrescription(_ prescription: TrainingBlockPrescription) -> Bool {
        guard let definition = prescription.movementId.flatMap(MovementCatalog.definition(for:))
            ?? MovementCatalog.canonicalExercise(named: prescription.exerciseName)
        else {
            return false
        }

        switch definition.movementSlot {
        case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
            return true
        case .arms, .core, .calves, .carry, .cardio, .mobility, .routine, .skill:
            return false
        }
    }

    private static func appendNote(_ note: String, to existing: String?) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return note
        }
        if existing.localizedCaseInsensitiveContains(note) { return existing }
        return "\(existing) \(note)"
    }
}
