import XCTest
@testable import UNBOUND

final class CutModeTests: XCTestCase {
    func testDisabledByDefault() {
        let cut = CutMode()
        XCTAssertFalse(cut.enabled)
        XCTAssertNil(cut.startedAt)
        XCTAssertEqual(cut.softCapWeeks, 8)
    }

    func testSoftCapNotReachedBeforeEightWeeks() {
        let cut = CutMode(enabled: true, startedAt: Date().addingTimeInterval(-7 * 7 * 86400))
        XCTAssertFalse(cut.softCapReached(now: Date()))
    }

    func testSoftCapReachedJustPastEightWeeks() {
        let cut = CutMode(enabled: true, startedAt: Date().addingTimeInterval(-8 * 7 * 86400 - 3600))
        XCTAssertTrue(cut.softCapReached(now: Date()))
    }

    func testDisabledCutNeverReachesSoftCap() {
        let cut = CutMode(enabled: false, startedAt: Date().addingTimeInterval(-100 * 86400))
        XCTAssertFalse(cut.softCapReached(now: Date()))
    }

    func testNoStartedAtNeverReachesSoftCap() {
        let cut = CutMode(enabled: true, startedAt: nil)
        XCTAssertFalse(cut.softCapReached(now: Date()))
    }

    func testCodableRoundtrip() throws {
        let original = CutMode(enabled: true, startedAt: Date(timeIntervalSince1970: 1_700_000_000), softCapWeeks: 8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CutMode.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
