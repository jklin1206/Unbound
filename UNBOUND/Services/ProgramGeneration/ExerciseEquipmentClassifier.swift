// UNBOUND/Services/ProgramGeneration/ExerciseEquipmentClassifier.swift
import Foundation

/// Compatibility facade for older program-generation tests and helpers.
/// Known movements read their equipment requirements from MovementCatalog;
/// unknown custom names fall back to the broad dumbbell/accessory bucket.
enum ExerciseEquipmentCategory: String {
    case barbell       // needs a barbell (+ rack for squat/bench)
    case dumbbell      // needs dumbbells (or light accessory equivalents)
    case machine       // needs cables / selectorized machines (gym)
    case bodyweight    // only body + optional pullup bar / dip station
}

enum ExerciseEquipmentClassifier {

    /// Infer the coarse equipment category for display/back-compat callers.
    static func classify(_ exerciseName: String) -> ExerciseEquipmentCategory {
        guard let definition = MovementCatalog.canonicalExercise(named: exerciseName) else {
            return .dumbbell
        }
        return classify(definition)
    }

    /// True if the exercise is compatible with the user's training style and
    /// equipment chips. Catalog movements delegate to MovementCatalog's
    /// structured equipment requirements; unknown custom names retain the old
    /// permissive dumbbell/accessory fallback.
    static func isCompatible(
        exerciseName: String,
        style: TrainingStyle,
        userEquipment: [Equipment]
    ) -> Bool {
        guard let definition = MovementCatalog.canonicalExercise(named: exerciseName) else {
            return fallbackCompatibility(style: style, userEquipment: userEquipment)
        }
        return MovementCatalog.isProgramCompatible(
            definition,
            style: style,
            userEquipment: userEquipment
        )
    }

    private static func classify(_ definition: MovementDefinition) -> ExerciseEquipmentCategory {
        let equipment = Set(definition.equipment)
        if !equipment.isDisjoint(with: [.machine, .cable, .smithMachine, .cardioMachine]) {
            return .machine
        }
        if equipment.contains(.barbell) {
            return .barbell
        }
        if !equipment.isDisjoint(with: [.dumbbell, .kettlebell, .bench]) {
            return .dumbbell
        }
        return .bodyweight
    }

    private static func fallbackCompatibility(
        style: TrainingStyle,
        userEquipment: [Equipment]
    ) -> Bool {
        if style == .bodyweight {
            return false
        }
        if userEquipment.contains(.fullGym) {
            return true
        }
        return userEquipment.contains(.dumbbells)
            || userEquipment.contains(.bench)
            || userEquipment.contains(.homeWeights)
            || userEquipment.contains(.bands)
    }
}
