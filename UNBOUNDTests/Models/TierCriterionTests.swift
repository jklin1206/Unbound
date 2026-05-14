import XCTest
@testable import UNBOUND

final class TierCriterionTests: XCTestCase {
    func testRepsRoundtrip() throws {
        let c: TierCriterion = .reps(8, exerciseName: "pull-up")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testSecondsRoundtrip() throws {
        let c: TierCriterion = .seconds(60)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testWeightKgRoundtrip() throws {
        let c: TierCriterion = .weightKg(120.0)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testBodyweightRatioRoundtrip() throws {
        let c: TierCriterion = .bodyweightRatio(1.5)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testVariantRoundtrip() throws {
        let c: TierCriterion = .variant("muscle-up")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testCompoundRoundtrip() throws {
        let c: TierCriterion = .compound([
            .reps(8, exerciseName: "pull-up"),
            .seconds(30)
        ])
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testEquatability() {
        XCTAssertEqual(TierCriterion.reps(8, exerciseName: "pull-up"),
                       TierCriterion.reps(8, exerciseName: "pull-up"))
        XCTAssertNotEqual(TierCriterion.reps(8, exerciseName: "pull-up"),
                          TierCriterion.reps(8, exerciseName: "chin-up"))
        XCTAssertNotEqual(TierCriterion.seconds(60), TierCriterion.seconds(61))
    }
}
