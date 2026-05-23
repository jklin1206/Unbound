import XCTest
@testable import UNBOUND

final class ScanCadenceGateTests: XCTestCase {
    func testNoPriorScanIsUnlocked() {
        let state = ScanCadenceState.compute(lastScanAt: nil, now: .now)
        XCTAssertTrue(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 0)
    }

    func testThirtyDaysExactlyIsUnlocked() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(30 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertTrue(state.isUnlocked)
    }

    func testTwentyNineDaysIsLocked() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(29 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 1)
    }

    func testTwentyThreeDayWindowAddsPulse() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(23 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 7)
        XCTAssertTrue(state.urgencyPulse)
    }

    func testEarlyDaysAreMuted() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(5 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 25)
        XCTAssertFalse(state.urgencyPulse)
    }
}
