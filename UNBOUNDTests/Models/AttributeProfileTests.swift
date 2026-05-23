import XCTest
@testable import UNBOUND

final class AttributeProfileTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testEmptyReturnsProfileWithAllZeroAxes() {
        let p = AttributeProfile.empty(userId: "u1", at: t0)
        XCTAssertEqual(p.values.count, AttributeKey.allCases.count)
        for key in AttributeKey.allCases {
            XCTAssertEqual(p.value(for: key).peak, 0)
            XCTAssertEqual(p.value(for: key).current, 0)
            XCTAssertEqual(p.value(for: key).xp, 0)
            XCTAssertEqual(p.level(for: key), 0)
        }
    }

    func testAttributeLevelUsesConcaveXPCurve() {
        let levelFourXP = AttributeLevelCurve.xpRequired(forLevel: 4)
        let value = AttributeValue(peak: 0, current: 0, xp: levelFourXP, lastContributionAt: t0)
        let justBelow = AttributeValue(peak: 0, current: 0, xp: levelFourXP - 0.1, lastContributionAt: t0)

        XCTAssertEqual(value.level, 4)
        XCTAssertEqual(justBelow.level, 3)
    }

    func testAttributeLevelCostCapsAfterSoftCap() {
        let level100XP = AttributeLevelCurve.xpRequired(forLevel: 100)
        let level101XP = AttributeLevelCurve.xpRequired(forLevel: 101)
        let level500XP = AttributeLevelCurve.xpRequired(forLevel: 500)
        let level501XP = AttributeLevelCurve.xpRequired(forLevel: 501)

        XCTAssertEqual(level101XP - level100XP, AttributeLevelCurve.cappedXPPerLevel, accuracy: 0.001)
        XCTAssertEqual(level501XP - level500XP, AttributeLevelCurve.cappedXPPerLevel, accuracy: 0.001)
        XCTAssertEqual(AttributeLevelCurve.level(forXP: level500XP), 500)
        XCTAssertEqual(AttributeLevelCurve.level(forXP: level500XP - 0.1), 499)
    }

    func testLegacyAttributeValuesBackfillXPFromPeakScore() {
        let value = AttributeValue(peak: 72, current: 60, lastContributionAt: t0)

        XCTAssertEqual(value.xp, AttributeLevelCurve.legacyXP(forScore: 72), accuracy: 0.001)
        XCTAssertEqual(value.level, AttributeLevelCurve.level(forXP: value.xp))
    }

    func testDominantIsAxisWithHighestPeak() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power,    AttributeValue(peak: 80, current: 60, lastContributionAt: t0))
        p.set(.mobility, AttributeValue(peak: 40, current: 30, lastContributionAt: t0))
        XCTAssertEqual(p.dominant, .power)
    }

    func testWeakestIsAxisWithLowestPeak() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        // All 6 axes non-zero — exercises the `peak > 0` filter on a fully-trained profile.
        p.set(.power,         AttributeValue(peak: 80, current: 60, lastContributionAt: t0))
        p.set(.agility,       AttributeValue(peak: 45, current: 40, lastContributionAt: t0))
        p.set(.control,       AttributeValue(peak: 55, current: 50, lastContributionAt: t0))
        p.set(.endurance,     AttributeValue(peak: 60, current: 55, lastContributionAt: t0))
        p.set(.mobility,      AttributeValue(peak: 20, current: 14, lastContributionAt: t0))
        p.set(.explosiveness, AttributeValue(peak: 35, current: 30, lastContributionAt: t0))
        XCTAssertEqual(p.weakest, .mobility)
    }

    func testIsBalancedWhenMaxMinusMinUnder15() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 50, current: 50, lastContributionAt: t0))
        }
        p.set(.power, AttributeValue(peak: 60, current: 60, lastContributionAt: t0))
        XCTAssertTrue(p.isBalanced)  // 60 - 50 = 10 < 15
    }

    func testIsBalancedFalseWhenSpread15OrMore() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 30, current: 30, lastContributionAt: t0))
        }
        p.set(.power, AttributeValue(peak: 50, current: 50, lastContributionAt: t0))
        XCTAssertFalse(p.isBalanced, "spread 20 must be unbalanced")  // 50 - 30 = 20

        // Boundary: spread exactly 15 must also be unbalanced (`< 15` is strict).
        p.set(.power, AttributeValue(peak: 45, current: 45, lastContributionAt: t0))
        XCTAssertFalse(p.isBalanced, "spread 15 must be unbalanced (strict < 15)")
    }

    func testBuildNameIsBalancedAthleteWhenSpreadUnder15() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 50, current: 50, lastContributionAt: t0))
        }
        XCTAssertEqual(p.buildName, "Balanced Athlete")
    }

    func testBuildNameDerivesFromBuildIdentityWhenSkewed() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        // gap12 = 70 - 20 = 50 → .specialist (gap12 > 25)
        p.set(.power, AttributeValue(peak: 70, current: 60, lastContributionAt: t0))
        p.set(.mobility, AttributeValue(peak: 20, current: 14, lastContributionAt: t0))
        XCTAssertEqual(p.buildName, "Power Specialist")
    }
}
