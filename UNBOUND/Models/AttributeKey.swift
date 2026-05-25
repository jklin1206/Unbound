import Foundation

enum AttributeKey: String, CaseIterable, Codable, Sendable {
    /// `agility` is kept as the raw value for storage/backward compatibility.
    /// Product-facing copy treats this axis as Vitality.
    case power, agility, control, endurance, mobility, explosiveness

    var displayName: String {
        switch self {
        case .power:         return "Power"
        case .agility:       return "Vitality"
        case .control:       return "Control"
        case .endurance:     return "Endurance"
        case .mobility:      return "Mobility"
        case .explosiveness: return "Explosiveness"
        }
    }

    var shortCode: String {
        switch self {
        case .power:         return "POW"
        case .agility:       return "VIT"
        case .control:       return "CTL"
        case .endurance:     return "END"
        case .mobility:      return "MOB"
        case .explosiveness: return "EXP"
        }
    }

    /// Used in the seed-survey copy ("POWER — heavy compounds, sub-6 reps").
    var trainsCopy: String {
        switch self {
        case .power:         return "Heavy compounds, sub-6 reps"
        case .agility:       return "Rest days, deloads, recovery"
        case .control:       return "Skill nodes, tempo, isometrics"
        case .endurance:     return "Z2 runs, density, long efforts"
        case .mobility:      return "Range of motion, flexibility"
        case .explosiveness: return "Jumps, plyos, dynamic effort"
        }
    }
}

// MARK: - BuildIdentity vocabulary

extension AttributeKey {
    /// Grounded athletic vocabulary used by `BuildIdentity.displayName`.
    /// Locked taxonomy — see spec.
    var buildVocab: String {
        switch self {
        case .power:         return "Power"
        case .agility:       return "Vitality"
        case .control:       return "Control"
        case .endurance:     return "Endurance"
        case .mobility:      return "Mobility"
        case .explosiveness: return "Explosive"
        }
    }

    /// Suffix used by the `.lean` shape. Per-axis variation for natural English.
    var leanSuffix: String {
        switch self {
        case .power:         return "-Oriented"
        case .agility:       return "-Focused"
        case .control:       return "-Focused"
        case .endurance:     return "-Dominant"
        case .mobility:      return "-Focused"
        case .explosiveness: return " Athlete"   // "Explosive" alone reads ambiguous
        }
    }

    /// Source phrase for `BuildIdentity.tagline` composition.
    var taglinePhrase: String {
        switch self {
        case .power:         return "heavy output"
        case .agility:       return "recovery consistency"
        case .control:       return "deliberate, controlled work"
        case .endurance:     return "long, sustained effort"
        case .mobility:      return "range-of-motion work"
        case .explosiveness: return "explosive, dynamic effort"
        }
    }

    /// Anchor lifts for aggregate-rank computation. IDs must match `CatalogExercise.name` —
    /// space-lowercase format used throughout production (WorkoutLog).
    ///
    /// NOTE: These were previously authored in snake_case (ExerciseLibrary format),
    /// which caused silent lookup misses. All IDs now match ExerciseCatalog exactly.
    var emphasisLifts: [String] {
        switch self {
        case .power:         return ["back squat", "deadlift", "bench press", "overhead press"]
        case .agility:       return []
        case .control:       return ["pullup", "dip", "plank"]
        case .endurance:     return ["leg press", "leg curl (lying)", "deadlift"]
        case .mobility:      return ["goblet squat", "romanian deadlift", "good morning"]
        case .explosiveness: return ["jump squat", "kettlebell swing", "muscle-up", "pendlay row"]
        }
    }
}
