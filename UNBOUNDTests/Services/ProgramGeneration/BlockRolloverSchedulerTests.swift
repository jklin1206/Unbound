import XCTest
@testable import UNBOUND

final class BlockRolloverSchedulerTests: XCTestCase {

    func testNoRolloverBeforeTwentyEightDaysElapsed() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-27 * 86400))
        XCTAssertFalse(BlockRolloverScheduler.shouldRollover(program: program, now: Date()))
    }

    func testRolloverAtExactlyTwentyEightDays() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-28 * 86400))
        XCTAssertTrue(BlockRolloverScheduler.shouldRollover(program: program, now: Date()))
    }

    func testRolloverAfterTwentyEightDays() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-35 * 86400))
        XCTAssertTrue(BlockRolloverScheduler.shouldRollover(program: program, now: Date()))
    }

    func testDaysRemainingDescendsLinearly() {
        let now = Date()
        let p1 = makeProgram(createdAt: now)                                    // day 1 -> 28 days remaining
        let p15 = makeProgram(createdAt: now.addingTimeInterval(-14 * 86400))   // day 15 -> 14 days remaining
        let p28 = makeProgram(createdAt: now.addingTimeInterval(-27 * 86400))   // day 28 -> 1 day remaining
        let pDone = makeProgram(createdAt: now.addingTimeInterval(-28 * 86400)) // day 29 -> 0 days remaining

        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: p1, now: now), 28)
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: p15, now: now), 14)
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: p28, now: now), 1)
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: pDone, now: now), 0)
    }

    func testDaysRemainingClampsAtZero() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-100 * 86400))
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: program, now: Date()), 0)
    }

    func testCurrentDayNumberWithinBlock() {
        let now = Date()
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now), now: now), 1)
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now.addingTimeInterval(-14 * 86400)), now: now), 15)
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now.addingTimeInterval(-27 * 86400)), now: now), 28)
        // Past end - clamp to durationDays (28)
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now.addingTimeInterval(-35 * 86400)), now: now), 28)
    }

    func testCalibrationWeekUsesSevenDayDuration() {
        let now = Date()
        let daySix = makeProgram(createdAt: now.addingTimeInterval(-6 * 86400), durationDays: 7)
        let done = makeProgram(createdAt: now.addingTimeInterval(-7 * 86400), durationDays: 7)

        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: daySix, now: now), 1)
        XCTAssertFalse(BlockRolloverScheduler.shouldRollover(program: daySix, now: now))
        XCTAssertTrue(BlockRolloverScheduler.shouldRollover(program: done, now: now))
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: done, now: now), 7)
    }

    // MARK: helper

    private func makeProgram(createdAt: Date, durationDays: Int = 28) -> TrainingProgram {
        TrainingProgram(
            id: "p-1",
            scanId: "s-1",
            analysisId: "a-1",
            userId: "u-1",
            createdAt: createdAt,
            name: "Test",
            description: "Test program",
            durationDays: durationDays,
            days: [],
            nutritionPlan: NutritionPlan(
                dailyCalories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 60,
                mealCount: 4, meals: [], hydrationLiters: 3, supplements: [], notes: "",
                restDayCalories: 1800, restDayProteinGrams: 150, restDayCarbsGrams: 150, restDayFatGrams: 60
            ),
            recoveryPlan: RecoveryPlan(sleepHoursTarget: 8, restDaysPerWeek: 3, activities: [], notes: ""),
            difficultyLevel: .intermediate,
            requiredEquipment: [],
            estimatedDailyMinutes: 45,
            rationale: nil
        )
    }
}

final class ArcModelTests: XCTestCase {
    func testArcDateMathAndWaveBoundary() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let arc = Arc(id: "arc-1", programId: "p-1", startDate: start)

        XCTAssertEqual(arc.dayNumber(asOf: start), 1)
        XCTAssertEqual(arc.currentWave(asOf: start), .wave1)
        XCTAssertEqual(arc.dayNumber(asOf: start.addingTimeInterval(13 * 86_400)), 14)
        XCTAssertEqual(arc.currentWave(asOf: start.addingTimeInterval(13 * 86_400)), .wave1)
        XCTAssertEqual(arc.dayNumber(asOf: start.addingTimeInterval(14 * 86_400)), 15)
        XCTAssertEqual(arc.currentWave(asOf: start.addingTimeInterval(14 * 86_400)), .wave2)
        XCTAssertEqual(arc.dayNumber(asOf: start.addingTimeInterval(27 * 86_400)), 28)
        XCTAssertEqual(arc.currentWave(asOf: start.addingTimeInterval(27 * 86_400)), .wave2)
        XCTAssertNil(arc.dayNumber(asOf: start.addingTimeInterval(28 * 86_400)))
        XCTAssertNil(arc.currentWave(asOf: start.addingTimeInterval(28 * 86_400)))
    }

    func testTrainingProgramDecodesLegacyPayloadWithoutArcFields() throws {
        let program = TrainingProgram(
            id: "p-1",
            scanId: "s-1",
            analysisId: "a-1",
            userId: "u-1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            name: "Legacy",
            description: "Legacy payload",
            durationDays: 14,
            days: [
                ProgramDay(
                    id: "d-1",
                    dayNumber: 1,
                    label: "Push",
                    isRestDay: false,
                    workout: nil,
                    nutritionOverride: nil,
                    recoveryActivities: []
                )
            ],
            nutritionPlan: NutritionPlan(
                dailyCalories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 60,
                mealCount: 4, meals: [], hydrationLiters: 3, supplements: [], notes: "",
                restDayCalories: 1800, restDayProteinGrams: 150, restDayCarbsGrams: 150, restDayFatGrams: 60
            ),
            recoveryPlan: RecoveryPlan(sleepHoursTarget: 8, restDaysPerWeek: 3, activities: [], notes: ""),
            difficultyLevel: .intermediate,
            requiredEquipment: [],
            estimatedDailyMinutes: 45,
            rationale: nil
        )
        let data = try JSONEncoder().encode(program)
        var json = try XCTUnwrap(String(data: data, encoding: .utf8))
        json = json
            .replacingOccurrences(of: ",\"arcs\":[]", with: "")
            .replacingOccurrences(of: "\"arcs\":[],", with: "")
            .replacingOccurrences(of: ",\"sessionRole\":\"custom:unspecified\"", with: "")
            .replacingOccurrences(of: "\"sessionRole\":\"custom:unspecified\",", with: "")

        let decoded = try JSONDecoder().decode(TrainingProgram.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.arcs, [])
        XCTAssertNil(decoded.currentArcId)
        XCTAssertEqual(decoded.days.first?.sessionRole, .custom("unspecified"))
    }

    func testRegionLoadOnlyRecommendsTrimForOverBudgetRegion() {
        let planned = RegionLoad([.pull: 14, .legs: 8])
        let budget = RegionLoad([.pull: 10, .legs: 10, .push: 10])

        let trims = planned.trimRecommendations(over: budget)

        XCTAssertEqual(trims[.pull], 4)
        XCTAssertNil(trims[.legs])
        XCTAssertNil(trims[.push])
    }
}
