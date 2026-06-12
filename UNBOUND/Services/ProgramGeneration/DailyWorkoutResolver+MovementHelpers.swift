import Foundation

// MARK: - Movement lookup and substitution helpers

extension DailyWorkoutResolver {
    static func replacement(
        for exercise: Exercise,
        modifierContext: DailyWorkoutModifierContext,
        additionalExcludedNames: Set<String>
    ) -> CatalogExercise? {
        guard let current = MovementCatalog.canonicalExercise(named: exercise.name) else { return nil }
        let equipment = modifierContext.availableEquipment ?? [.fullGym]
        let style = inferredStyle(for: equipment)
        let excluded = Set(
            [current.displayName, current.canonicalExerciseName ?? exercise.name]
                + modifierContext.avoidedMovementIds.map { $0 }
                + Array(additionalExcludedNames)
        )
        let unavailable = modifierContext.availableEquipment.map {
            !MovementCatalog.isProgramCompatible(current, style: style, userEquipment: $0)
        } ?? false
        let avoided = isAvoided(current, by: modifierContext.avoidedMovementIds)
        guard unavailable || avoided else { return nil }

        return MovementCatalog.catalogDefaultSubstitute(
            for: exercise.name,
            style: style,
            userEquipment: equipment,
            excludedNames: excluded
        )
    }

    static func exclusionNames(for exercise: Exercise) -> [String] {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return [
                definition.id,
                definition.displayName,
                definition.canonicalExerciseName ?? exercise.name,
                definition.rankStandardMovementId
            ].map(MovementCatalog.normalized)
        }
        return [MovementCatalog.normalized(exercise.name)]
    }

    static func exclusionNames(for prescription: TrainingBlockPrescription) -> [String] {
        if let movementId = prescription.movementId,
           let definition = MovementCatalog.definition(for: movementId) {
            return [
                definition.id,
                definition.displayName,
                definition.canonicalExerciseName ?? prescription.exerciseName,
                definition.rankStandardMovementId
            ].map(MovementCatalog.normalized)
        }
        return [MovementCatalog.normalized(prescription.exerciseName)]
    }

    static func exclusionNames(for exercise: CatalogExercise) -> [String] {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return [
                definition.id,
                definition.displayName,
                definition.canonicalExerciseName ?? exercise.name,
                definition.rankStandardMovementId
            ].map(MovementCatalog.normalized)
        }
        return [
            MovementCatalog.normalized(exercise.name),
            MovementCatalog.normalized(exercise.displayName)
        ]
    }

    static func isAvoided(_ definition: MovementDefinition, by avoidedMovementIds: Set<String>) -> Bool {
        guard !avoidedMovementIds.isEmpty else { return false }
        let avoided = Set(avoidedMovementIds.map(MovementCatalog.normalized))
        let candidates = [
            definition.id,
            definition.rankStandardMovementId,
            definition.displayName,
            definition.canonicalExerciseName ?? ""
        ].map(MovementCatalog.normalized)
        return candidates.contains { avoided.contains($0) }
    }

    static func containsMovement(_ definition: MovementDefinition, in exercises: [Exercise]) -> Bool {
        exercises.contains { exercise in
            guard let existing = MovementCatalog.canonicalExercise(named: exercise.name) else {
                return MovementCatalog.normalized(exercise.name) == MovementCatalog.normalized(definition.displayName)
            }
            return existing.id == definition.id
                || existing.rankStandardMovementId == definition.rankStandardMovementId
        }
    }

    static func containsMovement(
        _ definition: MovementDefinition,
        in prescriptions: [TrainingBlockPrescription]
    ) -> Bool {
        prescriptions.contains { prescription in
            if prescription.movementId == definition.id
                || prescription.rankStandardMovementId == definition.rankStandardMovementId {
                return true
            }
            guard let existing = MovementCatalog.canonicalExercise(named: prescription.exerciseName) else {
                return MovementCatalog.normalized(prescription.exerciseName) == MovementCatalog.normalized(definition.displayName)
            }
            return existing.id == definition.id
                || existing.rankStandardMovementId == definition.rankStandardMovementId
        }
    }

    static func isCompatible(
        _ definition: MovementDefinition,
        modifierContext: DailyWorkoutModifierContext
    ) -> Bool {
        guard let equipment = modifierContext.availableEquipment else { return true }
        let style = inferredStyle(for: equipment)
        return MovementCatalog.isProgramCompatible(definition, style: style, userEquipment: equipment)
    }

    static func inferredStyle(for equipment: [Equipment]) -> TrainingStyle {
        let bodyweightGear: Set<Equipment> = [.bodyweight, .pullupBar, .bands, .dipStation, .rings]
        if !equipment.isEmpty && Set(equipment).isSubset(of: bodyweightGear) {
            return .bodyweight
        }
        return .hybrid
    }

    // MARK: - Trial prep builders

    static func trialPrepExercise(for definition: MovementDefinition) -> Exercise {
        Exercise(
            id: "trial-prep-\(definition.id)",
            name: definition.canonicalExerciseName ?? definition.displayName,
            muscleGroups: definition.muscleGroups,
            sets: 2,
            reps: trialPrepTarget(for: definition.defaultMetric),
            restSeconds: 90,
            rpe: 7,
            notes: "Trial prep modifier.",
            substitution: nil
        )
    }

    static func trialPrepPrescription(for definition: MovementDefinition) -> TrainingBlockPrescription {
        TrainingBlockPrescription(
            exerciseName: definition.canonicalExerciseName ?? definition.displayName,
            movementId: definition.id,
            rankStandardMovementId: definition.rankStandardMovementId,
            sets: 2,
            target: trialPrepTrainingTarget(for: definition.defaultMetric),
            restSeconds: 90,
            muscleGroups: definition.muscleGroups,
            rpe: 7,
            notes: "Trial prep modifier."
        )
    }

    static func exercise(from prescription: TrainingBlockPrescription) -> Exercise {
        Exercise(
            id: prescription.id,
            name: prescription.exerciseName,
            muscleGroups: prescription.muscleGroups,
            sets: prescription.sets,
            reps: prescription.target.displayText,
            restSeconds: prescription.restSeconds,
            rpe: prescription.rpe,
            notes: prescription.notes,
            substitution: nil
        )
    }

    static func trialPrepTarget(for metric: TrainingMetricKind) -> String {
        switch metric {
        case .reps: return "8"
        case .holdSeconds: return "30s"
        case .durationSeconds: return "300s"
        case .distanceMeters: return "400m"
        case .calories: return "30 cal"
        }
    }

    static func trialPrepTrainingTarget(for metric: TrainingMetricKind) -> TrainingTarget {
        switch metric {
        case .reps: return .reps(8)
        case .holdSeconds: return .holdSeconds(30)
        case .durationSeconds: return .timedSeconds(300)
        case .distanceMeters: return .distanceMeters(400)
        case .calories: return .calories(30)
        }
    }

    // MARK: - Utilities

    static func appendSkillModifierNote(to existing: String?) -> String {
        appendNote("Volume tapered for scheduled skill work.", to: existing)
    }

    static func appendNote(_ note: String, to existing: String?) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return note
        }
        if existing.contains(note) { return existing }
        return "\(existing) \(note)"
    }

    static func estimatedMinutes(for blocks: [TrainingBlock], fallback: Int) -> Int {
        guard !blocks.isEmpty else { return fallback }
        let minutes = blocks.reduce(0) { total, block in
            let blockSeconds = block.prescriptions.reduce(0) { subtotal, prescription in
                let workSeconds: Int
                switch prescription.target {
                case .holdSeconds(let seconds), .timedSeconds(let seconds):
                    workSeconds = seconds
                default:
                    workSeconds = 45
                }
                return subtotal + ((workSeconds + prescription.restSeconds) * max(1, prescription.sets))
            }
            return total + max(5, Int(ceil(Double(blockSeconds) / 60.0)))
        }
        return max(fallback, minutes)
    }
}
