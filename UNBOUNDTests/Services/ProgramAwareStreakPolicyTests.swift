import XCTest
@testable import UNBOUND

final class ProgramAwareStreakPolicyTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func test_singleMissedDayUsesBaseGraceWindow() {
        let decision = ProgramAwareStreakPolicy.shouldExtendStreak(
            from: date("2026-05-04"),
            to: date("2026-05-06"),
            currentStreak: 5,
            resetWindowDays: 14,
            activeProgram: nil,
            calendar: calendar
        )

        XCTAssertEqual(decision.streak, 6)
        XCTAssertTrue(decision.extended)
        XCTAssertFalse(decision.broken)
    }

    func test_longerGapExtendsWhenSkippedProgramDaysAreRecovery() {
        let program = makeProgram(pattern: [.train, .rest, .rest, .train])

        let decision = ProgramAwareStreakPolicy.shouldExtendStreak(
            from: date("2026-05-04"),
            to: date("2026-05-07"),
            currentStreak: 5,
            resetWindowDays: 14,
            activeProgram: program,
            calendar: calendar
        )

        XCTAssertEqual(decision.streak, 6)
        XCTAssertTrue(decision.extended)
        XCTAssertFalse(decision.broken)
    }

    func test_longerGapBreaksWhenSkippedProgramDaysIncludeTraining() {
        let program = makeProgram(pattern: [.train, .rest, .train, .train])

        let decision = ProgramAwareStreakPolicy.shouldExtendStreak(
            from: date("2026-05-04"),
            to: date("2026-05-07"),
            currentStreak: 5,
            resetWindowDays: 14,
            activeProgram: program,
            calendar: calendar
        )

        XCTAssertEqual(decision.streak, 1)
        XCTAssertFalse(decision.extended)
        XCTAssertTrue(decision.broken)
    }

    func test_gapBeyondResetWindowBreaksEvenIfSkippedDaysAreRecovery() {
        let program = makeProgram(pattern: [.train, .rest, .rest, .rest, .rest])

        let decision = ProgramAwareStreakPolicy.shouldExtendStreak(
            from: date("2026-05-04"),
            to: date("2026-05-08"),
            currentStreak: 5,
            resetWindowDays: 3,
            activeProgram: program,
            calendar: calendar
        )

        XCTAssertEqual(decision.streak, 1)
        XCTAssertFalse(decision.extended)
        XCTAssertTrue(decision.broken)
    }

    private enum DayKind {
        case train
        case rest
    }

    private func makeProgram(pattern: [DayKind]) -> TrainingProgram {
        TrainingProgram(
            id: "program-rest-aware",
            scanId: "scan",
            analysisId: "analysis",
            userId: "user",
            createdAt: date("2026-05-04"),
            name: "Rest-Aware Block",
            description: "Test program",
            days: pattern.enumerated().map { index, kind in
                ProgramDay(
                    id: "day-\(index + 1)",
                    dayNumber: index + 1,
                    label: kind == .rest ? "Recovery" : "Train",
                    isRestDay: kind == .rest,
                    workout: kind == .rest ? nil : workout(),
                    nutritionOverride: nil,
                    recoveryActivities: []
                )
            },
            nutritionPlan: NutritionPlan(
                dailyCalories: 2200,
                proteinGrams: 150,
                carbsGrams: 240,
                fatGrams: 70,
                mealCount: 3,
                meals: [],
                hydrationLiters: 2.5,
                supplements: [],
                notes: "",
                restDayCalories: 2100,
                restDayProteinGrams: 150,
                restDayCarbsGrams: 220,
                restDayFatGrams: 70
            ),
            recoveryPlan: RecoveryPlan(sleepHoursTarget: 8, restDaysPerWeek: 2, activities: [], notes: ""),
            difficultyLevel: .beginner,
            requiredEquipment: [],
            estimatedDailyMinutes: 45
        )
    }

    private func workout() -> Workout {
        Workout(
            name: "Training Day",
            targetMuscleGroups: [.chest],
            warmup: [],
            mainExercises: [],
            cooldown: [],
            estimatedMinutes: 45,
            notes: nil,
            blockType: nil
        )
    }

    private func date(_ yyyyMMdd: String) -> Date {
        var components = DateComponents()
        let parts = yyyyMMdd.split(separator: "-").compactMap { Int($0) }
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return components.date!
    }
}
