import XCTest
@testable import UNBOUND

final class AttributeProfileTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// Seed an axis at exactly `level` via the curve's xp requirement.
    private func value(level: Int) -> AttributeValue {
        AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: level), lastContributionAt: t0)
    }

    func testEmptyReturnsProfileWithAllZeroAxes() {
        let p = AttributeProfile.empty(userId: "u1", at: t0)
        XCTAssertEqual(p.values.count, AttributeKey.allCases.count)
        for key in AttributeKey.allCases {
            XCTAssertEqual(p.value(for: key).xp, 0)
            XCTAssertEqual(p.level(for: key), 0)
        }
    }

    func testAttributeLevelUsesQuadraticXPCurve() {
        let levelFourXP = AttributeLevelCurve.xpRequired(forLevel: 4)
        let value = AttributeValue(xp: levelFourXP, lastContributionAt: t0)
        let justBelow = AttributeValue(xp: levelFourXP - 0.1, lastContributionAt: t0)

        XCTAssertEqual(value.level, 4)
        XCTAssertEqual(justBelow.level, 3)
    }

    func testLevelClampsHardAtMaxLevel() {
        let maxXP = AttributeLevelCurve.xpRequired(forLevel: 100)
        XCTAssertEqual(AttributeLevelCurve.level(forXP: maxXP), 100)
        // No soft-cap tail: beyond L100 stays pinned at 100.
        XCTAssertEqual(AttributeLevelCurve.level(forXP: maxXP * 10), 100)
        XCTAssertEqual(AttributeLevelCurve.xpRequired(forLevel: 500), maxXP, accuracy: 0.001)
    }

    func testCurveConstants() {
        XCTAssertEqual(AttributeLevelCurve.base, 16)
        XCTAssertEqual(AttributeLevelCurve.exponent, 2.0)
        XCTAssertEqual(AttributeLevelCurve.maxLevel, 100)
        // L1 costs 16 (base); L100 the cliff. Last level ≈ 200× the first.
        XCTAssertEqual(AttributeLevelCurve.xpRequired(forLevel: 1), 16, accuracy: 0.001)
    }

    func testHexChartValuesAreLinearLevelOverMax() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power, value(level: 50))   // L50 → 50% → 50.0 on the 0...100 chart
        XCTAssertEqual(p.hexChartValues[.power] ?? -1, 50, accuracy: 0.001)
        p.set(.control, value(level: 100)) // maxed → 100
        XCTAssertEqual(p.hexChartValues[.control] ?? -1, 100, accuracy: 0.001)
    }

    func testAttributeLevelRankTitlesUseLevelBands() {
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 0), .initiate)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 3), .novice)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 6), .apprentice)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 10), .forged)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 15), .veteran)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 25), .master)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 40), .vessel)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 65), .unbound)
        XCTAssertEqual(AttributeLevelCurve.rankTitle(forLevel: 100), .ascendant)
    }

    func testLevelRankTitlesReflectAxisLevel() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power, value(level: 10))   // forged
        XCTAssertEqual(p.levelRankTitles[.power], .forged)
    }

    func testDominantIsAxisWithHighestLevel() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power,    value(level: 50))
        p.set(.mobility, value(level: 20))
        XCTAssertEqual(p.dominant, .power)
    }

    func testWeakestIsAxisWithLowestLevel() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power,         value(level: 50))
        p.set(.vitality,      value(level: 28))
        p.set(.control,       value(level: 34))
        p.set(.endurance,     value(level: 38))
        p.set(.mobility,      value(level: 12))
        p.set(.explosiveness, value(level: 22))
        XCTAssertEqual(p.weakest, .mobility)
    }

    func testIsBalancedWhenMaxMinusMinUnder15() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases { p.set(key, value(level: 50)) }
        p.set(.power, value(level: 60))
        XCTAssertTrue(p.isBalanced)  // 60 - 50 = 10 < 15
    }

    func testIsBalancedFalseWhenSpread15OrMore() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases { p.set(key, value(level: 30)) }
        p.set(.power, value(level: 50))
        XCTAssertFalse(p.isBalanced, "spread 20 must be unbalanced")

        // Boundary: spread exactly 15 must also be unbalanced (`< 15` is strict).
        p.set(.power, value(level: 45))
        XCTAssertFalse(p.isBalanced, "spread 15 must be unbalanced (strict < 15)")
    }

    func testBuildNameIsBalancedAthleteWhenSpreadUnder15() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases { p.set(key, value(level: 50)) }
        XCTAssertEqual(p.buildName, "Balanced Athlete")
    }

    func testBuildNameDerivesFromBuildIdentityWhenSkewed() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        // gap12 = 70 - 20 = 50 levels → .specialist (gap12 > 25)
        p.set(.power, value(level: 70))
        p.set(.mobility, value(level: 20))
        XCTAssertEqual(p.buildName, "Power Specialist")
    }
}
