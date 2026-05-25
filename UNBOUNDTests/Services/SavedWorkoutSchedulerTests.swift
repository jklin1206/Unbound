import XCTest
@testable import UNBOUND

final class SavedWorkoutSchedulerTests: XCTestCase {
    func testScheduleSavedWorkoutReplacesGeneratedDayAndMarksOwnership() throws {
        let program = makeProgram()
        let saved = makeSavedWorkout(role: "pull")

        let updated = try SavedWorkoutScheduler.schedule(
            saved,
            on: [2],
            in: program,
            userId: "u1"
        )

        let day = try XCTUnwrap(updated.days.first { $0.dayNumber == 2 })
        XCTAssertEqual(day.label, "My Pull A")
        XCTAssertFalse(day.isRestDay)
        XCTAssertEqual(day.savedWorkoutId, saved.id)
        XCTAssertEqual(day.sessionRole, .pull)
        XCTAssertEqual(day.workout?.mainExercises.map(\.name), ["Pull-Up", "Machine Row"])
    }

    func testScheduleRejectsCustomizedCollisionUnlessExplicitlyReplacing() throws {
        let saved = makeSavedWorkout(role: "push")
        var program = try SavedWorkoutScheduler.schedule(
            makeSavedWorkout(role: "pull"),
            on: [1],
            in: makeProgram(),
            userId: "u1"
        )

        XCTAssertThrowsError(
            try SavedWorkoutScheduler.schedule(saved, on: [1], in: program, userId: "u1")
        ) { error in
            XCTAssertEqual(error as? SavedWorkoutScheduler.ScheduleError, .customizedDayCollision(1))
        }

        program = try SavedWorkoutScheduler.schedule(
            saved,
            on: [1],
            in: program,
            userId: "u1",
            replacingCustomizedDays: true
        )

        XCTAssertEqual(program.days.first?.savedWorkoutId, saved.id)
        XCTAssertEqual(program.days.first?.sessionRole, .push)
    }

    func testUnscheduleClearsSavedWorkoutOwnershipWhenNoFallbackProvided() throws {
        let saved = makeSavedWorkout(role: "pull")
        let scheduled = try SavedWorkoutScheduler.schedule(
            saved,
            on: [1],
            in: makeProgram(),
            userId: "u1"
        )

        let unscheduled = try SavedWorkoutScheduler.unschedule(dayNumber: 1, in: scheduled)

        XCTAssertNil(unscheduled.days.first?.savedWorkoutId)
        XCTAssertNotNil(unscheduled.days.first?.workout)
    }

    private func makeProgram() -> TrainingProgram {
        let days = (1...3).map { day -> ProgramDay in
            ProgramDay(
                id: "d\(day)",
                dayNumber: day,
                label: "Generated \(day)",
                isRestDay: false,
                workout: Workout(
                    name: "Generated \(day)",
                    targetMuscleGroups: [.chest],
                    warmup: [],
                    mainExercises: [
                        Exercise(
                            id: "bench-\(day)",
                            name: "Bench Press",
                            muscleGroups: [.chest],
                            sets: 3,
                            reps: "8-10",
                            restSeconds: 90
                        )
                    ],
                    cooldown: [],
                    estimatedMinutes: 45,
                    notes: nil,
                    blockType: .accumulation
                ),
                sessionRole: .push,
                nutritionOverride: nil,
                recoveryActivities: []
            )
        }

        return TrainingProgram(
            id: "p1",
            scanId: "s1",
            analysisId: "a1",
            userId: "u1",
            createdAt: Date(timeIntervalSince1970: 0),
            name: "Arc",
            description: "Test",
            durationDays: 28,
            days: days,
            nutritionPlan: NutritionPlan(
                dailyCalories: 2200,
                proteinGrams: 160,
                carbsGrams: 240,
                fatGrams: 70,
                mealCount: 4,
                meals: [],
                hydrationLiters: 3,
                supplements: [],
                notes: "",
                restDayCalories: 2000,
                restDayProteinGrams: 160,
                restDayCarbsGrams: 200,
                restDayFatGrams: 70
            ),
            recoveryPlan: RecoveryPlan(
                sleepHoursTarget: 8,
                restDaysPerWeek: 2,
                activities: [],
                notes: ""
            ),
            difficultyLevel: .intermediate,
            requiredEquipment: [],
            estimatedDailyMinutes: 45
        )
    }

    private func makeSavedWorkout(role: String) -> SavedWorkout {
        let block = TrainingBlock(
            kind: .strength,
            title: "My Pull A",
            prescriptions: [
                TrainingBlockPrescription(
                    exerciseName: "Pull-Up",
                    sets: 3,
                    target: .repsRange(6, 8),
                    restSeconds: 120,
                    muscleGroups: [.back, .lats]
                ),
                TrainingBlockPrescription(
                    exerciseName: "Machine Row",
                    sets: 3,
                    target: .repsRange(8, 10),
                    restSeconds: 90,
                    muscleGroups: [.back]
                )
            ]
        )

        return SavedWorkout(
            id: role == "push"
                ? UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
                : UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: role == "push" ? "My Push A" : "My Pull A",
            blocks: [block],
            sessionRole: role
        )
    }
}
