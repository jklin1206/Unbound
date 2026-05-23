import XCTest
@testable import UNBOUND

final class ProgramSurfaceStateTests: XCTestCase {
    func testIdleLoadingAndErrorStatesResolveToActionableSurfaceStates() {
        XCTAssertEqual(ProgramSurfaceState.resolve(state: LoadingState<TrainingProgram>.idle).kind, .noProgram)
        XCTAssertEqual(ProgramSurfaceState.resolve(state: LoadingState<TrainingProgram>.loading).kind, .loading)

        let errorState = ProgramSurfaceState.resolve(
            state: LoadingState<TrainingProgram>.error(.networkNoConnection)
        )
        XCTAssertEqual(errorState.kind, .loadError)
        XCTAssertEqual(errorState.primaryActionTitle, "Retry")
        XCTAssertEqual(errorState.secondaryActionTitle, "Browse Routines")
    }

    func testLoadedProgramResolvesTrainingRestMissingAndBlockCompleteStates() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trainingProgram = program(
            createdAt: now,
            days: [
                day(number: 1, isRest: false),
                day(number: 2, isRest: true)
            ]
        )

        let training = ProgramSurfaceState.resolve(
            state: .loaded(trainingProgram),
            selectedDate: now,
            now: now
        )
        XCTAssertEqual(training.kind, .trainingDay)
        XCTAssertTrue(training.canStartWorkout)
        XCTAssertEqual(training.primaryActionTitle, "Begin Session")

        let rest = ProgramSurfaceState.resolve(
            state: .loaded(trainingProgram),
            selectedDate: now.addingTimeInterval(86_400),
            now: now
        )
        XCTAssertEqual(rest.kind, .restDay)
        XCTAssertFalse(rest.canStartWorkout)
        XCTAssertEqual(rest.primaryActionTitle, "View Recovery")
        XCTAssertEqual(rest.secondaryActionTitle, "Add Light Work")

        let missing = ProgramSurfaceState.resolve(
            state: .loaded(program(createdAt: now, days: [])),
            selectedDate: now,
            now: now
        )
        XCTAssertEqual(missing.kind, .missingDay)

        let complete = ProgramSurfaceState.resolve(
            state: .loaded(program(createdAt: now.addingTimeInterval(-14 * 86_400), days: [day(number: 1, isRest: false)])),
            selectedDate: now,
            now: now
        )
        XCTAssertEqual(complete.kind, .blockComplete)
        XCTAssertEqual(complete.primaryActionTitle, "Build Next Block")
    }

    func testProgramProofFixturesResolveToRequestedSurfaceStates() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            ProgramProofState.parse("REST-DAY"),
            .restDay
        )

        let training = ProgramProofProgramFactory.make(state: .trainingDay, userId: "u-1", now: now)
        XCTAssertEqual(
            ProgramSurfaceState.resolve(state: .loaded(training), selectedDate: now, now: now).kind,
            .trainingDay
        )

        let rest = ProgramProofProgramFactory.make(state: .restDay, userId: "u-1", now: now)
        XCTAssertEqual(
            ProgramSurfaceState.resolve(state: .loaded(rest), selectedDate: now, now: now).kind,
            .restDay
        )

        let missing = ProgramProofProgramFactory.make(state: .missingDay, userId: "u-1", now: now)
        XCTAssertEqual(
            ProgramSurfaceState.resolve(state: .loaded(missing), selectedDate: now, now: now).kind,
            .missingDay
        )

        let complete = ProgramProofProgramFactory.make(state: .blockComplete, userId: "u-1", now: now)
        XCTAssertEqual(
            ProgramSurfaceState.resolve(state: .loaded(complete), selectedDate: now, now: now).kind,
            .blockComplete
        )
    }

    func testProgramSurfaceProofOverridesParseAndResolveToRequestedStates() {
        XCTAssertEqual(
            ProgramSurfaceProofOverride.fromLaunchArguments(["app", "--unbound-proof-program-surface=load-error"]),
            .loadError
        )
        XCTAssertEqual(
            ProgramSurfaceProofOverride.fromLaunchArguments(["app", "--unbound-proof-program-surface", "no-program"]),
            .noProgram
        )

        XCTAssertEqual(
            ProgramSurfaceState.resolve(state: ProgramSurfaceProofOverride.noProgram.loadingState).kind,
            .noProgram
        )
        XCTAssertEqual(
            ProgramSurfaceState.resolve(state: ProgramSurfaceProofOverride.loading.loadingState).kind,
            .loading
        )
        XCTAssertEqual(
            ProgramSurfaceState.resolve(state: ProgramSurfaceProofOverride.loadError.loadingState).kind,
            .loadError
        )
    }

    private func program(createdAt: Date, days: [ProgramDay]) -> TrainingProgram {
        TrainingProgram(
            id: "p-1",
            scanId: "s-1",
            analysisId: "a-1",
            userId: "u-1",
            createdAt: createdAt,
            name: "Test",
            description: "Test program",
            durationDays: 14,
            days: days,
            nutritionPlan: NutritionPlan(
                dailyCalories: 2000,
                proteinGrams: 150,
                carbsGrams: 200,
                fatGrams: 60,
                mealCount: 4,
                meals: [],
                hydrationLiters: 3,
                supplements: [],
                notes: "",
                restDayCalories: 1800,
                restDayProteinGrams: 150,
                restDayCarbsGrams: 150,
                restDayFatGrams: 60
            ),
            recoveryPlan: RecoveryPlan(sleepHoursTarget: 8, restDaysPerWeek: 3, activities: [], notes: ""),
            difficultyLevel: .intermediate,
            requiredEquipment: [],
            estimatedDailyMinutes: 45,
            rationale: nil
        )
    }

    private func day(number: Int, isRest: Bool) -> ProgramDay {
        ProgramDay(
            id: "d-\(number)",
            dayNumber: number,
            label: isRest ? "Rest" : "Push",
            isRestDay: isRest,
            workout: isRest ? nil : Workout(
                name: "Push",
                targetMuscleGroups: [.chest],
                warmup: [],
                mainExercises: [
                    Exercise(
                        id: "pushup",
                        name: "Pushup",
                        muscleGroups: [.chest],
                        sets: 3,
                        reps: "8",
                        restSeconds: 90,
                        rpe: nil,
                        notes: nil,
                        substitution: nil
                    )
                ],
                cooldown: [],
                estimatedMinutes: 30,
                notes: nil,
                blockType: nil
            ),
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }
}
