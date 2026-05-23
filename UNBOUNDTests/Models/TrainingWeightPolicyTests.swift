import XCTest
@testable import UNBOUND

final class TrainingWeightPolicyTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: WeightPlatePolicy.unitDefaultsKey)
        UserDefaults.standard.removeObject(forKey: WeightPlatePolicy.microloadingDefaultsKey)
        super.tearDown()
    }

    func testPoundRoundTripKeepsTwoPlateBenchClean() {
        let kilograms = TrainingWeightUnit.pounds.kilograms(fromDisplayValue: 225)

        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeight(kilograms, unit: .pounds),
            "225"
        )
        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeight(kilograms, unit: .kilograms),
            "102.1"
        )
    }

    func testPoundSuggestionsSnapToLoadableNumbers() {
        let oddPounds = TrainingWeightUnit.pounds.kilograms(fromDisplayValue: 88)

        XCTAssertEqual(
            WeightPlatePolicy.formatSuggestionWeight(
                oddPounds,
                unit: .pounds,
                microloadingEnabled: false
            ),
            "90"
        )
    }

    func testPoundProgressionUsesStandardPlateJumpByDefault() {
        let current = TrainingWeightUnit.pounds.kilograms(fromDisplayValue: 225)
        let next = WeightPlatePolicy.progressedWeightKilograms(
            from: current,
            classification: .upperCompound,
            unit: .pounds,
            microloadingEnabled: false
        )

        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeight(next, unit: .pounds),
            "230"
        )
    }

    func testPoundMicroloadingUsesSmallerUpperBodyJump() {
        let current = TrainingWeightUnit.pounds.kilograms(fromDisplayValue: 225)
        let next = WeightPlatePolicy.progressedWeightKilograms(
            from: current,
            classification: .upperCompound,
            unit: .pounds,
            microloadingEnabled: true
        )

        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeight(next, unit: .pounds),
            "227.5"
        )
    }

    func testKilogramMicroloadingKeepsQuarterPlatePrecision() {
        let next = WeightPlatePolicy.progressedWeightKilograms(
            from: 100,
            classification: .upperCompound,
            unit: .kilograms,
            microloadingEnabled: true
        )

        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeight(next, unit: .kilograms),
            "101.25"
        )
    }

    func testLowerBodyPoundProgressionCanUseBiggerStandardJump() {
        let current = TrainingWeightUnit.pounds.kilograms(fromDisplayValue: 225)
        let next = WeightPlatePolicy.progressedWeightKilograms(
            from: current,
            classification: .lowerCompound,
            unit: .pounds,
            microloadingEnabled: false
        )

        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeight(next, unit: .pounds),
            "235"
        )
    }
}
