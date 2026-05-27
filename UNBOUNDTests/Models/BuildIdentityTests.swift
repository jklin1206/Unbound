// UNBOUNDTests/Models/BuildIdentityTests.swift
import XCTest
@testable import UNBOUND

final class BuildIdentityTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func profile(_ pairs: [(AttributeKey, Double)]) -> AttributeProfile {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        for (key, peak) in pairs {
            p.set(key, AttributeValue(peak: peak, current: peak, lastContributionAt: t0))
        }
        return p
    }

    // MARK: Shape derivation

    func testEmptyProfileIsBalancedAthlete() {
        let p = AttributeProfile.empty(userId: "u", at: t0)
        XCTAssertEqual(p.buildIdentity.shape, .balancedAthlete)
    }

    func testSingleHighAxisIsSpecialist() {
        let p = profile([(.power, 50)])
        XCTAssertEqual(p.buildIdentity.shape, .specialist)
        XCTAssertEqual(p.buildIdentity.primary, .power)
    }

    func testTwoCloseAxesIsHybrid() {
        let p = profile([(.power, 40), (.explosiveness, 38)])
        XCTAssertEqual(p.buildIdentity.shape, .hybrid)
        XCTAssertEqual(p.buildIdentity.primary, .power)
        XCTAssertEqual(p.buildIdentity.secondary, .explosiveness)
    }

    func testThreeCloseAxesIsHybridAthlete() {
        let p = profile([(.power, 40), (.explosiveness, 40), (.vitality, 40)])
        XCTAssertEqual(p.buildIdentity.shape, .hybridAthlete)
        XCTAssertNil(p.buildIdentity.primary)
        XCTAssertNil(p.buildIdentity.secondary)
    }

    func testAllSaturatedIsBalancedAthlete() {
        let pairs: [(AttributeKey, Double)] = AttributeKey.allCases.map { ($0, 100.0) }
        let p = profile(pairs)
        XCTAssertEqual(p.buildIdentity.shape, .balancedAthlete)
    }

    // MARK: Boundary cases — strict inequalities

    func testSpreadExactly15EscapesBalanced() {
        let p = profile([(.power, 15)])
        XCTAssertNotEqual(p.buildIdentity.shape, .balancedAthlete)
    }

    func testGap12Exactly10FallsToLean() {
        let p = profile([(.power, 30), (.endurance, 20)])
        XCTAssertEqual(p.buildIdentity.shape, .lean)
    }

    func testGap12Exactly25FallsToLean() {
        let p = profile([(.power, 50), (.endurance, 25)])
        XCTAssertEqual(p.buildIdentity.shape, .lean)
    }

    func testGap12Over25IsSpecialist() {
        let p = profile([(.power, 60), (.endurance, 30)])
        XCTAssertEqual(p.buildIdentity.shape, .specialist)
    }

    // MARK: displayName outputs

    func testDisplayNameBalancedAthlete() {
        let id = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        XCTAssertEqual(id.displayName, "Balanced Athlete")
    }

    func testDisplayNameHybridAthlete() {
        let id = BuildIdentity(primary: nil, secondary: nil, shape: .hybridAthlete)
        XCTAssertEqual(id.displayName, "Hybrid Athlete")
    }

    func testDisplayNameSpecialistPerAxis() {
        let cases: [(AttributeKey, String)] = [
            (.power, "Power Specialist"),
            (.vitality, "Vitality Specialist"),
            (.control, "Control Specialist"),
            (.endurance, "Endurance Specialist"),
            (.mobility, "Mobility Specialist"),
            (.explosiveness, "Explosive Specialist"),
        ]
        for (key, expected) in cases {
            let id = BuildIdentity(primary: key, secondary: nil, shape: .specialist)
            XCTAssertEqual(id.displayName, expected, "for \(key)")
        }
    }

    func testDisplayNameHybridPerAxis() {
        let cases: [(AttributeKey, String)] = [
            (.power, "Power Hybrid"),
            (.vitality, "Vitality Hybrid"),
            (.control, "Control Hybrid"),
            (.endurance, "Endurance Hybrid"),
            (.mobility, "Mobility Hybrid"),
            (.explosiveness, "Explosive Hybrid"),
        ]
        for (key, expected) in cases {
            let id = BuildIdentity(primary: key, secondary: .endurance, shape: .hybrid)
            XCTAssertEqual(id.displayName, expected, "for \(key)")
        }
    }

    func testDisplayNameLeanPerAxis() {
        let cases: [(AttributeKey, String)] = [
            (.power, "Power-Oriented"),
            (.vitality, "Vitality-Focused"),
            (.control, "Control-Focused"),
            (.endurance, "Endurance-Dominant"),
            (.mobility, "Mobility-Focused"),
            (.explosiveness, "Explosive Athlete"),
        ]
        for (key, expected) in cases {
            let id = BuildIdentity(primary: key, secondary: nil, shape: .lean)
            XCTAssertEqual(id.displayName, expected, "for \(key)")
        }
    }

    // MARK: tagline outputs

    func testTaglineBalancedAthlete() {
        let id = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        XCTAssertEqual(id.tagline, "Even across every axis.")
    }

    func testTaglineHybridAthlete() {
        let id = BuildIdentity(primary: nil, secondary: nil, shape: .hybridAthlete)
        XCTAssertEqual(id.tagline, "Multi-axis athlete — no single specialty.")
    }

    func testTaglineSpecialist() {
        let id = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        XCTAssertEqual(id.tagline, "Built around heavy output — sharply focused.")
    }

    func testTaglineHybrid() {
        let id = BuildIdentity(primary: .power, secondary: .endurance, shape: .hybrid)
        XCTAssertEqual(id.tagline, "Built around heavy output with strong Endurance.")
    }

    func testTaglineLean() {
        let id = BuildIdentity(primary: .power, secondary: nil, shape: .lean)
        XCTAssertEqual(id.tagline, "Trending toward heavy output.")
    }

    // MARK: Backward-compat alias

    func testBuildNameMatchesBuildIdentityDisplayName() {
        let p = profile([(.power, 50)])
        XCTAssertEqual(p.buildName, p.buildIdentity.displayName)
    }
}
