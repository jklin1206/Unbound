import Foundation

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

    private static func isAvoided(_ definition: MovementDefinition, by avoidedMovementIds: Set<String>) -> Bool {
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

    static func isCompatible(
        _ definition: MovementDefinition,
        modifierContext: DailyWorkoutModifierContext
    ) -> Bool {
        guard let equipment = modifierContext.availableEquipment else { return true }
        let style = inferredStyle(for: equipment)
        return MovementCatalog.isProgramCompatible(definition, style: style, userEquipment: equipment)
    }

    private static func inferredStyle(for equipment: [Equipment]) -> TrainingStyle {
        let bodyweightGear: Set<Equipment> = [.bodyweight, .pullupBar, .bands, .dipStation, .rings]
        if !equipment.isEmpty && Set(equipment).isSubset(of: bodyweightGear) {
            return .bodyweight
        }
        return .hybrid
    }

    static func appendNote(_ note: String, to existing: String?) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return note
        }
        if existing.contains(note) { return existing }
        return "\(existing) \(note)"
    }
}
