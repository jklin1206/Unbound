import XCTest
@testable import UNBOUND

// MIGRATION (Phase 2e): ProgramGeneratorInput.archetype replaced by buildIdentity.

final class DeterministicProgramGeneratorTests: XCTestCase {

    func testGeneratesExactlyTwentyEightDaysForStandardReadyArc() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        XCTAssertEqual(program.days.count, 28)
    }

    func testTrainingDayCountMatchesFourTrainingWeeks() throws {
        let days: Set<Weekday> = [.monday, .wednesday, .friday]
        let input = makeInput(frequency: .three, trainingDays: days)
        let program = try DeterministicProgramGenerator.generate(input: input)
        let trainingCount = program.days.filter { !$0.isRestDay }.count
        XCTAssertEqual(trainingCount, 12) // 3/wk x 4 weeks
    }

    func testRestDaysHaveNoWorkout() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        for day in program.days where day.isRestDay {
            XCTAssertNil(day.workout)
        }
    }

    func testTrainingDaysHaveWorkoutWithMainExercises() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        let trainingDays = program.days.filter { !$0.isRestDay }
        for day in trainingDays {
            XCTAssertNotNil(day.workout, "day \(day.dayNumber) should have a workout")
            XCTAssertFalse(day.workout?.mainExercises.isEmpty ?? true,
                           "day \(day.dayNumber) mainExercises should not be empty")
        }
    }

    func testDurationDaysIsTwentyEight() throws {
        let input = makeInput(frequency: .three, trainingDays: [.monday, .wednesday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        XCTAssertEqual(program.durationDays, 28)
        XCTAssertEqual(program.currentArc?.currentWave(asOf: input.blockStartDate), .wave1)
        XCTAssertEqual(program.currentArc?.currentWave(asOf: input.blockStartDate.addingTimeInterval(14 * 86_400)), .wave2)
    }

    func testCalibrationWeekGeneratesSevenDayLearningProgram() throws {
        var input = makeInput(
            frequency: .three,
            trainingDays: [.tuesday, .thursday, .saturday]
        )
        input.calibration = .learningWeek()

        let program = try DeterministicProgramGenerator.generate(input: input)

        XCTAssertEqual(program.name, "Calibration Week")
        XCTAssertEqual(program.durationDays, 7)
        XCTAssertEqual(program.days.count, 7)
        XCTAssertTrue(program.rationale?.headline.localizedCaseInsensitiveContains("calibration") == true)

        let workouts = program.days.compactMap(\.workout)
        XCTAssertEqual(workouts.count, 3)
        XCTAssertTrue(workouts.allSatisfy { $0.name.localizedCaseInsensitiveContains("Calibration") })
    }

    func testCalibrationExercisesAreConservativeAndExplainTheStandard() throws {
        var input = makeInput(
            frequency: .three,
            trainingDays: [.tuesday, .thursday, .saturday]
        )
        input.calibration = .learningWeek()

        let program = try DeterministicProgramGenerator.generate(input: input)
        let exercises = program.days.compactMap(\.workout).flatMap(\.mainExercises)

        XCTAssertFalse(exercises.isEmpty)
        XCTAssertTrue(exercises.allSatisfy { ($0.rpe ?? 0) <= 7 })
        XCTAssertTrue(exercises.allSatisfy { $0.sets <= 2 })
        XCTAssertTrue(exercises.allSatisfy {
            $0.notes?.localizedCaseInsensitiveContains("Calibration set") == true
        })
    }

    func testStandardReadyInputDoesNotStartWithCalibration() throws {
        var input = makeInput(
            frequency: .three,
            trainingDays: [.tuesday, .thursday, .saturday]
        )
        input.calibration = .standardReady(knownExerciseKeys: ["pushup", "pullup"])

        let program = try DeterministicProgramGenerator.generate(input: input)

        XCTAssertEqual(program.durationDays, 28)
        XCTAssertFalse(program.name.localizedCaseInsensitiveContains("Calibration"))
        XCTAssertFalse(program.days.compactMap(\.workout).contains {
            $0.name.localizedCaseInsensitiveContains("Calibration")
        })
    }

    func testStandardReadyProgramCreatesCurrentArcMetadata() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])

        let program = try DeterministicProgramGenerator.generate(input: input)

        XCTAssertEqual(program.arcs.count, 1)
        XCTAssertEqual(program.currentArc?.programId, program.id)
        XCTAssertEqual(program.currentArc?.startDate, input.blockStartDate)
        XCTAssertEqual(program.currentArc?.endDate, input.blockStartDate.addingTimeInterval(28 * 86_400))
        XCTAssertEqual(program.currentArc?.wave1Range, 1...14)
        XCTAssertEqual(program.currentArc?.wave2Range, 15...28)
    }

    func testGeneratedDaysCarrySessionRoles() throws {
        let input = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )

        let program = try DeterministicProgramGenerator.generate(input: input)
        let trainingRoles = program.days.filter { !$0.isRestDay }.map(\.sessionRole)
        let restRoles = program.days.filter(\.isRestDay).map(\.sessionRole)

        XCTAssertTrue(trainingRoles.contains(.push))
        XCTAssertTrue(trainingRoles.contains(.pull))
        XCTAssertTrue(trainingRoles.contains(.legs))
        XCTAssertTrue(restRoles.allSatisfy { $0 == .rest })
    }

    func testCutModeShiftsNutrition() throws {
        var maintenance = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        maintenance.cutModeActive = false
        var cut = maintenance
        cut.cutModeActive = true

        let maintenanceProg = try DeterministicProgramGenerator.generate(input: maintenance)
        let cutProg = try DeterministicProgramGenerator.generate(input: cut)
        XCTAssertLessThan(cutProg.nutritionPlan.dailyCalories, maintenanceProg.nutritionPlan.dailyCalories)
    }

    func testWeakPointBiasInfluencesDayLabel() throws {
        var input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        input.focusAreas = [
            FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "narrow", suggestedFocus: "side delts")
        ]
        let program = try DeterministicProgramGenerator.generate(input: input)
        let labels = program.days.map(\.label).joined(separator: " | ")
        // At least one training day's label should mention shoulders (via bias naming).
        XCTAssertTrue(labels.lowercased().contains("shoulder"),
                      "At least one day's label should reference shoulders; got: \(labels)")
    }

    func testBodyweightUserHasNoBarbellExercises() throws {
        var input = makeInput(frequency: .three, trainingDays: [.monday, .wednesday, .friday])
        input.trainingStyle = .bodyweight
        input.equipment = [.bodyweight]
        let program = try DeterministicProgramGenerator.generate(input: input)
        let allNames = program.days
            .compactMap { $0.workout }
            .flatMap { $0.mainExercises }
            .map { $0.name.lowercased() }
        for name in allNames {
            XCTAssertFalse(name.contains("barbell"),
                           "Bodyweight user shouldn't have a barbell exercise; saw \(name)")
            XCTAssertFalse(name.contains("back squat"),
                           "Bodyweight user shouldn't get back squat; saw \(name)")
            XCTAssertFalse(name.contains("deadlift"),
                           "Bodyweight user shouldn't get deadlift; saw \(name)")
        }
    }

    func testGeneratedExercisesRespectStructuredEquipmentCompatibility() throws {
        let input = makeInput(
            frequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .machines,
            equipment: [.machines]
        )

        let program = try DeterministicProgramGenerator.generate(input: input)
        let exercises = program.days.compactMap(\.workout).flatMap(\.mainExercises)
        XCTAssertFalse(exercises.isEmpty)
        XCTAssertTrue(exercises.allSatisfy { exercise in
            guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else { return false }
            return MovementCatalog.isProgramCompatible(definition, style: .machines, userEquipment: [.machines])
        })
        XCTAssertFalse(exercises.contains { $0.name.localizedCaseInsensitiveContains("Barbell") })
    }

    func testPullTemplateOnlyUsesPullMovementSlots() throws {
        let input = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )

        let program = try DeterministicProgramGenerator.generate(input: input)
        let pullExercises = program.days
            .filter { $0.label == "Pull" }
            .compactMap(\.workout)
            .flatMap(\.mainExercises)

        XCTAssertFalse(pullExercises.isEmpty)
        for exercise in pullExercises {
            guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else {
                return XCTFail("Expected \(exercise.name) to resolve through MovementCatalog.")
            }
            XCTAssertTrue(
                [.horizontalPull, .verticalPull].contains(definition.movementSlot),
                "\(exercise.name) should stay in a pull slot, got \(definition.movementSlot)."
            )
        }
    }

    func testGeneratedExercisesHonorAvoidAndSubstitutePreferences() throws {
        var input = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )

        let baseline = try DeterministicProgramGenerator.generate(input: input)
        let baselineNames = baseline.days.compactMap(\.workout).flatMap(\.mainExercises).map(\.name)
        guard let originalName = baselineNames.first(where: {
            MovementCatalog.canonicalExercise(named: $0)?.movementSlot == .horizontalPush
        }),
        let original = MovementCatalog.canonicalExercise(named: originalName),
        let replacement = MovementCatalog.programAlternatives(
            to: originalName,
            style: .freeWeights,
            userEquipment: [.fullGym]
        ).first
        else {
            return XCTFail("Expected a substitutable horizontal-push movement in the generated program.")
        }

        input.exercisePreferences = [
            ExercisePreference(
                id: "u-1:\(original.canonicalExerciseName ?? original.displayName)",
                userId: "u-1",
                exerciseName: original.canonicalExerciseName ?? original.displayName,
                displayName: original.displayName,
                status: .substitute,
                muscleGroups: original.muscleGroups,
                substitutePreference: replacement.canonicalExerciseName ?? replacement.displayName,
                notes: nil,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ]

        let program = try DeterministicProgramGenerator.generate(input: input)
        let names = program.days.compactMap(\.workout).flatMap(\.mainExercises).map(\.name)
        XCTAssertFalse(names.contains(original.displayName))
        XCTAssertTrue(names.contains(replacement.displayName))
    }

    func testProgressionStateFeedsGeneratedPrescriptionRPEAndRepRange() throws {
        var input = makeInput(
            frequency: .three,
            trainingDays: [.tuesday, .thursday, .saturday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )
        let baseline = try DeterministicProgramGenerator.generate(input: input)
        guard let seededExercise = baseline.days
            .compactMap(\.workout)
            .flatMap(\.mainExercises)
            .first,
              let definition = MovementCatalog.canonicalExercise(named: seededExercise.name)
        else {
            return XCTFail("Expected a generated exercise to seed.")
        }

        let state = ProgressionState.seed(
            userId: "u-1",
            exercise: definition.canonicalExerciseName ?? definition.displayName,
            startingWeightKg: 80,
            block: .intensification
        )
        input.progressionStates = [
            MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName): state
        ]

        let program = try DeterministicProgramGenerator.generate(input: input)
        let adjusted = program.days
            .compactMap(\.workout)
            .flatMap(\.mainExercises)
            .first { $0.name == seededExercise.name }

        XCTAssertEqual(adjusted?.reps, "6-8")
        XCTAssertEqual(adjusted?.rpe, 8)
    }

    // MARK: — helper

    // MIGRATION: was archetype: .shredded — now control specialist (equivalent calisthenic identity)
    private func makeInput(
        frequency: TargetFrequency,
        trainingDays: Set<Weekday>,
        buildIdentity: BuildIdentity = BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
        trainingStyle: TrainingStyle = .bodyweight,
        equipment: [Equipment] = [.bodyweight]
    ) -> ProgramGeneratorInput {
        ProgramGeneratorInput(
            userId: "u-1",
            scanId: "s-1",
            analysisId: "a-1",
            buildIdentity: buildIdentity,
            trainingStyle: trainingStyle,
            equipment: equipment,
            targetFrequency: frequency,
            trainingDays: trainingDays,
            experience: .current,
            focusAreas: [],
            cutModeActive: false,
            trainingFeedbackMode: .quick,
            progressionStates: [:],
            previousBlock: nil,
            weightKg: 75,
            heightCm: 178,
            age: 24,
            sex: .male,
            blockStartDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
