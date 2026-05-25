import Foundation

struct NutritionTargetCalculator: Sendable {
    struct Configuration: Sendable {
        var minProteinGramsPerKilogram: Double = 1.6
        var maxProteinGramsPerKilogram: Double = 2.2
        var defaultProteinGramsPerKilogram: Double = 1.8
        var hydrationMillilitersPerKilogram: Double = 35
        var minPersonalizedHydrationLiters: Double = 1.8
        var maxPersonalizedHydrationLiters: Double = 4.5
    }

    struct Input: Sendable {
        var bodyweightKilograms: Double?
        var hardSessionLoggedWithin24Hours: Bool

        init(bodyweightKilograms: Double? = nil, hardSessionLoggedWithin24Hours: Bool = false) {
            self.bodyweightKilograms = bodyweightKilograms
            self.hardSessionLoggedWithin24Hours = hardSessionLoggedWithin24Hours
        }
    }

    var configuration: Configuration = Configuration()

    func calculate(input: Input) -> NutritionContext {
        guard let bodyweight = sanitizedBodyweight(input.bodyweightKilograms) else {
            return NutritionContext(
                bodyweightKilograms: nil,
                protein: .init(
                    minGrams: nil,
                    maxGrams: nil,
                    recommendedGrams: nil,
                    displayText: "Aim for 0.7-1.0g protein per lb bodyweight. Add bodyweight in Settings for a personalized target."
                ),
                hydration: .init(
                    liters: nil,
                    displayText: "Keep hydration steady through the day. Add bodyweight in Settings for a personalized target."
                ),
                trainingFuel: input.hardSessionLoggedWithin24Hours ? .hardSession : nil,
                usesGenericFallback: true
            )
        }

        let minProtein = roundedGrams(bodyweight * configuration.minProteinGramsPerKilogram)
        let maxProtein = roundedGrams(bodyweight * configuration.maxProteinGramsPerKilogram)
        let recommendedProtein = roundedGrams(bodyweight * configuration.defaultProteinGramsPerKilogram)
        let hydration = clampedHydrationLiters(
            bodyweight * configuration.hydrationMillilitersPerKilogram / 1_000
        )

        return NutritionContext(
            bodyweightKilograms: bodyweight,
            protein: .init(
                minGrams: minProtein,
                maxGrams: maxProtein,
                recommendedGrams: recommendedProtein,
                displayText: "\(minProtein)-\(maxProtein)g protein"
            ),
            hydration: .init(
                liters: hydration,
                displayText: "\(String(format: "%.1f", hydration))L hydration"
            ),
            trainingFuel: input.hardSessionLoggedWithin24Hours ? .hardSession : nil,
            usesGenericFallback: false
        )
    }

    private func sanitizedBodyweight(_ bodyweight: Double?) -> Double? {
        guard let bodyweight, bodyweight.isFinite, bodyweight >= 30, bodyweight <= 300 else {
            return nil
        }
        return bodyweight
    }

    private func roundedGrams(_ value: Double) -> Int {
        Int((value / 5).rounded() * 5)
    }

    private func clampedHydrationLiters(_ value: Double) -> Double {
        let clamped = min(
            max(value, configuration.minPersonalizedHydrationLiters),
            configuration.maxPersonalizedHydrationLiters
        )
        return (clamped * 10).rounded() / 10
    }
}
