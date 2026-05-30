import Foundation

enum ProofFamily: Hashable, Sendable, Codable {
    case reps
    case hold
    case mobility
    case form
    case eccentric
    case loaded
    case unilateral
    case tempo
    case other(String)

    var rawValue: String {
        switch self {
        case .reps: return "reps"
        case .hold: return "hold"
        case .mobility: return "mobility"
        case .form: return "form"
        case .eccentric: return "eccentric"
        case .loaded: return "loaded"
        case .unilateral: return "unilateral"
        case .tempo: return "tempo"
        case .other(let value): return value
        }
    }

    init(rawValue: String) {
        switch rawValue {
        case "reps": self = .reps
        case "hold": self = .hold
        case "mobility": self = .mobility
        case "form": self = .form
        case "eccentric": self = .eccentric
        case "loaded": self = .loaded
        case "unilateral": self = .unilateral
        case "tempo": self = .tempo
        default: self = .other(rawValue)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var allowsHigherProofAutoClear: Bool {
        switch self {
        case .reps, .loaded, .eccentric:
            return true
        case .hold, .mobility, .form, .tempo, .unilateral, .other:
            return false
        }
    }
}

extension ProofFamily {
    static func inferred(from criterion: TierCriterion?) -> ProofFamily {
        guard let criterion else { return .form }
        switch criterion {
        case .reps(_, let exerciseName):
            return inferred(fromExerciseName: exerciseName, defaultFamily: .reps)
        case .seconds, .exerciseSeconds:
            return .hold
        case .weightKg, .exerciseWeightKg, .bodyweightRatio, .exerciseBodyweightRatio:
            return .loaded
        case .variant(let name):
            return inferred(fromExerciseName: name, defaultFamily: .form)
        case .compound(let criteria):
            if criteria.contains(where: { inferred(from: $0) == .hold }) {
                return .hold
            }
            if criteria.contains(where: { inferred(from: $0) == .mobility }) {
                return .mobility
            }
            if criteria.contains(where: { inferred(from: $0) == .form }) {
                return .form
            }
            if let first = criteria.first {
                return inferred(from: first)
            }
            return .form
        }
    }

    static func inferred(from requirement: NodeRequirement) -> ProofFamily {
        switch requirement {
        case .weightMultiplier:
            return .loaded
        case .reps(let exercise, _, _):
            return inferred(fromExerciseName: exercise, defaultFamily: .reps)
        case .hold:
            return .hold
        case .steps:
            return .unilateral
        case .carry:
            return .loaded
        case .composite(let requirements):
            if requirements.contains(where: { inferred(from: $0) == .hold }) {
                return .hold
            }
            if requirements.contains(where: { inferred(from: $0) == .mobility }) {
                return .mobility
            }
            return requirements.first.map(inferred(from:)) ?? .form
        }
    }

    static func inferred(fromExerciseName name: String, defaultFamily: ProofFamily) -> ProofFamily {
        let normalized = MovementCatalog.normalized(name)
        if normalized.contains("mobility") || normalized.contains("stretch") || normalized.contains("dislocate") {
            return .mobility
        }
        if normalized.contains("hold")
            || normalized.contains("hang")
            || normalized.contains("plank")
            || normalized.contains("lever")
            || normalized.contains("l sit")
            || normalized.contains("handstand") {
            return .hold
        }
        if normalized.contains("negative") || normalized.contains("eccentric") {
            return .eccentric
        }
        if normalized.contains("slow") || normalized.contains("tempo") {
            return .tempo
        }
        if normalized.contains("weighted") || normalized.contains("farmer carry") {
            return .loaded
        }
        return defaultFamily
    }
}
