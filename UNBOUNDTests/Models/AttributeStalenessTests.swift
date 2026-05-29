import XCTest
@testable import UNBOUND

final class AttributeStalenessTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// Stale is now a pure recency flag off `lastContributionAt`. `xp`, level,
    /// and rank are permanent and never lost to a layoff.
    func testAxisGoesStaleAfterIdleButRankIsPreserved() {
        let value = AttributeValue(xp: 6_300, lastContributionAt: t0) // L15
        var profile = AttributeProfile.empty(userId: "u", at: t0)
        profile.set(.power, value)

        // Fresh: not idle → not stale.
        XCTAssertFalse(profile.value(for: .power).isStale(asOf: t0))
        XCTAssertFalse(profile.isStale(asOf: t0))

        // 31 days idle → stale flag, but xp/level/rank unchanged (no decay).
        let t31 = t0.addingTimeInterval(31 * 86_400)
        let projected = AttributeDrift.project(profile, to: t31)
        let v = projected.value(for: .power)

        XCTAssertTrue(v.isStale(asOf: t31))
        XCTAssertTrue(projected.isStale(asOf: t31))
        // Stale is now pure recency: every axis idle past the grace window is
        // flagged (the empty axes share the profile's t0 contribution stamp).
        XCTAssertTrue(projected.staleAxes(asOf: t31).contains(.power))

        // Rank is preserved: xp and the xp-derived level are unchanged.
        XCTAssertEqual(v.xp, value.xp, accuracy: 0.001)
        XCTAssertEqual(v.level, value.level)
        XCTAssertEqual(v.rankTitle, .veteran)
    }

    /// Within the grace window an axis is NOT flagged stale.
    func testWithinGraceWindowIsNotStale() {
        let value = AttributeValue(xp: 6_300, lastContributionAt: t0)
        var profile = AttributeProfile.empty(userId: "u", at: t0)
        profile.set(.power, value)

        let t5 = t0.addingTimeInterval(5 * 86_400)
        let projected = AttributeDrift.project(profile, to: t5)
        let v = projected.value(for: .power)

        XCTAssertFalse(v.isStale(asOf: t5))
        XCTAssertFalse(projected.isStale(asOf: t5))
        // xp never changes on project.
        XCTAssertEqual(v.xp, value.xp, accuracy: 0.001)
    }
}
