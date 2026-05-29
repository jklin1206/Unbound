// UNBOUNDTests/Services/AttributeServiceDriftTests.swift
//
// Phase 5: peak-relative decay was deleted. `xp` is permanent and never
// decays, so `AttributeDrift.project` is now a pure passthrough that only
// stamps `computedAt`. The old decay-tempo / floor / midpoint tests asserted
// behavior that no longer exists and were removed.
import XCTest
@testable import UNBOUND

final class AttributeServiceDriftTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testProjectNeverChangesXP() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        let powerXP = AttributeLevelCurve.xpRequired(forLevel: 15)    // L15
        let mobilityXP = AttributeLevelCurve.xpRequired(forLevel: 10) // L10
        p.set(.power, AttributeValue(xp: powerXP, lastContributionAt: t0))
        p.set(.mobility, AttributeValue(xp: mobilityXP, lastContributionAt: t0))

        // Far past any old grace/decay window.
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(90 * 86_400))

        XCTAssertEqual(snap.value(for: .power).xp, powerXP, accuracy: 0.001)
        XCTAssertEqual(snap.value(for: .power).level, 15)
        XCTAssertEqual(snap.value(for: .mobility).xp, mobilityXP, accuracy: 0.001)
        XCTAssertEqual(snap.value(for: .mobility).level, 10)
    }

    func testProjectStampsComputedAt() {
        let p = AttributeProfile.empty(userId: "u", at: t0)
        let when = t0.addingTimeInterval(12 * 86_400)
        XCTAssertEqual(AttributeDrift.project(p, to: when).computedAt, when)
    }
}
