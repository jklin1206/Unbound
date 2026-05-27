import XCTest
@testable import UNBOUND

final class AttributeContributionTests: XCTestCase {
    func testSumWithinToleranceReturnsTrueForValid() {
        let c = AttributeContribution(weights: [
            .power: 0.7, .endurance: 0.2, .control: 0.1
        ])
        XCTAssertTrue(c.sumIsValid)
    }

    func testSumWithinToleranceReturnsFalseWhenSumIsOff() {
        let c = AttributeContribution(weights: [.power: 0.5, .vitality: 0.2])
        XCTAssertFalse(c.sumIsValid)
    }

    func testNormalizedWeightsFillsMissingKeysWithZero() {
        let c = AttributeContribution(weights: [.power: 1.0])
        XCTAssertEqual(c.weight(for: .power), 1.0)
        XCTAssertEqual(c.weight(for: .mobility), 0.0)
    }

    func testCodableRoundTrips() throws {
        let original = AttributeContribution(weights: [.power: 0.6, .control: 0.4])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttributeContribution.self, from: data)
        XCTAssertEqual(decoded.weight(for: .power), 0.6, accuracy: 0.001)
        XCTAssertEqual(decoded.weight(for: .control), 0.4, accuracy: 0.001)
    }
}
