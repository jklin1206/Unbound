import XCTest
@testable import UNBOUND

final class TrainingFeedbackModeTests: XCTestCase {
    func testDefaultForNeverTrained() {
        XCTAssertEqual(TrainingFeedbackMode.default(for: .never), .silent)
    }
    func testDefaultForTriedOnce() {
        XCTAssertEqual(TrainingFeedbackMode.default(for: .tried), .silent)
    }
    func testDefaultForUsedToTrain() {
        XCTAssertEqual(TrainingFeedbackMode.default(for: .used), .quick)
    }
    func testDefaultForCurrentlyTraining() {
        XCTAssertEqual(TrainingFeedbackMode.default(for: .current), .quick)
    }
    func testTargetRPEValues() {
        XCTAssertEqual(TrainingFeedbackMode.silent.defaultTargetRPE, 0)
        XCTAssertEqual(TrainingFeedbackMode.quick.defaultTargetRPE, 7)
        XCTAssertEqual(TrainingFeedbackMode.detailed.defaultTargetRPE, 7)
    }
    func testAllCasesHaveDisplayName() {
        for mode in TrainingFeedbackMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertFalse(mode.description.isEmpty)
        }
    }
}
