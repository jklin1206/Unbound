import XCTest
@testable import UNBOUND

final class AttributeValueTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testZeroIsZeroXP() {
        let v = AttributeValue.zero(at: t0)
        XCTAssertEqual(v.xp, 0)
        XCTAssertEqual(v.level, 0)
        XCTAssertEqual(v.lastContributionAt, t0)
    }

    // Curve: xpRequired(L) = 16·L^2, level(xp) = min(100, floor((xp/16)^0.5)).
    func testLevelDerivesFromXPViaQuadraticCurve() {
        // L10 cumulative = 16 · 100 = 1_600.
        let v = AttributeValue(xp: 1_600, lastContributionAt: t0)
        XCTAssertEqual(v.level, 10)
        // L50 cumulative = 16 · 2_500 = 40_000.
        let v50 = AttributeValue(xp: 40_000, lastContributionAt: t0)
        XCTAssertEqual(v50.level, 50)
    }

    func testLevelClampsAtMaxLevel() {
        // Far beyond L100 (= 16·10_000 = 160_000) stays at 100.
        let v = AttributeValue(xp: 5_000_000, lastContributionAt: t0)
        XCTAssertEqual(v.level, AttributeLevelCurve.maxLevel)
    }

    func testHexFillIsLinearLevelOverMax() {
        let v50 = AttributeValue(xp: 40_000, lastContributionAt: t0)   // L50
        XCTAssertEqual(v50.hexFill, 0.5, accuracy: 0.001)
        let vMax = AttributeValue(xp: 160_000, lastContributionAt: t0) // L100
        XCTAssertEqual(vMax.hexFill, 1.0, accuracy: 0.001)
    }

    func testRankTitleMapsThroughLevelTable() {
        // L0 → initiate.
        XCTAssertEqual(AttributeValue.zero(at: t0).rankTitle, .initiate)
        // L15 (= 16·225 = 3_600) → veteran (threshold 15).
        let vet = AttributeValue(xp: 3_600, lastContributionAt: t0)
        XCTAssertEqual(vet.level, 15)
        XCTAssertEqual(vet.rankTitle, .veteran)
        // L100 → ascendant.
        let asc = AttributeValue(xp: 160_000, lastContributionAt: t0)
        XCTAssertEqual(asc.rankTitle, .ascendant)
    }

    func testXPToNextLevel() {
        // At exactly L10 (1_600 xp), next level L11 = 16·121 = 1_936 → 336 to go.
        let v = AttributeValue(xp: 1_600, lastContributionAt: t0)
        XCTAssertEqual(v.xpToNextLevel, 336, accuracy: 0.001)
    }
}
