import XCTest
@testable import UNBOUND

final class AttributeStalenessTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// Kickoff proof: 31d idle → stale flag + recent < lifetime, rank unchanged.
    func testAxisGoesStaleAfterIdleButRankIsPreserved() {
        let value = AttributeValue(peak: 80, current: 80, lastContributionAt: t0)
        var profile = AttributeProfile.empty(userId: "u", at: t0)
        profile.set(.power, value)

        // Fresh: at peak, not idle → not stale.
        XCTAssertFalse(profile.value(for: .power).isStale(asOf: t0))
        XCTAssertFalse(profile.isStale(asOf: t0))

        // 31 days idle: drift current toward floor.
        let t31 = t0.addingTimeInterval(31 * 86_400)
        let drifted = AttributeDrift.project(profile, to: t31)
        let v = drifted.value(for: .power)

        // recent < lifetime
        XCTAssertLessThan(v.current, v.peak)
        XCTAssertTrue(v.recentBelowLifetimePeak)
        // honest stale flag
        XCTAssertTrue(v.isStale(asOf: t31))
        XCTAssertTrue(drifted.isStale(asOf: t31))
        XCTAssertEqual(drifted.staleAxes(asOf: t31), [.power])

        // rank is preserved: peak, xp, and the xp-derived level are unchanged.
        XCTAssertEqual(v.peak, 80, accuracy: 0.001)
        XCTAssertEqual(v.xp, value.xp, accuracy: 0.001)
        XCTAssertEqual(v.level, value.level)
    }

    /// Within the grace window, a drifted-but-recent axis is NOT flagged stale.
    func testWithinGraceWindowIsNotStale() {
        let value = AttributeValue(peak: 80, current: 80, lastContributionAt: t0)
        var profile = AttributeProfile.empty(userId: "u", at: t0)
        profile.set(.power, value)

        let t5 = t0.addingTimeInterval(5 * 86_400)
        let drifted = AttributeDrift.project(profile, to: t5)
        let v = drifted.value(for: .power)

        XCTAssertEqual(v.current, v.peak, accuracy: 0.001, "No drift inside grace window")
        XCTAssertFalse(v.isStale(asOf: t5))
        XCTAssertFalse(drifted.isStale(asOf: t5))
    }

    /// A recently-trained axis below its peak is not stale (staleness requires a layoff).
    func testRecentlyTrainedBelowPeakIsNotStale() {
        // current < peak but contributed today → not a layoff.
        let recent = AttributeValue(peak: 80, current: 60, lastContributionAt: t0)
        XCTAssertTrue(recent.recentBelowLifetimePeak)
        XCTAssertFalse(recent.isStale(asOf: t0))
    }
}
