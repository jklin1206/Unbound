import Foundation

// MARK: - Draft-level modifier pipeline

extension DailyWorkoutResolver {
    static func substitutedDraft(
        _ draft: TrainingSessionDraft,
        modifierContext: DailyWorkoutModifierContext
    ) -> TrainingSessionDraft {
        guard modifierContext.hasModifiers else { return draft }
        var updated = draft
        var usedNames: Set<String> = []
        updated.blocks = draft.blocks.map { block in
            guard shouldApplyWorkoutModifiers(to: block.kind) else { return block }
            var copy = block
            copy.prescriptions = block.prescriptions.map { prescription in
                let excluded = Set(block.prescriptions.flatMap(exclusionNames)).union(usedNames)
                let uniqueReplacement = replacement(
                    for: exercise(from: prescription),
                    modifierContext: modifierContext,
                    additionalExcludedNames: excluded
                )
                let fallbackReplacement = replacement(
                    for: exercise(from: prescription),
                    modifierContext: modifierContext,
                    additionalExcludedNames: []
                )
                guard let replacement = uniqueReplacement ?? fallbackReplacement else {
                    usedNames.formUnion(exclusionNames(for: exercise(from: prescription)))
                    return prescription
                }

                var adjusted = prescription
                adjusted.exerciseName = replacement.displayName
                adjusted.muscleGroups = replacement.muscleGroups
                adjusted.notes = appendNote("Adjusted for today's modifiers.", to: prescription.notes)
                usedNames.formUnion(exclusionNames(for: replacement))
                return adjusted
            }
            return copy
        }
        return updated
    }

    static func trialPrepDraft(
        _ draft: TrainingSessionDraft,
        modifierContext: DailyWorkoutModifierContext
    ) -> TrainingSessionDraft {
        guard !modifierContext.trialPrepMovementIds.isEmpty else { return draft }
        var updated = draft
        guard let targetBlockIndex = updated.blocks.firstIndex(where: { shouldApplyWorkoutModifiers(to: $0.kind) }) else {
            return draft
        }

        for movementId in modifierContext.trialPrepMovementIds {
            guard let definition = MovementCatalog.definition(for: movementId),
                  !containsMovement(definition, in: updated.blocks.flatMap(\.prescriptions)),
                  isCompatible(definition, modifierContext: modifierContext)
            else {
                continue
            }
            updated.blocks[targetBlockIndex].prescriptions.append(trialPrepPrescription(for: definition))
        }
        return updated
    }

    static func deloadedDraft(
        _ draft: TrainingSessionDraft,
        modifierContext: DailyWorkoutModifierContext
    ) -> TrainingSessionDraft {
        guard let rawFactor = modifierContext.deloadFactor else { return draft }
        let factor = min(1, max(0.25, rawFactor))
        var updated = draft
        updated.blocks = draft.blocks.map { block in
            guard shouldApplyWorkoutModifiers(to: block.kind) else { return block }
            var copy = block
            copy.prescriptions = block.prescriptions.map { prescription in
                var adjusted = prescription
                adjusted.sets = max(1, Int((Double(prescription.sets) * factor).rounded(.down)))
                adjusted.rpe = prescription.rpe.map { max(5, $0 - 1) }
                adjusted.notes = appendNote("Deload modifier applied.", to: prescription.notes)
                return adjusted
            }
            return copy
        }
        return updated
    }

    static func shortSessionDraft(
        _ draft: TrainingSessionDraft,
        modifierContext: DailyWorkoutModifierContext
    ) -> TrainingSessionDraft {
        guard modifierContext.shortSessionActive else { return draft }
        let editableCount = draft.blocks
            .filter { shouldApplyWorkoutModifiers(to: $0.kind) }
            .flatMap(\.prescriptions)
            .count
        guard editableCount > 3 else { return draft }

        var remaining = 3
        var updated = draft
        updated.blocks = draft.blocks.compactMap { block in
            guard shouldApplyWorkoutModifiers(to: block.kind) else { return block }
            guard remaining > 0 else { return nil }
            var copy = block
            copy.prescriptions = block.prescriptions.prefix(remaining).map { prescription in
                var adjusted = prescription
                adjusted.notes = appendNote("Short mode kept this exercise; lower-priority work was cut for today.", to: prescription.notes)
                return adjusted
            }
            remaining -= copy.prescriptions.count
            return copy.prescriptions.isEmpty ? nil : copy
        }
        updated.estimatedMinutes = min(draft.estimatedMinutes, 30)
        return updated
    }
}
