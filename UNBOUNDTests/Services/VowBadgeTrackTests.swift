import XCTest
@testable import UNBOUND

final class VowBadgeTrackTests: XCTestCase {

    // MARK: - totalKept

    func test_totalKept_sumsAllLanes() {
        let byLane: [VowLane: Int] = [.fuel: 3, .recovery: 2, .engine: 1]
        XCTAssertEqual(VowBadgeTrack.totalKept(byLane), 6)
    }

    func test_totalKept_emptyIsZero() {
        XCTAssertEqual(VowBadgeTrack.totalKept([:]), 0)
    }

    // MARK: - crossings

    func test_crossings_4to5_yields5() {
        let result = VowBadgeTrack.crossings(priorKept: 4, currentKept: 5)
        XCTAssertEqual(result, [VowBadgeTrack.Milestone(threshold: 5)])
    }

    func test_crossings_5to5_yieldsEmpty() {
        // Already at threshold — no new crossing
        let result = VowBadgeTrack.crossings(priorKept: 5, currentKept: 5)
        XCTAssertTrue(result.isEmpty)
    }

    func test_crossings_14to15_yields15() {
        let result = VowBadgeTrack.crossings(priorKept: 14, currentKept: 15)
        XCTAssertEqual(result, [VowBadgeTrack.Milestone(threshold: 15)])
    }

    func test_crossings_multipleThresholds_yieldsAll() {
        // Jumping from 4 to 16 crosses both 5 and 15
        let result = VowBadgeTrack.crossings(priorKept: 4, currentKept: 16)
        XCTAssertEqual(result.map(\.threshold), [5, 15])
    }

    func test_crossings_aboveAllThresholds_yieldsEmpty() {
        let result = VowBadgeTrack.crossings(priorKept: 52, currentKept: 53)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - progress

    func test_progress_7_hasNext15() {
        let p = VowBadgeTrack.progress(totalKept: 7)
        XCTAssertEqual(p.current, 7)
        XCTAssertEqual(p.nextThreshold, 15)
    }

    func test_progress_0_hasNext5() {
        let p = VowBadgeTrack.progress(totalKept: 0)
        XCTAssertEqual(p.current, 0)
        XCTAssertEqual(p.nextThreshold, 5)
    }

    func test_progress_52_hasNilNext() {
        let p = VowBadgeTrack.progress(totalKept: 52)
        XCTAssertEqual(p.current, 52)
        XCTAssertNil(p.nextThreshold)
    }

    func test_progress_53_hasNilNext() {
        let p = VowBadgeTrack.progress(totalKept: 53)
        XCTAssertNil(p.nextThreshold)
    }
}
