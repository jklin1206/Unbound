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
        }
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
