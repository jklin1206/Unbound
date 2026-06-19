import XCTest
@testable import UNBOUND

final class ExerciseRefreshRuleTests: XCTestCase {

    // MARK: shouldRotate

    func testDoesNotRotateBelowThreeConsecutive() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 0,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 2,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
    }

    func testRotatesAtThreeConsecutive() {
        XCTAssertTrue(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 3,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
    }

    func testRotatesBeyondThree() {
        XCTAssertTrue(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 7,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
    }

    func testTierUnlockPreventsRotation() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "pullup",
            consecutiveBlocksPrescribed: 5,
            hadTierUnlock: true,
            hadPlateauDeload: false
        )))
    }

    func testPlateauDeloadPreventsRotation() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 5,
            hadTierUnlock: false,
            hadPlateauDeload: true
        )))
    }

    func testBothSignalsPreventRotation() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 10,
            hadTierUnlock: true,
            hadPlateauDeload: true
        )))
    }

}
