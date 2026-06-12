import Foundation

enum TrainingSessionEditPersistence: String, Codable, CaseIterable, Hashable, Sendable {
    case todayOnly
    case recurringSubstitution
    case equipmentPreference
    case nextBlockBias

    var displayName: String {
        switch self {
        case .todayOnly: return "Today only"
        case .recurringSubstitution: return "Repeat swap"
        case .equipmentPreference: return "Preference"
        case .nextBlockBias: return "Next block"
        }
    }

    var explanation: String {
        switch self {
        case .todayOnly:
            return "Starts this edited session without changing the base program."
        case .recurringSubstitution:
            return "Use the selected swap again when this movement appears."
        case .equipmentPreference:
            return "Treat the change as an equipment or availability preference."
        case .nextBlockBias:
            return "Keep the current block intact and bias the next block proposal."
        }
    }

    var isImplemented: Bool {
        switch self {
        case .todayOnly, .recurringSubstitution, .equipmentPreference, .nextBlockBias:
            return true
        }
    }
}

struct TrainingSessionSwapEdit: Equatable, Sendable {
    let originalExerciseName: String
    let replacementExerciseName: String
    let originalMovementId: String?
    let replacementMovementId: String?
    let muscleGroups: [MuscleGroup]
}

enum TrainingSessionEditPreferenceBuilder {
    static func swapEdits(
        original: TrainingSessionDraft,
        edited: TrainingSessionDraft
    ) -> [TrainingSessionSwapEdit] {
        let originalPrescriptions = flattenedPrescriptions(from: original)
        let editedPrescriptions = flattenedPrescriptions(from: edited)
        let sharedCount = min(originalPrescriptions.count, editedPrescriptions.count)

        return (0..<sharedCount).compactMap { index in
            let original = originalPrescriptions[index]
            let edited = editedPrescriptions[index]
            guard MovementCatalog.normalized(original.exerciseName) != MovementCatalog.normalized(edited.exerciseName) else {
                return nil
            }
            return TrainingSessionSwapEdit(
                originalExerciseName: original.exerciseName,
                replacementExerciseName: edited.exerciseName,
                originalMovementId: original.movementId,
                replacementMovementId: edited.movementId,
                muscleGroups: original.muscleGroups.isEmpty ? edited.muscleGroups : original.muscleGroups
            )
        }
    }

    static func preferences(
        for swaps: [TrainingSessionSwapEdit],
        mode: TrainingSessionEditPersistence,
        userId: String,
        updatedAt: Date = Date()
    ) -> [ExercisePreference] {
        switch mode {
        case .recurringSubstitution, .nextBlockBias:
            return uniqueSwaps(swaps).map { swap in
                let originalDefinition = definition(named: swap.originalExerciseName, movementId: swap.originalMovementId)
                let replacementDefinition = definition(named: swap.replacementExerciseName, movementId: swap.replacementMovementId)
                let originalKey = originalDefinition?.canonicalExerciseName
                    ?? MovementCatalog.normalized(swap.originalExerciseName)
                let replacementKey = replacementDefinition?.canonicalExerciseName
                    ?? MovementCatalog.normalized(swap.replacementExerciseName)

                return ExercisePreference(
                    id: "\(userId):\(originalKey)",
                    userId: userId,
                    exerciseName: originalKey,
                    displayName: originalDefinition?.displayName ?? swap.originalExerciseName,
                    status: .substitute,
                    muscleGroups: originalDefinition?.muscleGroups ?? swap.muscleGroups,
                    substitutePreference: replacementKey,
                    notes: mode == .nextBlockBias
                        ? "Queued from Session Editor for the next block proposal."
                        : "Set from Session Editor repeat swap.",
                    updatedAt: updatedAt
                )
            }

        case .equipmentPreference:
            return uniqueSwaps(swaps).map { swap in
                let replacementDefinition = definition(named: swap.replacementExerciseName, movementId: swap.replacementMovementId)
                let replacementKey = replacementDefinition?.canonicalExerciseName
                    ?? MovementCatalog.normalized(swap.replacementExerciseName)

                return ExercisePreference(
                    id: "\(userId):\(replacementKey)",
                    userId: userId,
                    exerciseName: replacementKey,
                    displayName: replacementDefinition?.displayName ?? swap.replacementExerciseName,
                    status: .available,
                    muscleGroups: replacementDefinition?.muscleGroups ?? swap.muscleGroups,
                    substitutePreference: nil,
                    notes: "Marked available from Session Editor.",
                    updatedAt: updatedAt
                )
            }

        case .todayOnly:
            return []
        }
    }

    private static func flattenedPrescriptions(from draft: TrainingSessionDraft) -> [TrainingBlockPrescription] {
        draft.blocks.flatMap(\.prescriptions)
    }

    private static func uniqueSwaps(_ swaps: [TrainingSessionSwapEdit]) -> [TrainingSessionSwapEdit] {
        var seen = Set<String>()
        return swaps.filter { swap in
            let key = [
                MovementCatalog.normalized(swap.originalExerciseName),
                MovementCatalog.normalized(swap.replacementExerciseName)
            ].joined(separator: "->")
            return seen.insert(key).inserted
        }
    }

    private static func definition(named name: String, movementId: String?) -> MovementDefinition? {
        if let movementId, let definition = MovementCatalog.definition(for: movementId) {
            return definition
        }
        return MovementCatalog.canonicalExercise(named: name)
    }
}

struct TrainingSessionEditSummary: Equatable, Sendable {
    let originalExerciseCount: Int
    let editedExerciseCount: Int
    let addedCount: Int
    let removedCount: Int
    let changedSlotCount: Int
    let reordered: Bool

    var isChanged: Bool {
        addedCount > 0 || removedCount > 0 || changedSlotCount > 0 || reordered
    }

    var headline: String {
        guard isChanged else { return "No edits yet" }

        let total = addedCount + removedCount + changedSlotCount + (reordered ? 1 : 0)
        return "\(total) edit\(total == 1 ? "" : "s") staged"
    }

    var details: [String] {
        var parts: [String] = []
        if addedCount > 0 { parts.append("+\(addedCount) added") }
        if removedCount > 0 { parts.append("-\(removedCount) removed") }
        if changedSlotCount > 0 { parts.append("\(changedSlotCount) swapped") }
        if reordered { parts.append("order changed") }
        return parts
    }

    static func compare(original: TrainingSessionDraft, edited: TrainingSessionDraft) -> TrainingSessionEditSummary {
        let originalNames = flattenedExerciseNames(from: original)
        let editedNames = flattenedExerciseNames(from: edited)

        let originalCounts = countsByName(originalNames)
        let editedCounts = countsByName(editedNames)
        let allNames = Set(originalCounts.keys).union(editedCounts.keys)

        let rawAdded = allNames.reduce(0) { total, name in
            total + max(0, (editedCounts[name] ?? 0) - (originalCounts[name] ?? 0))
        }
        let rawRemoved = allNames.reduce(0) { total, name in
            total + max(0, (originalCounts[name] ?? 0) - (editedCounts[name] ?? 0))
        }

        let sharedCount = min(originalNames.count, editedNames.count)
        let changedSlots = (0..<sharedCount).reduce(0) { total, index in
            originalNames[index] == editedNames[index] ? total : total + 1
        }

        let reordered = originalCounts == editedCounts && originalNames != editedNames
        let swapCount = reordered || originalNames.count != editedNames.count ? 0 : changedSlots

        return TrainingSessionEditSummary(
            originalExerciseCount: originalNames.count,
            editedExerciseCount: editedNames.count,
            addedCount: max(0, rawAdded - swapCount),
            removedCount: max(0, rawRemoved - swapCount),
            changedSlotCount: swapCount,
            reordered: reordered
        )
    }

    private static func flattenedExerciseNames(from draft: TrainingSessionDraft) -> [String] {
        draft.blocks.flatMap { block in
            block.prescriptions.map { prescription in
                MovementCatalog.normalized(prescription.exerciseName)
            }
        }
    }

    private static func countsByName(_ names: [String]) -> [String: Int] {
        names.reduce(into: [:]) { counts, name in
            counts[name, default: 0] += 1
        }
    }
}
