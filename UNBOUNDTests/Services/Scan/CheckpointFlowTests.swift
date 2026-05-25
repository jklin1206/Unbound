import XCTest
@testable import UNBOUND

final class CheckpointFlowTests: XCTestCase {
    func testSkipFromEntryCommitsSkippedOutcome() {
        var flow = CheckpointFlow()

        flow.skip()

        XCTAssertEqual(flow.outcome, .skipped)
    }

    func testCompletePathMovesThroughReviewAndCommit() {
        var flow = CheckpointFlow()

        flow.begin()
        XCTAssertEqual(flow.step, .bodyCapture)
        flow.advance()
        XCTAssertEqual(flow.step, .standardsCheck)
        flow.setStandardsCheck(CheckpointStandardsCheck(attemptedCount: 4, clearedCount: 3))
        flow.advance()
        XCTAssertEqual(flow.step, .freeText)
        flow.setFreeText("Felt fresh but lats lagged.")
        flow.advance()
        XCTAssertEqual(flow.step, .nutritionCheck)
        flow.advance()
        XCTAssertEqual(flow.step, .summarizing)
        let signals = CheckpointSignals(recoveryStateHint: .wellRecovered, weakRegions: [.lats])
        flow.presentReview(signals: signals)
        flow.commitReviewedSignals()

        XCTAssertEqual(flow.outcome, .completed(signals))
    }

    func testCancelDiscardsPartialState() {
        var flow = CheckpointFlow()
        flow.begin()
        flow.setFreeText("Keep this out")
        flow.setStandardsCheck(CheckpointStandardsCheck(attemptedCount: 5, clearedCount: 5))

        flow.cancel()

        XCTAssertEqual(flow.step, .cancelled)
        XCTAssertEqual(flow.freeText, "")
        XCTAssertEqual(flow.standardsCheck, .none)
        XCTAssertNil(flow.nutrition)
    }

    func testGraceWindowExpiresToSkipped() {
        var flow = CheckpointFlow()
        let ended = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 25 * 3_600)

        flow.expireIfPastGraceWindow(arcEndedAt: ended, now: now, calendar: .fixedGMT)

        XCTAssertEqual(flow.outcome, .skipped)
    }
}
