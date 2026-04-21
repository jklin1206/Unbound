import XCTest
@testable import UNBOUND

final class BlockRolloverSchedulerTests: XCTestCase {

    func testNoRolloverBeforeFourteenDaysElapsed() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-13 * 86400))
        XCTAssertFalse(BlockRolloverScheduler.shouldRollover(program: program, now: Date()))
    }

    func testRolloverAtExactlyFourteenDays() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-14 * 86400))
        XCTAssertTrue(BlockRolloverScheduler.shouldRollover(program: program, now: Date()))
    }

    func testRolloverAfterFourteenDays() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-20 * 86400))
        XCTAssertTrue(BlockRolloverScheduler.shouldRollover(program: program, now: Date()))
    }

    func testDaysRemainingDescendsLinearly() {
        let now = Date()
        let p1 = makeProgram(createdAt: now)                                    // day 1 → 14 days remaining
        let p7 = makeProgram(createdAt: now.addingTimeInterval(-6 * 86400))     // day 7 → 8 days remaining
        let p14 = makeProgram(createdAt: now.addingTimeInterval(-13 * 86400))   // day 14 → 1 day remaining
        let pDone = makeProgram(createdAt: now.addingTimeInterval(-14 * 86400)) // day 15 → 0 days remaining

        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: p1, now: now), 14)
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: p7, now: now), 8)
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: p14, now: now), 1)
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: pDone, now: now), 0)
    }

    func testDaysRemainingClampsAtZero() {
        let program = makeProgram(createdAt: Date().addingTimeInterval(-100 * 86400))
        XCTAssertEqual(BlockRolloverScheduler.daysRemaining(program: program, now: Date()), 0)
    }

    func testCurrentDayNumberWithinBlock() {
        let now = Date()
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now), now: now), 1)
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now.addingTimeInterval(-6 * 86400)), now: now), 7)
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now.addingTimeInterval(-13 * 86400)), now: now), 14)
        // Past end — clamp to durationDays (14)
        XCTAssertEqual(BlockRolloverScheduler.currentDayNumber(program: makeProgram(createdAt: now.addingTimeInterval(-20 * 86400)), now: now), 14)
    }

    // MARK: helper

    private func makeProgram(createdAt: Date) -> TrainingProgram {
        TrainingProgram(
            id: "p-1",
            scanId: "s-1",
            analysisId: "a-1",
            userId: "u-1",
            createdAt: createdAt,
            archetype: .shredded,
            name: "Test",
            description: "Test program",
            durationDays: 14,
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
