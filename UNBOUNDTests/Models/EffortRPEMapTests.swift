import XCTest
@testable import UNBOUND

final class EffortRPEMapTests: XCTestCase {
    func test_rpeValues() {
        XCTAssertEqual(Effort.easy.rpe, 6)
        XCTAssertEqual(Effort.solid.rpe, 8)
        XCTAssertEqual(Effort.hard.rpe, 9)
    }
    func test_fromRPE_bucketsCorrectly() {
        XCTAssertEqual(Effort(rpe: 5), .easy)
        XCTAssertEqual(Effort(rpe: 7), .solid)
        XCTAssertEqual(Effort(rpe: 8), .solid)
        XCTAssertEqual(Effort(rpe: 9), .hard)
        XCTAssertEqual(Effort(rpe: 10), .hard)
        XCTAssertNil(Effort(rpe: nil))
    }
    func test_allCasesHaveLabels() {
        for e in Effort.allCases { XCTAssertFalse(e.label.isEmpty) }
    }
}
