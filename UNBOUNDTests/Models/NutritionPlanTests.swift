import XCTest
@testable import UNBOUND

final class NutritionPlanTests: XCTestCase {
    func testTrainingAndRestTargetsResolveFromPlan() {
        let plan = makePlan()

        let training = plan.target(isRestDay: false)
        let rest = plan.target(isRestDay: true)

        XCTAssertEqual(training.calories, 2600)
        XCTAssertEqual(training.proteinGrams, 160)
        XCTAssertEqual(training.carbsGrams, 280)
        XCTAssertEqual(rest.calories, 2300)
        XCTAssertEqual(rest.proteinGrams, 160)
        XCTAssertEqual(rest.carbsGrams, 220)
        XCTAssertTrue(rest.isRestDay)
    }

    func testDayOverrideWinsForSelectedTarget() {
        let plan = makePlan()
        let override = DayNutrition(calories: 2450, proteinGrams: 170, carbsGrams: 250, fatGrams: 70)

        let target = plan.target(isRestDay: false, override: override)

        XCTAssertEqual(target.calories, 2450)
        XCTAssertEqual(target.proteinGrams, 170)
        XCTAssertEqual(target.carbsGrams, 250)
        XCTAssertEqual(target.fatGrams, 70)
        XCTAssertFalse(target.isRestDay)
    }

    private func makePlan() -> NutritionPlan {
        NutritionPlan(
            dailyCalories: 2600,
            proteinGrams: 160,
            carbsGrams: 280,
            fatGrams: 80,
            mealCount: 4,
            meals: [],
            hydrationLiters: 3.0,
            supplements: [],
            notes: "",
            restDayCalories: 2300,
            restDayProteinGrams: 160,
            restDayCarbsGrams: 220,
            restDayFatGrams: 80
        )
    }
}
