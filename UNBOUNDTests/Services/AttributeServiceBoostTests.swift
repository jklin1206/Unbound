// UNBOUNDTests/Services/AttributeServiceBoostTests.swift
//
// Phase 5: AttributeValue collapsed to {xp, lastContributionAt}. `applyBoost`
// now adds its `amount` directly as permanent XP (the old 0...100 score /
// peak clamp is gone — xp has a level ceiling, not a 100 cap).
import XCTest
@testable import UNBOUND

@MainActor
final class AttributeServiceBoostTests: XCTestCase {

    private var mock: MockAttributeService!

    override func setUp() {
        super.setUp()
        mock = MockAttributeService()
    }

    func testBoostAddsXP() {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.power, AttributeValue(xp: 1_000, lastContributionAt: .now))
        mock.profileByUser["u-1"] = profile

        mock.applyBoost(axis: .power, amount: 250, userId: "u-1")

        XCTAssertEqual(mock.profile(userId: "u-1").value(for: .power).xp, 1_250, accuracy: 0.01)
    }

    func testBoostNeverReducesXP() {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.endurance, AttributeValue(xp: 5_000, lastContributionAt: .now))
        mock.profileByUser["u-1"] = profile

        mock.applyBoost(axis: .endurance, amount: -100, userId: "u-1")

        // Negative amounts are clamped to 0 — xp is permanent and only grows.
        XCTAssertEqual(mock.profile(userId: "u-1").value(for: .endurance).xp, 5_000, accuracy: 0.01)
    }

    func testBoostRaisesLevel() {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.mobility, AttributeValue(xp: 0, lastContributionAt: .now))
        mock.profileByUser["u-1"] = profile

        // base-independent: award exactly the XP for L10.
        mock.applyBoost(axis: .mobility, amount: AttributeLevelCurve.xpRequired(forLevel: 10), userId: "u-1")

        XCTAssertEqual(mock.profile(userId: "u-1").value(for: .mobility).level, 10)
    }
}
