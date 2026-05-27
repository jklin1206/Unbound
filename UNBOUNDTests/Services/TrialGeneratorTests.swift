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

    func testPrescriptionsKeepKindSpecificDurationAndRPEIntent() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)
        let ember = cards.first(where: { $0.kind == .ember })!
        let overdrive = cards.first(where: { $0.kind == .overdrive })!
        let apex = cards.first(where: { $0.kind == .apex })!

        XCTAssertEqual(ember.prescription?.placement, .recoveryDay)
        XCTAssertEqual(ember.prescription?.minMinutes, 8)
        XCTAssertEqual(ember.prescription?.maxMinutes, 12)
        XCTAssertEqual(ember.prescription?.minRPE, 3)
        XCTAssertEqual(ember.prescription?.maxRPE, 5)

        XCTAssertEqual(overdrive.prescription?.placement, .afterWorkout)
        XCTAssertEqual(overdrive.prescription?.minMinutes, 6)
        XCTAssertEqual(overdrive.prescription?.maxMinutes, 12)
        XCTAssertEqual(overdrive.prescription?.minRPE, 7)
        XCTAssertEqual(overdrive.prescription?.maxRPE, 8)

        XCTAssertEqual(apex.prescription?.placement, .dedicatedSession)
        XCTAssertEqual(apex.prescription?.minMinutes, 20)
        XCTAssertEqual(apex.prescription?.maxMinutes, 45)
        XCTAssertEqual(apex.prescription?.minRPE, 8)
        XCTAssertEqual(apex.prescription?.maxRPE, 9)
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

    func testGeneratedCardsUseBindingVowLanguageAndImpactNames() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let cards = WeeklyVowGenerator.cards(profile: profile, history: [], weekStart: .now, weekNumber: 5)

        XCTAssertTrue(cards.allSatisfy { $0.displayName.localizedCaseInsensitiveContains("vow") })
        XCTAssertTrue(cards.allSatisfy { $0.blurb.localizedCaseInsensitiveContains("Binding Vow") })
        XCTAssertFalse(cards.map(\.displayName).contains { name in
            name.localizedCaseInsensitiveContains("Ember")
                || name.localizedCaseInsensitiveContains("Overdrive")
        })
    }

    func testPowerOverdriveProofNamesTheLiftItScaledFrom() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let history = [
            makeWorkoutLog(exerciseName: "bench press", weightKg: 80),
            makeWorkoutLog(exerciseName: "hip flexor stretch", weightKg: 120)
        ]

        let cards = WeeklyVowGenerator.cards(profile: profile, history: history, weekStart: .now, weekNumber: 5)
        let overdrive = cards.first(where: { $0.kind == .overdrive })!

        guard case .autoFromLog(.exerciseWeightKg(let target, let exerciseName)) = overdrive.capstone.evaluation else {
            return XCTFail("Expected an exercise-specific weight proof.")
        }

        XCTAssertEqual(exerciseName, "bench press")
        XCTAssertEqual(target, 85)
        XCTAssertTrue(overdrive.capstone.description.contains("Barbell Bench Press"))
    }

    func testApexWeightProofUsesExerciseSpecificTarget() {
        let profile = makeProfile(powerValue: 70, controlValue: 30)
        let history = [makeWorkoutLog(exerciseName: "deadlift", weightKg: 120)]

        let cards = WeeklyVowGenerator.cards(profile: profile, history: history, weekStart: .now, weekNumber: 2)
        let apex = cards.first(where: { $0.kind == .apex })!

        guard case .autoFromLog(.exerciseWeightKg(let target, let exerciseName)) = apex.capstone.evaluation else {
            return XCTFail("Expected an exercise-specific Apex proof.")
        }

        XCTAssertEqual(apex.capstone.displayName, "1-Rep PR Attempt")
        XCTAssertEqual(exerciseName, "deadlift")
        XCTAssertEqual(target, 125)
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

    private func makeWorkoutLog(exerciseName: String, weightKg: Double) -> WorkoutLog {
        WorkoutLog(
            id: UUID().uuidString,
            userId: "u-1",
            programId: "program",
            dayNumber: 1,
            plannedWorkoutName: "Lift",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_600),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: UUID().uuidString,
                    exerciseName: exerciseName,
                    plannedSets: 1,
                    plannedReps: "1",
                    sets: [
                        SetLog(
                            id: UUID().uuidString,
                            setNumber: 1,
                            weightKg: weightKg,
                            reps: 1,
                            rpe: nil,
                            isWarmup: false
                        )
                    ],
                    skipped: false,
                    notes: nil
                )
            ],
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: 45
        )
    }
}
