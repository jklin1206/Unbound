import XCTest
@testable import UNBOUND

final class ExerciseEquipmentClassifierTests: XCTestCase {

    // MARK: - Classification

    func testBarbellMovements() {
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("back squat"), .barbell)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("deadlift"), .barbell)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("romanian deadlift"), .barbell)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("bench press"), .barbell)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("overhead press"), .barbell)
    }

    func testDumbbellMovements() {
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("Dumbbell Bench Press"), .dumbbell)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("Dumbbell Row"), .dumbbell)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("goblet squat"), .dumbbell)
    }

    func testMachineAndCableMovements() {
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("leg press"), .machine)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("hack squat"), .machine)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("lat pulldown"), .machine)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("cable row"), .machine)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("cable fly"), .machine)
    }

    func testBodyweightMovements() {
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("pullup"), .bodyweight)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("push-up"), .bodyweight)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("dip"), .bodyweight)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("pistol squat"), .bodyweight)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("wall handstand pushup"), .bodyweight)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("bodyweight squat"), .bodyweight)
    }

    func testCatalogMovementsUseMovementCatalogEquipment() {
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("face pull"), .machine)

        let facePull = MovementCatalog.canonicalExercise(named: "face pull")
        XCTAssertEqual(facePull?.equipment.contains(.cable), true)
        XCTAssertEqual(facePull?.movementSlot, .verticalPush)
    }

    func testUnknownCustomNamesDefaultToDumbbellCompatibility() {
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("custom tempo press"), .dumbbell)
    }

    // MARK: - User-equipment compatibility

    func testBodyweightStyleRejectsNonBodyweight() {
        // Bodyweight-style users must never be prescribed barbell/machine work
        // even if their equipment chips would technically allow it.
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "push-up",
            style: .bodyweight,
            userEquipment: [.bodyweight]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat",
            style: .bodyweight,
            userEquipment: [.bodyweight]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "lat pulldown",
            style: .bodyweight,
            userEquipment: [.fullGym]
        ))
    }

    func testFullGymUserAcceptsEverything() {
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat",
            style: .hybrid,
            userEquipment: [.fullGym]
        ))
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "pullup",
            style: .hybrid,
            userEquipment: [.fullGym]
        ))
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "lat pulldown",
            style: .hybrid,
            userEquipment: [.fullGym]
        ))
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "Dumbbell Bench Press",
            style: .hybrid,
            userEquipment: [.fullGym]
        ))
    }

    func testHomeWeightsUserAcceptsDumbbellAndBodyweightButNotMachine() {
        // homeWeights = dumbbells + bench (and maybe barbell) at home.
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "goblet squat",
            style: .freeWeights,
            userEquipment: [.homeWeights]
        ))
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "Dumbbell Bench Press",
            style: .freeWeights,
            userEquipment: [.homeWeights]
        ))
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "pullup",
            style: .hybrid,
            userEquipment: [.homeWeights]
        ))
        // Machine/cable work should fail — no gym.
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "lat pulldown",
            style: .freeWeights,
            userEquipment: [.homeWeights]
        ))
    }

    func testBodyweightOnlyUserRejectsBarbellAndMachine() {
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "push-up",
            style: .bodyweight,
            userEquipment: [.bodyweight]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat",
            style: .bodyweight,
            userEquipment: [.bodyweight]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "lat pulldown",
            style: .bodyweight,
            userEquipment: [.bodyweight]
        ))
    }

    func testBandsUserRejectsCatalogMovementsThatRequireStationsOrWeights() {
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "pullup",
            style: .hybrid,
            userEquipment: [.bands]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "face pull",
            style: .hybrid,
            userEquipment: [.bands]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat",
            style: .hybrid,
            userEquipment: [.bands]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "leg press",
            style: .hybrid,
            userEquipment: [.bands]
        ))
    }

    // MARK: - Granular chip cases

    func testBarbellOnlyUserAcceptsBarbellAndBodyweight() {
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat", style: .freeWeights,
            userEquipment: [.barbell]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "Dumbbell Bench Press", style: .freeWeights,
            userEquipment: [.barbell]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "pullup", style: .freeWeights,
            userEquipment: [.barbell]
        ))
    }

    func testMachinesUserAcceptsMachines() {
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "lat pulldown", style: .machines,
            userEquipment: [.machines]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat", style: .machines,
            userEquipment: [.machines]
        ))
    }

    func testBenchAndDumbbellsCombination() {
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "Dumbbell Bench Press", style: .freeWeights,
            userEquipment: [.dumbbells, .bench]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat", style: .freeWeights,
            userEquipment: [.dumbbells, .bench]
        ))
    }

    func testPullupBarUserGetsBodyweightOnly() {
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "pullup", style: .bodyweight,
            userEquipment: [.pullupBar, .bodyweight]
        ))
        XCTAssertFalse(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "back squat", style: .bodyweight,
            userEquipment: [.pullupBar, .bodyweight]
        ))
    }

    func testCompatibilityFacadeMatchesMovementCatalogForSavedNameForms() {
        let names = [
            "Lat Pulldown (Neutral)",
            "lat_pulldown_neutral",
            "cable row",
            "cable_row_seated"
        ]

        for name in names {
            guard let definition = MovementCatalog.canonicalExercise(named: name) else {
                return XCTFail("Expected \(name) to resolve through MovementCatalog.")
            }

            XCTAssertEqual(
                ExerciseEquipmentClassifier.isCompatible(
                    exerciseName: name,
                    style: .machines,
                    userEquipment: [.machines]
                ),
                MovementCatalog.isProgramCompatible(
                    definition,
                    style: .machines,
                    userEquipment: [.machines]
                ),
                "\(name) should delegate compatibility to MovementCatalog."
            )
        }
    }
}
