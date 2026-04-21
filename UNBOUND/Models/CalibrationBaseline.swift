import Foundation

struct CalibrationBaseline: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: String
    var exerciseKey: String
    var displayName: String
    var kind: Kind
    var value: Double
    var unit: String
    var isKnown: Bool
    var capturedAt: Date

    enum Kind: String, Codable, Sendable { case weight, reps }

    init(
        id: UUID = UUID(),
        userId: String,
        exerciseKey: String,
        displayName: String,
        kind: Kind,
        value: Double,
        unit: String,
        isKnown: Bool,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.exerciseKey = exerciseKey.trimmingCharacters(in: .whitespaces).lowercased()
        self.displayName = displayName
        self.kind = kind
        self.value = value
        self.unit = unit
        self.isKnown = isKnown
        self.capturedAt = capturedAt
    }

    /// Return working weight in kg regardless of the stored unit.
    var weightInKg: Double? {
        guard kind == .weight else { return nil }
        if unit.lowercased() == "lbs" { return value * 0.45359237 }
        return value
    }

    /// Maps the stored rep value to a calisthenic progression tier (0–3).
    var repTier: Int? {
        guard kind == .reps else { return nil }
        let reps = Int(value.rounded())
        switch reps {
        case ..<3:    return 0
        case 3...7:   return 1
        case 8...15:  return 2
        default:      return 3
        }
    }
}
