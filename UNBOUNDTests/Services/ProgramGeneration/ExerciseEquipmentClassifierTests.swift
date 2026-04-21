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
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("dumbbell press"), .dumbbell)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("db row"), .dumbbell)
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
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("handstand pushup"), .bodyweight)
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("bodyweight squat"), .bodyweight)
    }

    func testUnknownDefaultsToDumbbell() {
        // Anything that doesn't match a keyword should default to the
        // middle-ground category (dumbbell) — safest assumption.
        XCTAssertEqual(ExerciseEquipmentClassifier.classify("face pull"), .dumbbell)
    }

    // MARK: - User-equipment compatibility
    // Equipment enum at this point in the codebase has 4 cases:
    // .fullGym, .homeWeights, .bodyweight, .bands

    func testBodyweightStyleRejectsNonBodyweight() {
        // Bodyweight-style users must never be prescribed barbell/machine work
        // even if their equipment chips would technically allow it.
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "pullup",
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
            exerciseName: "dumbbell press",
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
            exerciseName: "dumbbell press",
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
            exerciseName: "pullup",
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

    func testBandsUserAcceptsBodyweightAndDumbbellAccessoriesButNotBarbellOrMachine() {
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
            exerciseName: "pullup",
            style: .hybrid,
            userEquipment: [.bands]
        ))
        XCTAssertTrue(ExerciseEquipmentClassifier.isCompatible(
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
}
