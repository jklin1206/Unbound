import Foundation

struct AttributeContribution: Codable, Sendable, Equatable {
    let weights: [AttributeKey: Double]

    init(weights: [AttributeKey: Double]) {
        self.weights = weights
    }

    func weight(for key: AttributeKey) -> Double {
        weights[key] ?? 0.0
    }

    /// True if weights sum to 1.0 ± 0.01.
    var sumIsValid: Bool {
        abs(weights.values.reduce(0.0, +) - 1.0) <= 0.01
    }

    static let zero = AttributeContribution(weights: [:])
}
