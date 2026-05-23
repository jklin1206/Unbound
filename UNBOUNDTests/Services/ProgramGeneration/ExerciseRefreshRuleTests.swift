import XCTest
@testable import UNBOUND

final class ExerciseRefreshRuleTests: XCTestCase {

    // MARK: shouldRotate

    func testDoesNotRotateBelowThreeConsecutive() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 0,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 2,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
    }

    func testRotatesAtThreeConsecutive() {
        XCTAssertTrue(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 3,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
    }

    func testRotatesBeyondThree() {
        XCTAssertTrue(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 7,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )))
    }

    func testTierUnlockPreventsRotation() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "pullup",
            consecutiveBlocksPrescribed: 5,
            hadTierUnlock: true,
            hadPlateauDeload: false
        )))
    }

    func testPlateauDeloadPreventsRotation() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 5,
            hadTierUnlock: false,
            hadPlateauDeload: true
        )))
    }

    func testBothSignalsPreventRotation() {
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: .init(
            exerciseKey: "bench press",
            consecutiveBlocksPrescribed: 10,
            hadTierUnlock: true,
            hadPlateauDeload: true
        )))
    }

    // MARK: alternative(for:in:)

    func testAlternativeFromSameProgressionFamily() {
        let a = CatalogExercise(
            name: "barbell row",
            displayName: "Barbell Row",
            muscleGroups: [.back, .lats],
            defaultSubstitute: nil,
            progressionFamily: "pull-h",
            progressionTier: 1
        )
        let sibling = CatalogExercise(
            name: "pendlay row",
            displayName: "Pendlay Row",
            muscleGroups: [.back, .lats],
            defaultSubstitute: nil,
            progressionFamily: "pull-h",
            progressionTier: 2
        )
        let unrelated = CatalogExercise(
            name: "curl",
            displayName: "Curl",
            muscleGroups: [.arms],
            defaultSubstitute: nil
        )
        let pool = [a, sibling, unrelated]
        let alt = ExerciseRefreshRule.alternative(for: a, in: pool)
        XCTAssertEqual(alt?.name, "pendlay row")
    }

    func testAlternativeFallsBackToSameMuscleGroups() {
        let a = CatalogExercise(
            name: "face pull",
            displayName: "Face Pull",
            muscleGroups: [.shoulders, .back],
            defaultSubstitute: nil
        )
        let sibling = CatalogExercise(
            name: "rear delt fly",
            displayName: "Rear Delt Fly",
            muscleGroups: [.shoulders, .back],
            defaultSubstitute: nil
        )
        let differentGroups = CatalogExercise(
            name: "curl",
            displayName: "Curl",
            muscleGroups: [.arms],
            defaultSubstitute: nil
        )
        let alt = ExerciseRefreshRule.alternative(for: a, in: [a, sibling, differentGroups])
        XCTAssertEqual(alt?.name, "rear delt fly")
    }

    func testAlternativeReturnsNilWhenNoMatch() {
        let a = CatalogExercise(
            name: "unique-move",
            displayName: "Unique Move",
            muscleGroups: [.forearms],
            defaultSubstitute: nil,
            progressionFamily: "forearm-lever",
            progressionTier: 1
        )
        // Pool contains only `a` itself and unrelated exercises with different
        // family AND different muscle groups.
        let unrelated = CatalogExercise(
            name: "curl",
            displayName: "Curl",
            muscleGroups: [.arms],
            defaultSubstitute: nil
        )
        let alt = ExerciseRefreshRule.alternative(for: a, in: [a, unrelated])
        XCTAssertNil(alt)
    }
}
