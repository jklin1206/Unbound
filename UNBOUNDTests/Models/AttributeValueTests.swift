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

    func testSubRankReflectsCurrentNotPeak() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 100; v.current = 0
        XCTAssertEqual(v.subRank, SubRank.eMinus)
        v.current = 100
        XCTAssertEqual(v.subRank, SubRank.sPlus)
    }

    func testRankTitleMapsThroughRankTitleTable() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 100
        v.current = 50  // ordinal ~8 → cPlus → veteran (per existing SubRank.title table)
        XCTAssertEqual(v.rankTitle, .veteran)
    }
}
