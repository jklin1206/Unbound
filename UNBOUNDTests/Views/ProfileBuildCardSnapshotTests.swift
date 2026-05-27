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

    func testMidProfileRendersWithoutCrashing() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power,         AttributeValue(peak: 72, current: 72, lastContributionAt: t0))
        p.set(.vitality,       AttributeValue(peak: 45, current: 45, lastContributionAt: t0))
        p.set(.control,       AttributeValue(peak: 58, current: 58, lastContributionAt: t0))
        p.set(.endurance,     AttributeValue(peak: 52, current: 52, lastContributionAt: t0))
        p.set(.mobility,      AttributeValue(peak: 28, current: 28, lastContributionAt: t0))
        p.set(.explosiveness, AttributeValue(peak: 38, current: 38, lastContributionAt: t0))
        _ = ProfileBuildCard(profile: p).body
    }

    func testSaturatedProfileRendersWithoutCrashing() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 95, current: 92, lastContributionAt: t0))
        }
        _ = ProfileBuildCard(profile: p).body
    }
}
