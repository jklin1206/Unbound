// UNBOUNDTests/Services/TrialGeneratorTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class WeeklyVowGeneratorTests: XCTestCase {

    func testDeterministic() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let a = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: weekStart, weekNumber: 5)
        let b = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: weekStart, weekNumber: 5)
        XCTAssertEqual(a, b)
    }

    func testAlwaysReturnsThreeCards() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        XCTAssertEqual(cards.count, 3)
    }

    func testThreeDistinctKinds() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        XCTAssertEqual(Set(cards.map(\.kind)), Set([.ember, .overdrive, .apex]))
    }

    func testOverdriveThemeIsDominantAxis() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let overdrive = cards.first(where: { $0.kind == .overdrive })!
        XCTAssertEqual(overdrive.theme, .axis(.power))
    }

    func testEmberThemeIsWeakestAxis() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let ember = cards.first(where: { $0.kind == .ember })!
        XCTAssertEqual(ember.theme, .axis(.control))
    }

    func testApexThemeIsWildcard() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let apex = cards.first(where: { $0.kind == .apex })!
        XCTAssertEqual(apex.theme, .wildcard)
    }

    func testApexRotatesByWeek() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let weekA = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 0)
        let weekB = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 1)
        let apexA = weekA.first(where: { $0.kind == .apex })!
        let apexB = weekB.first(where: { $0.kind == .apex })!
        XCTAssertNotEqual(apexA.capstone.displayName, apexB.capstone.displayName)
    }

    func testCardIdsUseWeekStamp() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        for card in cards {
            XCTAssertTrue(card.id.contains("W5"), "Card id missing week stamp: \(card.id)")
        }
    }

    func testEmberPrescriptionStaysRecoverySafe() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let ember = cards.first(where: { $0.kind == .ember })!

        XCTAssertEqual(ember.prescription?.placement, .recoveryDay)
        XCTAssertEqual(ember.prescription?.minMinutes, 8)
        XCTAssertEqual(ember.prescription?.maxMinutes, 12)
        XCTAssertEqual(ember.prescription?.minRPE, 3)
        XCTAssertEqual(ember.prescription?.maxRPE, 5)
    }

    func testGeneratedUserFacingCopyDoesNotUseTrialOrChallenge() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let copy = cards.flatMap { card in
            [
                card.kind.displayName,
                card.kind.shortDescription,
                card.displayName,
                card.blurb,
                card.capstone.displayName,
                card.capstone.description,
                card.prescription?.summary ?? ""
            ]
        }

        for text in copy {
            XCTAssertFalse(text.localizedCaseInsensitiveContains("trial"), "Unexpected weekly copy: \(text)")
            XCTAssertFalse(text.localizedCaseInsensitiveContains("challenge"), "Unexpected weekly copy: \(text)")
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
