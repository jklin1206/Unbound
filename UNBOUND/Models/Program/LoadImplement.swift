import Foundation

// MARK: - LoadImplement
//
// The physical implement a loaded movement is performed with. Weight math is
// implement-specific: dumbbells and kettlebells come in fixed sizes with a
// hard ceiling on what exists, machine stacks move in coarser pitches, and
// only barbells are effectively unbounded plate math. WeightPlatePolicy keys
// its snap grid, progression jump, and automatic-progression cap off this.

enum LoadImplement: String, Codable, Sendable {
    case barbell        // plate-loaded bars (incl. smith, sleds): open-ended
    case dumbbell       // fixed or adjustable dumbbells
    case kettlebell     // fixed bells on the 4 kg ladder
    case machine        // selectorized stacks and cables
    case bodyweightLoad // bodyweight stations loaded by a held plate/bell

    /// Resolve the implement for a progression exercise key. Unknown custom
    /// names get the conservative dumbbell treatment so automatic ramps stay
    /// bounded; a heavier load the user actually logs still tracks normally.
    static func resolve(exerciseKey: String) -> LoadImplement {
        guard let definition = MovementCatalog.canonicalExercise(named: exerciseKey) else {
            return .dumbbell
        }
        let equipment = Set(definition.equipment)
        if !equipment.isDisjoint(with: [.barbell, .smithMachine, .sled]) {
            return .barbell
        }
        if !equipment.isDisjoint(with: [.machine, .cable, .cardioMachine]) {
            return .machine
        }
        if equipment.contains(.dumbbell) {
            return .dumbbell
        }
        if equipment.contains(.kettlebell) {
            return .kettlebell
        }
        return .bodyweightLoad
    }

    /// Heaviest load (kg) automatic progression may prescribe, nil = unbounded.
    /// This caps engine-driven ramps only — user-logged heavier sets always win.
    var automaticCapKilograms: Double? {
        switch self {
        case .barbell: return nil
        case .dumbbell: return 50
        case .kettlebell: return 48
        case .machine: return 150
        case .bodyweightLoad: return 50
        }
    }
}
