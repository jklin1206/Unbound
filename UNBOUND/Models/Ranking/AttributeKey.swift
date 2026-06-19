import Foundation

enum AttributeKey: CaseIterable, Codable, RawRepresentable, Sendable {
    case power, vitality, control, endurance, mobility, explosiveness

    init?(rawValue: String) {
        switch rawValue {
        case "power": self = .power
        case "vitality", "agility": self = .vitality
        case "control": self = .control
        case "endurance": self = .endurance
        case "mobility": self = .mobility
        case "explosiveness": self = .explosiveness
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .power: return "power"
        case .vitality: return "vitality"
        case .control: return "control"
        case .endurance: return "endurance"
        case .mobility: return "mobility"
        case .explosiveness: return "explosiveness"
        }
    }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        guard let key = AttributeKey(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown attribute key: \(rawValue)"
                )
            )
        }
        self = key
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .power:         return L10n.attribute(id: rawValue, field: "displayName", defaultValue: "Power")
        case .vitality:      return L10n.attribute(id: rawValue, field: "displayName", defaultValue: "Vitality")
        case .control:       return L10n.attribute(id: rawValue, field: "displayName", defaultValue: "Control")
        case .endurance:     return L10n.attribute(id: rawValue, field: "displayName", defaultValue: "Endurance")
        case .mobility:      return L10n.attribute(id: rawValue, field: "displayName", defaultValue: "Mobility")
        case .explosiveness: return L10n.attribute(id: rawValue, field: "displayName", defaultValue: "Explosiveness")
        }
    }

    var shortCode: String {
        switch self {
        case .power:         return L10n.attribute(id: rawValue, field: "shortCode", defaultValue: "POW")
        case .vitality:      return L10n.attribute(id: rawValue, field: "shortCode", defaultValue: "VIT")
        case .control:       return L10n.attribute(id: rawValue, field: "shortCode", defaultValue: "CTL")
        case .endurance:     return L10n.attribute(id: rawValue, field: "shortCode", defaultValue: "END")
        case .mobility:      return L10n.attribute(id: rawValue, field: "shortCode", defaultValue: "MOB")
        case .explosiveness: return L10n.attribute(id: rawValue, field: "shortCode", defaultValue: "EXP")
        }
    }

    /// Used in the seed-survey copy ("POWER — heavy compounds, sub-6 reps").
    var trainsCopy: String {
        switch self {
        case .power:         return L10n.attribute(id: rawValue, field: "trainsCopy", defaultValue: "Heavy compounds, sub-6 reps")
        case .vitality:      return L10n.attribute(id: rawValue, field: "trainsCopy", defaultValue: "Easy walks, deloads, recovery")
        case .control:       return L10n.attribute(id: rawValue, field: "trainsCopy", defaultValue: "Skill nodes, tempo, isometrics")
        case .endurance:     return L10n.attribute(id: rawValue, field: "trainsCopy", defaultValue: "Z2 runs, density, long efforts")
        case .mobility:      return L10n.attribute(id: rawValue, field: "trainsCopy", defaultValue: "Range of motion, flexibility")
        case .explosiveness: return L10n.attribute(id: rawValue, field: "trainsCopy", defaultValue: "Jumps, plyos, dynamic effort")
        }
    }
}

// MARK: - BuildIdentity vocabulary

extension AttributeKey {
    /// Grounded athletic vocabulary used by `BuildIdentity.displayName`.
    /// Locked taxonomy — see spec.
    var buildVocab: String {
        switch self {
        case .power:         return L10n.attribute(id: rawValue, field: "buildVocab", defaultValue: "Power")
        case .vitality:      return L10n.attribute(id: rawValue, field: "buildVocab", defaultValue: "Vitality")
        case .control:       return L10n.attribute(id: rawValue, field: "buildVocab", defaultValue: "Control")
        case .endurance:     return L10n.attribute(id: rawValue, field: "buildVocab", defaultValue: "Endurance")
        case .mobility:      return L10n.attribute(id: rawValue, field: "buildVocab", defaultValue: "Mobility")
        case .explosiveness: return L10n.attribute(id: rawValue, field: "buildVocab", defaultValue: "Explosive")
        }
    }

    /// Suffix used by the `.lean` shape. Per-axis variation for natural English.
    var leanSuffix: String {
        switch self {
        case .power:         return L10n.attribute(id: rawValue, field: "leanSuffix", defaultValue: "-Oriented")
        case .vitality:      return L10n.attribute(id: rawValue, field: "leanSuffix", defaultValue: "-Focused")
        case .control:       return L10n.attribute(id: rawValue, field: "leanSuffix", defaultValue: "-Focused")
        case .endurance:     return L10n.attribute(id: rawValue, field: "leanSuffix", defaultValue: "-Dominant")
        case .mobility:      return L10n.attribute(id: rawValue, field: "leanSuffix", defaultValue: "-Focused")
        case .explosiveness: return L10n.attribute(id: rawValue, field: "leanSuffix", defaultValue: " Athlete")
        }
    }

    /// Source phrase for `BuildIdentity.tagline` composition.
    var taglinePhrase: String {
        switch self {
        case .power:         return L10n.attribute(id: rawValue, field: "taglinePhrase", defaultValue: "heavy output")
        case .vitality:      return L10n.attribute(id: rawValue, field: "taglinePhrase", defaultValue: "recovery consistency")
        case .control:       return L10n.attribute(id: rawValue, field: "taglinePhrase", defaultValue: "deliberate, controlled work")
        case .endurance:     return L10n.attribute(id: rawValue, field: "taglinePhrase", defaultValue: "long, sustained effort")
        case .mobility:      return L10n.attribute(id: rawValue, field: "taglinePhrase", defaultValue: "range-of-motion work")
        case .explosiveness: return L10n.attribute(id: rawValue, field: "taglinePhrase", defaultValue: "explosive, dynamic effort")
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
        case .vitality:      return []
        case .control:       return ["pullup", "dip", "plank"]
        case .endurance:     return ["leg press", "leg curl (lying)", "deadlift"]
        case .mobility:      return ["goblet squat", "romanian deadlift", "good morning"]
        case .explosiveness: return ["jump squat", "kettlebell swing", "muscle-up", "pendlay row"]
        }
    }
}
