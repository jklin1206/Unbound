import XCTest
@testable import UNBOUND

final class SessionRoleTaggerTests: XCTestCase {
    func testCanonicalSplitsMapFromTitle() {
        XCTAssertEqual(SessionRoleTagger.role(title: "Push A", muscleGroups: []), .push)
        XCTAssertEqual(SessionRoleTagger.role(title: "Pull B", muscleGroups: []), .pull)
        XCTAssertEqual(SessionRoleTagger.role(title: "Upper", muscleGroups: []), .upper)
        XCTAssertEqual(SessionRoleTagger.role(title: "Full Body", muscleGroups: []), .fullBody)
        XCTAssertEqual(SessionRoleTagger.role(title: "Bro Chest", muscleGroups: []), .broChest)
    }

    func testMuscleGroupInferenceCatchesInvalidRotationCandidate() {
        let push = SessionRoleTagger.role(title: "Training", muscleGroups: [.chest, .shoulders, .arms])
        let pull = SessionRoleTagger.role(title: "Training", muscleGroups: [.back, .lats])

        XCTAssertEqual(push, .push)
        XCTAssertEqual(pull, .pull)
        XCTAssertFalse(SessionRoleTagger.rolesMatchForRotation(push, pull))
    }

    func testWorkoutRoleUsesExerciseContent() {
        let workout = Workout(
            name: "Generated",
            targetMuscleGroups: [],
            warmup: [],
            mainExercises: [
                Exercise(
                    id: "row",
                    name: "Machine Row",
                    muscleGroups: [.back, .lats],
                    sets: 3,
                    reps: "8-10",
                    restSeconds: 90
                )
            ],
            cooldown: [],
            estimatedMinutes: 45,
            notes: nil,
            blockType: .accumulation
        )

        XCTAssertEqual(SessionRoleTagger.role(for: workout), .pull)
    }
}
