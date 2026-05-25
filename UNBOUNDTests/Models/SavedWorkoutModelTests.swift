import XCTest
@testable import UNBOUND

final class SavedWorkoutModelTests: XCTestCase {
    func testFactoryFromWorkoutPreservesPrescriptionTargetsAndInfersRole() {
        let workout = Workout(
            name: "Pull Day A",
            targetMuscleGroups: [.back, .arms],
            warmup: [],
            mainExercises: [
                Exercise(
                    id: "pull-up-slot",
                    name: "Pull-Up",
                    muscleGroups: [.back, .arms],
                    sets: 3,
                    reps: "6-8",
                    restSeconds: 120,
                    rpe: 8,
                    notes: "Strict reps.",
                    substitution: nil
                )
            ],
            cooldown: [],
            estimatedMinutes: 45,
            notes: nil,
            blockType: nil
        )

        let saved = SavedWorkout.from(workout, now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(saved.title, "Pull Day A")
        XCTAssertEqual(saved.sessionRole, "pull")
        XCTAssertEqual(saved.blocks.count, 1)
        XCTAssertEqual(saved.blocks.first?.prescriptions.first?.exerciseName, "Pull-Up")
        XCTAssertEqual(saved.blocks.first?.prescriptions.first?.sets, 3)
        XCTAssertEqual(saved.blocks.first?.prescriptions.first?.target.displayText, "6-8 reps")
        XCTAssertEqual(saved.blocks.first?.prescriptions.first?.rpe, 8)
    }

    func testFactoryFromDraftCanRehydrateCustomDraft() {
        let draft = TrainingSessionDraft(
            userId: "u-1",
            source: .program,
            title: "Upper Template",
            estimatedMinutes: 42,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Upper",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Bench Press",
                            sets: 4,
                            target: .repsRange(5, 8),
                            restSeconds: 150,
                            muscleGroups: [.chest, .shoulders],
                            rpe: 8
                        )
                    ]
                )
            ]
        )

        let saved = SavedWorkout.from(draft, title: "My Upper A", sessionRole: "Upper")
        let rehydrated = saved.asDraft(userId: "u-2", dayNumber: 12)

        XCTAssertEqual(saved.sessionRole, "upper")
        XCTAssertEqual(rehydrated.userId, "u-2")
        XCTAssertEqual(rehydrated.source, .custom)
        XCTAssertEqual(rehydrated.title, "My Upper A")
        XCTAssertEqual(rehydrated.dayNumber, 12)
        XCTAssertEqual(rehydrated.blocks.first?.prescriptions.first?.exerciseName, "Bench Press")
    }

    func testEquatableOnlyUsesID() {
        let id = UUID()
        let lhs = SavedWorkout(id: id, title: "Push A", blocks: [], sessionRole: "push")
        let rhs = SavedWorkout(id: id, title: "Renamed Push", blocks: [], sessionRole: "legs")

        XCTAssertEqual(lhs, rhs)
    }

    func testABRotationGuardAllowsOnlyMatchingRoles() {
        let pushA = SavedWorkout(title: "Push A", blocks: [], sessionRole: "push")
        let pushB = SavedWorkout(title: "Push B", blocks: [], sessionRole: "Push")
        let legs = SavedWorkout(title: "Legs A", blocks: [], sessionRole: "legs")

        XCTAssertTrue(ABRotationGuard.canPair(pushA, with: pushB))
        let rejected = ABRotationGuard.validate(pushA, with: legs)
        XCTAssertFalse(rejected.canPair)
        XCTAssertEqual(rejected.reason, .differentRole("push", "legs"))
    }
}
