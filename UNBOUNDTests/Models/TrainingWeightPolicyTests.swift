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

    func testFormattedWeightWithUnitUsesSelectedUnitLabel() {
        let kilograms = TrainingWeightUnit.pounds.kilograms(fromDisplayValue: 225)

        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeightWithUnit(kilograms, unit: .pounds, separator: " "),
            "225 lb"
        )
        XCTAssertEqual(
            WeightPlatePolicy.formatLoggedWeightWithUnit(kilograms, unit: .kilograms, separator: " "),
            "102.1 kg"
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

    func testSuggestionFormattingSnapsConvertedWeightsToSelectedUnitScale() {
        let twoPlatePoundsInKilograms = TrainingWeightUnit.pounds.kilograms(fromDisplayValue: 225)

        XCTAssertEqual(
            WeightPlatePolicy.formatSuggestionWeightWithUnit(
                twoPlatePoundsInKilograms,
                unit: .kilograms,
                microloadingEnabled: false,
                separator: " "
            ),
            "102.5 kg"
        )

        XCTAssertEqual(
            WeightPlatePolicy.formatSuggestionWeightWithUnit(
                100,
                unit: .pounds,
                microloadingEnabled: false,
                separator: " "
            ),
            "220 lb"
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

    // MARK: - Implement-aware loads

    func testImplementResolution() {
        XCTAssertEqual(LoadImplement.resolve(exerciseKey: "barbell back squat"), .barbell)
        XCTAssertEqual(LoadImplement.resolve(exerciseKey: "goblet squat"), .dumbbell)
        XCTAssertEqual(LoadImplement.resolve(exerciseKey: "kettlebell swing"), .kettlebell)
        XCTAssertEqual(LoadImplement.resolve(exerciseKey: "lat pulldown"), .machine)
        // Unknown custom names get the bounded dumbbell treatment.
        XCTAssertEqual(LoadImplement.resolve(exerciseKey: "garage lever contraption"), .dumbbell)
    }

    func testKettlebellSnapsToFourKilogramLadderInAnyUnit() {
        XCTAssertEqual(
            WeightPlatePolicy.snappedSuggestionKilograms(22.7, implement: .kettlebell, unit: .pounds),
            24
        )
        XCTAssertEqual(
            WeightPlatePolicy.snappedSuggestionKilograms(17, implement: .kettlebell, unit: .kilograms),
            16
        )
        let next = WeightPlatePolicy.progressedWeightKilograms(
            from: 16,
            classification: .lowerCompound,
            implement: .kettlebell,
            unit: .pounds,
            microloadingEnabled: false
        )
        XCTAssertEqual(next, 20)
    }

    func testMachineStackMovesInCoarserPitch() {
        XCTAssertEqual(
            WeightPlatePolicy.snappedSuggestionKilograms(31.8, implement: .machine, unit: .kilograms),
            30
        )
        let next = WeightPlatePolicy.progressedWeightKilograms(
            from: 30,
            classification: .accessory,
            implement: .machine,
            unit: .kilograms,
            microloadingEnabled: false
        )
        XCTAssertEqual(next, 35)
    }

    func testDumbbellProgressionStopsAtImplementCap() {
        let capped = WeightPlatePolicy.progressedWeightKilograms(
            from: 50,
            classification: .lowerCompound,
            implement: .dumbbell,
            unit: .kilograms,
            microloadingEnabled: false
        )
        XCTAssertEqual(capped, 50, "No heavier dumbbell exists to prescribe")

        let underCap = WeightPlatePolicy.progressedWeightKilograms(
            from: 45,
            classification: .lowerCompound,
            implement: .dumbbell,
            unit: .kilograms,
            microloadingEnabled: false
        )
        XCTAssertEqual(underCap, 47.5, "Dumbbells jump one plate size, not the barbell double jump")
    }

    func testBarbellProgressionStaysUncapped() {
        let next = WeightPlatePolicy.progressedWeightKilograms(
            from: 200,
            classification: .lowerCompound,
            implement: .barbell,
            unit: .kilograms,
            microloadingEnabled: false
        )
        XCTAssertEqual(next, 205)
    }
}
