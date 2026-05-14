// UNBOUNDTests/Services/AttributeServiceBoostTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class AttributeServiceBoostTests: XCTestCase {

    private var mock: MockAttributeService!

    override func setUp() {
        super.setUp()
        mock = MockAttributeService()
    }

    func testBoostIncreasesAxisValue() {
        // Seed a starting value
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.power, AttributeValue(peak: 50, current: 50, lastContributionAt: .now))
        mock.profileByUser["u-1"] = profile

        mock.applyBoost(axis: .power, amount: 10, userId: "u-1")

        let updated = mock.profile(userId: "u-1")
        XCTAssertEqual(updated.value(for: .power).current, 60, accuracy: 0.01)
    }

    func testBoostClampsTo100() {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.power, AttributeValue(peak: 95, current: 95, lastContributionAt: .now))
        mock.profileByUser["u-1"] = profile

        mock.applyBoost(axis: .power, amount: 20, userId: "u-1")

        let updated = mock.profile(userId: "u-1")
        XCTAssertEqual(updated.value(for: .power).current, 100, accuracy: 0.01)
    }

    func testBoostDoesNotReduceValue() {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.endurance, AttributeValue(peak: 40, current: 40, lastContributionAt: .now))
        mock.profileByUser["u-1"] = profile

        mock.applyBoost(axis: .endurance, amount: 5, userId: "u-1")

        let updated = mock.profile(userId: "u-1")
        XCTAssertGreaterThanOrEqual(updated.value(for: .endurance).current, 40)
    }

    func testBoostUpdatesPeakWhenCurrentExceedsPriorPeak() {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.mobility, AttributeValue(peak: 30, current: 30, lastContributionAt: .now))
        mock.profileByUser["u-1"] = profile

        mock.applyBoost(axis: .mobility, amount: 15, userId: "u-1")

        let updated = mock.profile(userId: "u-1")
        XCTAssertEqual(updated.value(for: .mobility).peak, 45, accuracy: 0.01)
    }
}
