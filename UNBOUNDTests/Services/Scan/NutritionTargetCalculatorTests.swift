import XCTest
@testable import UNBOUND

final class NutritionTargetCalculatorTests: XCTestCase {
    func testBodyweightProducesProteinRangeAndHydrationTarget() {
        let context = NutritionTargetCalculator().calculate(
            input: .init(bodyweightKilograms: 80, hardSessionLoggedWithin24Hours: true)
        )

        XCTAssertFalse(context.usesGenericFallback)
        XCTAssertEqual(context.bodyweightKilograms, 80)
        XCTAssertEqual(context.protein.minGrams, 130)
        XCTAssertEqual(context.protein.maxGrams, 175)
        XCTAssertEqual(context.protein.recommendedGrams, 145)
        XCTAssertEqual(context.hydration.liters, 2.8)
        XCTAssertEqual(context.trainingFuel, .hardSession)
    }

    func testNoBodyweightProducesGenericFallbackWithoutNumericTargets() {
        let context = NutritionTargetCalculator().calculate(input: .init())

        XCTAssertTrue(context.usesGenericFallback)
        XCTAssertNil(context.bodyweightKilograms)
        XCTAssertNil(context.protein.minGrams)
        XCTAssertNil(context.protein.maxGrams)
        XCTAssertNil(context.protein.recommendedGrams)
        XCTAssertNil(context.hydration.liters)
        XCTAssertNil(context.trainingFuel)
        XCTAssertTrue(context.protein.displayText.contains("0.7-1.0g"))
    }

    func testInvalidBodyweightFallsBackToGeneric() {
        let context = NutritionTargetCalculator().calculate(
            input: .init(bodyweightKilograms: 12, hardSessionLoggedWithin24Hours: true)
        )

        XCTAssertTrue(context.usesGenericFallback)
        XCTAssertNil(context.bodyweightKilograms)
        XCTAssertEqual(context.trainingFuel, .hardSession)
    }
}
