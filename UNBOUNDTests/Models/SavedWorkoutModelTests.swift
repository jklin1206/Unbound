import XCTest
@testable import UNBOUND

final class SavedWorkoutModelTests: XCTestCase {
    func testFactoryFromWorkoutPreservesPrescriptionTargetsAndInfersRole() {
        let workout = Workout(
            name: "Pull Day A",
            targetMuscleGroups: [.back, .biceps],
            warmup: [],
            mainExercises: [
                Exercise(
                    id: "pull-up-slot",
                    name: "Pull-Up",
                    muscleGroups: [.back, .biceps],
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
        XCTAssertEqual(saved.blocks.first?.prescriptions.first?.target.displayText, "6 reps")
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

    func testEffectiveReferenceExerciseUsesFirstMainExercise() {
        var draft = TrainingSessionDraft(
            userId: "u-1",
            source: .custom,
            title: "Pull Template",
            estimatedMinutes: 35,
            referenceExerciseName: "Ring Row",
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Pull",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Pull-Up",
                            sets: 3,
                            target: .repsRange(5, 8),
                            restSeconds: 120,
                            muscleGroups: [.back],
                            rpe: 8
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Ring Row",
                            sets: 3,
                            target: .repsRange(8, 12),
                            restSeconds: 75,
                            muscleGroups: [.back, .biceps],
                            rpe: 7
                        )
                    ]
                )
            ]
        )

        let saved = SavedWorkout.from(draft)
        let rehydrated = saved.asDraft(userId: "u-2")

        XCTAssertEqual(saved.referenceExerciseName, "Ring Row")
        XCTAssertEqual(saved.effectiveReferenceExerciseName, "Pull-Up")
        XCTAssertEqual(rehydrated.referenceExerciseName, "Ring Row")
        XCTAssertEqual(rehydrated.effectiveReferenceExerciseName, "Pull-Up")

        draft.referenceExerciseName = "Exercise That Was Removed"
        draft.normalizeReferenceExerciseName()
        XCTAssertNil(draft.referenceExerciseName)
        XCTAssertEqual(draft.effectiveReferenceExerciseName, "Pull-Up")
    }

    func testEffectiveReferenceExerciseSkipsWarmupBlocks() {
        let draft = TrainingSessionDraft(
            userId: "u-1",
            source: .program,
            title: "Push Day",
            estimatedMinutes: 44,
            blocks: [
                TrainingBlock(
                    kind: .bodyweight,
                    title: "Warmup",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Shoulder Opener",
                            sets: 1,
                            target: .timedSeconds(45),
                            restSeconds: 20
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .strength,
                    title: "Main",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Pike Push-Up",
                            sets: 4,
                            target: .repsRange(5, 8),
                            restSeconds: 120
                        )
                    ]
                )
            ]
        )

        XCTAssertEqual(draft.effectiveReferenceExerciseName, "Pike Push-Up")
    }

    func testPrescriptionSetPlansSupportWarmupsBackoffsAndDropsets() {
        var prescription = TrainingBlockPrescription(
            exerciseName: "Squat",
            sets: 3,
            target: .reps(5),
            restSeconds: 180,
            rpe: 8,
            suggestedWeightKg: 140
        )

        prescription.materializeSetPlans()
        var plans = prescription.setPlans ?? []
        plans[0].isWarmup = true
        plans[0].target = .reps(3)
        plans[0].suggestedWeightKg = 100
        plans[1].target = .reps(5)
        plans[1].suggestedWeightKg = 140
        plans[2].target = .reps(10)
        plans[2].restSeconds = 45
        plans[2].rpe = 9
        plans[2].suggestedWeightKg = 100
        prescription.setPlans = plans
        prescription.syncSummaryFromSetPlans()

        XCTAssertEqual(prescription.plannedSetCount, 3)
        XCTAssertEqual(prescription.sets, 3)
        XCTAssertEqual(prescription.displayTargetText, "Custom set plan")
        XCTAssertEqual(prescription.setPlanSummaryText, "custom sets")
        XCTAssertEqual(prescription.effectiveSetPlans.map(\.target.displayText), ["3 reps", "5 reps", "10 reps"])
        XCTAssertEqual(prescription.effectiveSetPlans.map(\.restSeconds), [180, 180, 45])
        XCTAssertEqual(prescription.effectiveSetPlans.map(\.suggestedWeightKg), [100, 140, 100])
        XCTAssertTrue(prescription.effectiveSetPlans[0].isWarmup)

        prescription.addSetPlan()
        XCTAssertEqual(prescription.plannedSetCount, 4)
        XCTAssertEqual(prescription.effectiveSetPlans[3].target.displayText, "10 reps")
        XCTAssertEqual(prescription.effectiveSetPlans[3].restSeconds, 45)

        prescription.removeSetPlan(at: 3)
        XCTAssertEqual(prescription.plannedSetCount, 3)
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
