// UNBOUNDTests/Services/TrialGeneratorTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class TrialGeneratorTests: XCTestCase {

    func testDeterministic() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let a = TrialGenerator.cards(profile: profile, history: [], weekStart: weekStart, weekNumber: 5)
        let b = TrialGenerator.cards(profile: profile, history: [], weekStart: weekStart, weekNumber: 5)
        XCTAssertEqual(a, b)
    }

    func testAlwaysReturnsThreeCards() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        XCTAssertEqual(cards.count, 3)
    }

    func testThreeDistinctKinds() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        XCTAssertEqual(Set(cards.map(\.kind)), Set([.aligned, .growth, .prestige]))
    }

    func testAlignedThemeIsDominantAxis() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let aligned = cards.first(where: { $0.kind == .aligned })!
        XCTAssertEqual(aligned.theme, .axis(.power))
    }

    func testGrowthThemeIsWeakestAxis() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let growth = cards.first(where: { $0.kind == .growth })!
        XCTAssertEqual(growth.theme, .axis(.control))
    }

    func testPrestigeThemeIsWildcard() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let prestige = cards.first(where: { $0.kind == .prestige })!
        XCTAssertEqual(prestige.theme, .wildcard)
    }

    func testPrestigeRotatesByWeek() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let weekA = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 0)
        let weekB = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 1)
        let prestigeA = weekA.first(where: { $0.kind == .prestige })!
        let prestigeB = weekB.first(where: { $0.kind == .prestige })!
        XCTAssertNotEqual(prestigeA.capstone.displayName, prestigeB.capstone.displayName)
    }

    func testCardIdsUseWeekStamp() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = TrialGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        for card in cards {
            XCTAssertTrue(card.id.contains("W5"), "Card id missing week stamp: \(card.id)")
        }
    }

    // MARK: helpers

    private func makeProfile(powerValue: Double, controlValue: Double) -> AttributeProfile {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        for axis in AttributeKey.allCases {
            let value: Double = {
                switch axis {
                case .power: return powerValue
                case .control: return controlValue
                default: return 50
                }
            }()
            profile.set(axis, AttributeValue(peak: value, current: value, lastContributionAt: .now))
        }
        return profile
    }
}
