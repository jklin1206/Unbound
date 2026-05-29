// UNBOUNDTests/Views/ProfileBuildCardSnapshotTests.swift
import XCTest
import SwiftUI
@testable import UNBOUND

@MainActor
final class ProfileBuildCardSnapshotTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testEmptyProfileRendersWithoutCrashing() {
        let p = AttributeProfile.empty(userId: "u", at: t0)
        _ = ProfileBuildCard(profile: p).body
    }

    private func value(level: Int) -> AttributeValue {
        AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: level), lastContributionAt: t0)
    }

    func testMidProfileRendersWithoutCrashing() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power,         value(level: 72))
        p.set(.vitality,      value(level: 45))
        p.set(.control,       value(level: 58))
        p.set(.endurance,     value(level: 52))
        p.set(.mobility,      value(level: 28))
        p.set(.explosiveness, value(level: 38))
        _ = ProfileBuildCard(profile: p).body
    }

    func testSaturatedProfileRendersWithoutCrashing() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, value(level: 95))
        }
        _ = ProfileBuildCard(profile: p).body
    }
}
