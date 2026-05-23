import Foundation

struct WorkingWeight: Codable, Identifiable {
    var id: String
    let userId: String
    var exerciseName: String
    var weightKg: Double
    var lastReps: Int
    var lastRPE: Int?
    var updatedAt: Date
    var sourceLogId: String
    var consecutiveSessionsAtTarget: Int
}

enum ProgressionSuggestion {
    case increaseWeight(amount: Double)
    case increaseReps
    case hold
    case deload(percentage: Double)

    var description: String {
        switch self {
        case .increaseWeight(let amount):
            let unit = WeightPlatePolicy.currentUnit
            return "Try +\(WeightPlatePolicy.formatDeltaWeight(amount, unit: unit))\(unit.shortLabel)"
        case .increaseReps: return "Add 1-2 reps before increasing weight"
        case .hold: return "Hold current weight"
        case .deload(let pct): return "Deload \(Int(pct))% — RPE too high"
        }
    }
}
