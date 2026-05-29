import XCTest
@testable import UNBOUND

final class AttributeValueTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testZeroIsZeroValues() {
        let v = AttributeValue.zero(at: t0)
        XCTAssertEqual(v.peak, 0)
        XCTAssertEqual(v.current, 0)
        XCTAssertEqual(v.lastContributionAt, t0)
    }

    func testFloorIs70PercentOfPeak() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 80
        XCTAssertEqual(v.floor, 56.0, accuracy: 0.001)
    }

    func testRankTierReflectsCurrentNotPeak() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 100; v.current = 0
        XCTAssertEqual(v.rankTier, .initiate)   // old SubRank.eMinus → 2:1 band → initiate
        v.current = 100
        XCTAssertEqual(v.rankTier, .ascendant)  // old SubRank.sPlus → 2:1 band → ascendant
    }

    func testRankTitleMapsThroughRankTierTable() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 100
        v.current = 50  // 50/100*8 = 4.0 → veteran (old cPlus → 2:1 band → veteran)
        XCTAssertEqual(v.rankTitle, .veteran)
    }
}
