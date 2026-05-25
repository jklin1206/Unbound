import Foundation

struct NutritionContext: Codable, Equatable, Sendable {
    struct ProteinTarget: Codable, Equatable, Sendable {
        var minGrams: Int?
        var maxGrams: Int?
        var recommendedGrams: Int?
        var displayText: String
    }

    struct HydrationTarget: Codable, Equatable, Sendable {
        var liters: Double?
        var displayText: String
    }

    enum TrainingFuelGuidance: String, Codable, Sendable {
        case optional
        case hardSession

        var displayText: String {
            switch self {
            case .optional:
                return "Fuel is optional here. Keep protein and hydration steady."
            case .hardSession:
                return "Hard session logged recently. A carb source before or after training may help performance."
            }
        }
    }

    var bodyweightKilograms: Double?
    var protein: ProteinTarget
    var hydration: HydrationTarget
    var trainingFuel: TrainingFuelGuidance?
    var usesGenericFallback: Bool
}
