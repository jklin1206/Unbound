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

    func testTrainingDaysIncludeRoleSpecificWarmups() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)

        for workout in program.days.compactMap(\.workout) {
            XCTAssertFalse(workout.warmup.isEmpty, "\(workout.name) should include prep work.")
            XCTAssertTrue(workout.warmup.allSatisfy { !$0.name.isEmpty && $0.sets > 0 })
        }
    }

    func testThirtyMinuteSessionLengthCompressesWorkoutBudget() throws {
        var input = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )
        input.sessionLengthMinutes = 30

        let program = try DeterministicProgramGenerator.generate(input: input)
        let workouts = program.days.compactMap(\.workout)

        XCTAssertEqual(program.estimatedDailyMinutes, 30)
        XCTAssertFalse(workouts.isEmpty)
        XCTAssertTrue(workouts.allSatisfy { $0.estimatedMinutes <= 30 })
        XCTAssertTrue(workouts.contains { $0.notes?.localizedCaseInsensitiveContains("compressed") == true })
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

    func testExerciseRotationsAvoidStaleMovementWhenAlternativeExists() throws {
        var input = makeInput(
            frequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )
        let baseline = try DeterministicProgramGenerator.generate(input: input)
        let baselineNames = baseline.days
            .compactMap(\.workout)
            .flatMap(\.mainExercises)
            .map(\.name)
        let staleName = try XCTUnwrap(baselineNames.first)
        let staleDefinition = try XCTUnwrap(MovementCatalog.canonicalExercise(named: staleName))

        input.exerciseRotationsToApply = [staleDefinition.canonicalExerciseName ?? staleName]
        let rotated = try DeterministicProgramGenerator.generate(input: input)
        let rotatedNames = rotated.days
            .compactMap(\.workout)
            .flatMap(\.mainExercises)
            .map(\.name)

        XCTAssertFalse(rotatedNames.contains(staleName))
        XCTAssertEqual(rotated.days.count, baseline.days.count)
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

final class YearProgramSimulationTests: XCTestCase {
    func testBaselineYearSimulationSmokeExportsDebugArtifacts() async throws {
        try await runYearSimulation(
            personas: [try XCTUnwrap(BaselineYearProgramSimulator.personas.first { $0.id == "home-bodyweight-beginner" })],
            label: "smoke-home-bodyweight-56-days",
            expectedPersonaCount: 1,
            simulationDays: BaselineYearProgramSimulator.smokeSimulationDays
        )
    }

    func testBaselineYearSimulationExportsAllPersonaArtifacts() async throws {
        try XCTSkipUnless(Self.fullYearTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_FULL_YEAR=1 to export the full 365-day all-persona artifact bundle.")
        try await runYearSimulation(
            personas: BaselineYearProgramSimulator.personas,
            label: "all-personas",
            expectedPersonaCount: BaselineYearProgramSimulator.personas.count,
            simulationDays: BaselineYearProgramSimulator.fullYearSimulationDays
        )
    }

    func testBaselineYearSimulationExportsHomeBodyweightBeginnerArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "home-bodyweight-beginner")
    }

    func testBaselineYearSimulationExportsHomeDumbbellBenchArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "home-dumbbell-bench")
    }

    func testBaselineYearSimulationExportsFullGymIntermediateArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "full-gym-intermediate")
    }

    func testBaselineYearSimulationExportsAdvancedStrengthArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "advanced-strength")
    }

    func testBaselineYearSimulationExportsAdvancedCalisthenicsArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "advanced-calisthenics")
    }

    func testBaselineYearSimulationExportsTravelInconsistentArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "travel-inconsistent")
    }

    func testBaselineYearSimulationExportsCutModeHybridArtifacts() async throws {
        try XCTSkipUnless(Self.shardTestsEnabled, "Set UNBOUND_YEAR_SIM_ENABLE_SHARDS=1 for individual 365-day persona artifact exports.")
        try await runYearSimulation(personaId: "cut-mode-hybrid")
    }

    private static var fullYearTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_ENABLE_FULL_YEAR"] == "1"
    }

    private static var shardTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_ENABLE_SHARDS"] == "1"
    }

    private func runYearSimulation(
        personaId: String,
        sourceFile: StaticString = #filePath,
        sourceLine: UInt = #line
    ) async throws {
        executionTimeAllowance = 120

        let persona = try XCTUnwrap(
            BaselineYearProgramSimulator.personas.first { $0.id == personaId },
            file: sourceFile,
            line: sourceLine
        )
        try await runYearSimulation(
            personas: [persona],
            label: personaId,
            expectedPersonaCount: 1,
            sourceFile: sourceFile,
            sourceLine: sourceLine
        )
    }

    private func runYearSimulation(
        personas: [YearSimulationPersona],
        label: String,
        expectedPersonaCount: Int,
        simulationDays: Int = BaselineYearProgramSimulator.fullYearSimulationDays,
        sourceFile: StaticString = #filePath,
        sourceLine: UInt = #line
    ) async throws {
        executionTimeAllowance = expectedPersonaCount > 1 ? 300 : 120

        let report = try await Task.detached(priority: .userInitiated) {
            let simulator = BaselineYearProgramSimulator(personas: personas, simulationDays: simulationDays)
            return try await simulator.run()
        }.value
        let outputURL = try BaselineYearSimulationArtifactWriter().write(report)
        print("UNBOUND_YEAR_SIM_OUTPUT=\(outputURL.path)")

        XCTAssertEqual(report.personaRuns.count, expectedPersonaCount)
        XCTAssertTrue(report.personaRuns.allSatisfy { $0.days.count == simulationDays })
        XCTAssertTrue(report.personaRuns.allSatisfy { !$0.programs.isEmpty })
        if simulationDays >= BaselineYearProgramSimulator.fullYearSimulationDays {
            let criticals = report.personaRuns.flatMap { run in
                run.violations.filter { $0.severity == .critical }
            }
            XCTAssertTrue(
                criticals.isEmpty,
                criticals.map { "\($0.code): \($0.detail)" }.joined(separator: "\n"),
                file: sourceFile,
                line: sourceLine
            )
        }

        await XCTContext.runActivity(named: "UNBOUND year simulation artifacts: \(label)") { activity in
            activity.add(XCTAttachment(string: outputURL.path))
        }
    }
}

private struct BaselineYearProgramSimulator {
    static let fullYearSimulationDays = 365
    static let smokeSimulationDays = 56

    static var defaultSimulationDays: Int {
        guard let rawValue = ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_DAYS"],
              let days = Int(rawValue),
              days > 0 else {
            return smokeSimulationDays
        }
        return days
    }

    static let personas: [YearSimulationPersona] = [
        YearSimulationPersona(
            id: "home-bodyweight-beginner",
            displayName: "Home Bodyweight Beginner",
            lens: "normal-user home training",
            buildIdentity: BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            targetFrequency: .three,
            trainingDays: [.monday, .wednesday, .friday],
            experience: .never,
            sessionLengthMinutes: 30,
            goals: ["buildMuscle", "getDefined"],
            obstacles: ["time", "consistency"],
            sleepQuality: 5,
            stressLevel: 6,
            commitment: 7,
            focusAreas: [
                FocusArea(muscleGroup: .chest, priority: 1, rationale: "Onboarding target", suggestedFocus: "Upper body density"),
                FocusArea(muscleGroup: .core, priority: 2, rationale: "Onboarding target", suggestedFocus: "Control")
            ],
            cutModeActive: false,
            adherence: .steady,
            simulatedCarryEveryNDays: 21
        ),
        YearSimulationPersona(
            id: "home-dumbbell-bench",
            displayName: "Home Dumbbell Bench User",
            lens: "home user with limited gear",
            buildIdentity: BuildIdentity(primary: .power, secondary: .control, shape: .hybrid),
            trainingStyle: .freeWeights,
            equipment: [.dumbbells, .bench, .pullupBar, .bodyweight],
            targetFrequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .saturday],
            experience: .tried,
            sessionLengthMinutes: 45,
            goals: ["getStronger", "athletic"],
            obstacles: ["unsure"],
            sleepQuality: 6,
            stressLevel: 5,
            commitment: 8,
            focusAreas: [
                FocusArea(muscleGroup: .back, priority: 1, rationale: "Onboarding target", suggestedFocus: "V taper"),
                FocusArea(muscleGroup: .shoulders, priority: 2, rationale: "Onboarding target", suggestedFocus: "Frame")
            ],
            cutModeActive: false,
            adherence: .steady
        ),
        YearSimulationPersona(
            id: "full-gym-intermediate",
            displayName: "Full Gym Intermediate",
            lens: "professional trainer baseline",
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
            trainingStyle: .freeWeights,
            equipment: [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .machines],
            targetFrequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            experience: .current,
            sessionLengthMinutes: 60,
            goals: ["buildMuscle", "getStronger", "athletic"],
            obstacles: ["plateau"],
            sleepQuality: 7,
            stressLevel: 4,
            commitment: 9,
            focusAreas: [
                FocusArea(muscleGroup: .legs, priority: 1, rationale: "Scan lag", suggestedFocus: "Lower body"),
                FocusArea(muscleGroup: .back, priority: 2, rationale: "Scan lag", suggestedFocus: "Back width")
            ],
            cutModeActive: false,
            adherence: .steady
        ),
        YearSimulationPersona(
            id: "advanced-strength",
            displayName: "Advanced Strength Athlete",
            lens: "elite-performance strength",
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
            trainingStyle: .freeWeights,
            equipment: [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .machines],
            targetFrequency: .six,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday],
            experience: .current,
            sessionLengthMinutes: 90,
            goals: ["getStronger", "athletic"],
            obstacles: ["plateau"],
            sleepQuality: 8,
            stressLevel: 5,
            commitment: 10,
            focusAreas: [
                FocusArea(muscleGroup: .legs, priority: 1, rationale: "Performance priority", suggestedFocus: "Squat/deadlift base"),
                FocusArea(muscleGroup: .glutes, priority: 2, rationale: "Performance priority", suggestedFocus: "Posterior chain")
            ],
            cutModeActive: false,
            adherence: .aggressive,
            simulatedCarryEveryNDays: 14
        ),
        YearSimulationPersona(
            id: "advanced-calisthenics",
            displayName: "Advanced Calisthenics Athlete",
            lens: "elite-performance skill",
            buildIdentity: BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight, .pullupBar, .bands],
            targetFrequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .friday, .saturday],
            experience: .current,
            sessionLengthMinutes: 60,
            goals: ["athletic", "getDefined"],
            obstacles: ["plateau"],
            sleepQuality: 7,
            stressLevel: 5,
            commitment: 9,
            focusAreas: [
                FocusArea(muscleGroup: .core, priority: 1, rationale: "Skill target", suggestedFocus: "Lever/planche control"),
                FocusArea(muscleGroup: .shoulders, priority: 2, rationale: "Skill target", suggestedFocus: "Vertical push")
            ],
            cutModeActive: false,
            adherence: .steady,
            simulatedSkillIds: ["hs.wall-handstand-30", "pl.tuck-planche"]
        ),
        YearSimulationPersona(
            id: "travel-inconsistent",
            displayName: "Travel Inconsistent User",
            lens: "adherence stress test",
            buildIdentity: BuildIdentity(primary: .endurance, secondary: .power, shape: .hybrid),
            trainingStyle: .hybrid,
            equipment: [.fullGym, .dumbbells, .bench, .pullupBar, .bodyweight, .bands],
            targetFrequency: .four,
            trainingDays: [.monday, .wednesday, .friday, .sunday],
            experience: .used,
            sessionLengthMinutes: 45,
            goals: ["athletic", "buildMuscle"],
            obstacles: ["time", "consistency"],
            sleepQuality: 5,
            stressLevel: 8,
            commitment: 7,
            focusAreas: [
                FocusArea(muscleGroup: .chest, priority: 1, rationale: "Scan lag", suggestedFocus: "Push volume"),
                FocusArea(muscleGroup: .legs, priority: 2, rationale: "Scan lag", suggestedFocus: "Leg density")
            ],
            cutModeActive: false,
            adherence: .inconsistent
        ),
        YearSimulationPersona(
            id: "cut-mode-hybrid",
            displayName: "Hybrid Cut Mode User",
            lens: "recovery and preserve-mode stress test",
            buildIdentity: BuildIdentity(primary: .power, secondary: .endurance, shape: .hybrid),
            trainingStyle: .hybrid,
            equipment: [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .machines],
            targetFrequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .saturday],
            experience: .current,
            sessionLengthMinutes: 60,
            goals: ["getDefined", "getStronger"],
            obstacles: ["motivation", "plateau"],
            sleepQuality: 5,
            stressLevel: 7,
            commitment: 8,
            focusAreas: [
                FocusArea(muscleGroup: .back, priority: 1, rationale: "Cut preservation", suggestedFocus: "Maintain pull strength"),
                FocusArea(muscleGroup: .shoulders, priority: 2, rationale: "Cut preservation", suggestedFocus: "Frame")
            ],
            cutModeActive: true,
            adherence: .stressed
        )
    ]

    private let calendar = Calendar.fixedGMT
    private let startDate: Date
    private let personas: [YearSimulationPersona]
    private let simulationDays: Int

    init(
        personas: [YearSimulationPersona] = Self.personas,
        simulationDays: Int = Self.defaultSimulationDays
    ) {
        self.personas = personas
        self.simulationDays = simulationDays
        var components = DateComponents()
        components.calendar = Calendar.fixedGMT
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 25
        startDate = components.date!
    }

    func run() async throws -> YearSimulationReport {
        var runs: [YearPersonaRun] = []
        for persona in personas {
            let run = try await run(persona: persona)
            runs.append(run)
        }
        return YearSimulationReport(
            generatedAt: Date(),
            simulationStartDate: dateString(startDate),
            simulationDays: simulationDays,
            staticFindings: StaticTrainingLogicFinding.knownBaselineFindings,
            personaRuns: runs
        )
    }

    private func run(persona: YearSimulationPersona) async throws -> YearPersonaRun {
        var cursor = startDate
        let endDate = calendar.date(byAdding: .day, value: simulationDays, to: startDate)!
        var absoluteDay = 1
        var blockNumber = 1
        let maximumBlocks = 80
        var previousBlock: ProgramBlock?
        var progression = SimulationProgressionTracker(userId: persona.id, experience: persona.experience)
        var exerciseBlockCounts: [String: Int] = [:]
        var previousBlockExercises = Set<String>()
        var days: [YearDayExport] = []
        var programs: [YearProgramExport] = []
        var violations: [YearConstraintViolation] = []
        var actionLedger: [YearCoachActionExport] = []
        var weeklyVolume: [Int: [String: Int]] = [:]
        var weeklyBodyLoads: [Int: [String: BodyRegionTrainingLoad]] = [:]

        print("UNBOUND_YEAR_SIM_PROGRESS persona=\(persona.id) status=start")
        while cursor < endDate {
            if blockNumber > maximumBlocks {
                violations.append(
                    YearConstraintViolation(
                        severity: .critical,
                        day: absoluteDay,
                        date: dateString(cursor),
                        code: "year_sim_block_limit_exceeded",
                        detail: "Simulation stopped after \(maximumBlocks) generated blocks without reaching day 365."
                    )
                )
                break
            }

            print("UNBOUND_YEAR_SIM_PROGRESS persona=\(persona.id) block=\(blockNumber) day=\(absoluteDay) date=\(dateString(cursor))")
            let isCalibration = blockNumber == 1
            let keyedHistory = Dictionary(uniqueKeysWithValues: exerciseBlockCounts.map { key, count in
                (
                    key,
                    ExerciseRefreshRule.ExerciseHistory(
                        exerciseKey: key,
                        consecutiveBlocksPrescribed: count,
                        hadTierUnlock: false,
                        hadPlateauDeload: false
                    )
                )
            })

            let rollover = BlockRolloverService.resolveRollover(
                previousBlock: previousBlock,
                newFocusAreas: persona.focusAreas,
                exerciseHistory: keyedHistory,
                cutModeActive: persona.cutModeActive
            )
            if !rollover.exercisesToRotate.isEmpty {
                actionLedger.append(
                    YearCoachActionExport(
                        day: absoluteDay,
                        date: dateString(cursor),
                        kind: "rolloverRotationSuggested",
                        detail: rollover.exercisesToRotate.joined(separator: ", ")
                    )
                )
            }

            let program = try DeterministicProgramGenerator.generate(input: input(
                persona: persona,
                date: cursor,
                previousBlock: previousBlock,
                exerciseRotationsToApply: rollover.exercisesToRotate,
                progressionStates: progression.states,
                calibration: isCalibration ? .learningWeek(knownExerciseKeys: []) : .standardReady(knownExerciseKeys: Set(progression.states.keys))
            ))

            let waveProbe = calendar.date(byAdding: .day, value: Arc.waveLengthDays, to: program.createdAt) ?? program.createdAt
            let waveResult = WaveAdjuster.applyIfNeeded(program: program, asOf: waveProbe, calendar: calendar)
            let simulatedProgram = waveResult.didApply ? waveResult.program : program
            if waveResult.didApply && prescriptionSignature(waveResult.program) == prescriptionSignature(program) {
                violations.append(
                    YearConstraintViolation(
                        severity: .warning,
                        day: absoluteDay,
                        date: dateString(cursor),
                        code: "wave2_no_prescription_change",
                        detail: "Wave 2 emitted \(waveResult.adjustments.count) adjustment rows but left the program prescription unchanged."
                    )
                )
            }

            programs.append(
                YearProgramExport(
                    blockNumber: blockNumber,
                    programId: simulatedProgram.id,
                    name: simulatedProgram.name,
                    startedAt: dateString(simulatedProgram.createdAt),
                    durationDays: simulatedProgram.durationDays,
                    hasArc: simulatedProgram.currentArc != nil,
                    requiredEquipment: simulatedProgram.requiredEquipment,
                    estimatedDailyMinutes: simulatedProgram.estimatedDailyMinutes,
                    trainingDayCount: simulatedProgram.days.filter { !$0.isRestDay }.count,
                    rolloverRotationsSuggested: rollover.exercisesToRotate
                )
            )

            let currentBlockExercises = Set(simulatedProgram.days
                .compactMap { $0.workout }
                .flatMap { $0.mainExercises }
                .map(exerciseKey))
            for key in Set(previousBlockExercises).union(currentBlockExercises) {
                exerciseBlockCounts[key] = currentBlockExercises.contains(key)
                    ? (previousBlockExercises.contains(key) ? (exerciseBlockCounts[key, default: 0] + 1) : 1)
                    : 0
            }
            previousBlockExercises = currentBlockExercises

            let daysRemaining = calendar.dateComponents([.day], from: cursor, to: endDate).day ?? 0
            let daysToSimulate = min(simulatedProgram.durationDays, max(0, daysRemaining))
            if daysRemaining <= 0 {
                break
            }
            if daysToSimulate <= 0 {
                violations.append(
                    YearConstraintViolation(
                        severity: .critical,
                        day: absoluteDay,
                        date: dateString(cursor),
                        code: "year_sim_no_time_advance",
                        detail: "Generated program \(simulatedProgram.id) had durationDays=\(simulatedProgram.durationDays) with \(daysRemaining) days remaining, so the simulation could not advance."
                    )
                )
                break
            }

            for localOffset in 0..<daysToSimulate {
                let date = calendar.date(byAdding: .day, value: localOffset, to: cursor)!
                guard let programDay = simulatedProgram.days.first(where: { $0.dayNumber == localOffset + 1 }) else { continue }
                let result = await simulateDay(
                    persona: persona,
                    program: simulatedProgram,
                    day: programDay,
                    date: date,
                    absoluteDay: absoluteDay,
                    progression: &progression
                )
                days.append(result.day)
                violations.append(contentsOf: result.violations)
                actionLedger.append(contentsOf: result.actions)

                let week = ((absoluteDay - 1) / 7) + 1
                for exercise in programDay.workout?.mainExercises ?? [] where result.day.completed {
                    for muscle in exercise.muscleGroups {
                        weeklyVolume[week, default: [:]][muscle.rawValue, default: 0] += exercise.sets
                    }
                }
                if result.day.completed, !result.bodyLoads.isEmpty {
                    var weekLoads = weeklyBodyLoads[week] ?? [:]
                    for load in result.bodyLoads {
                        var current = weekLoads[load.region.rawValue] ?? BodyRegionTrainingLoad(region: load.region)
                        current.merge(load)
                        weekLoads[load.region.rawValue] = current
                    }
                    weeklyBodyLoads[week] = weekLoads
                }
                absoluteDay += 1
            }

            previousBlock = ProgramBlock(
                id: "block-\(persona.id)-\(blockNumber)",
                userId: persona.id,
                programId: simulatedProgram.id,
                blockNumber: blockNumber,
                startedAt: cursor,
                scanId: nil,
                accessoryBias: rollover.accessoryBiasResult.bias,
                cutModeActive: persona.cutModeActive,
                biasRefreshedFromPrevious: rollover.accessoryBiasResult.carriedForward,
                exerciseRotationsThisBlock: rollover.exercisesToRotate
            )

            cursor = calendar.date(byAdding: .day, value: daysToSimulate, to: cursor) ?? endDate
            blockNumber += 1
        }
        print("UNBOUND_YEAR_SIM_PROGRESS persona=\(persona.id) status=end days=\(days.count) programs=\(programs.count) violations=\(violations.count)")

        if simulationDays >= Self.fullYearSimulationDays {
            violations.append(contentsOf: annualConstraintChecks(
                persona: persona,
                days: days,
                programs: programs,
                progression: progression
            ))
        }

        return YearPersonaRun(
            persona: persona.export,
            days: days,
            programs: programs,
            weeklyVolume: weeklyVolume
                .keys
                .sorted()
                .map { YearWeeklyVolumeExport(week: $0, setsByMuscle: weeklyVolume[$0] ?? [:]) },
            weeklyBodyRegionLoad: weeklyBodyLoads
                .keys
                .sorted()
                .map { YearWeeklyBodyRegionLoadExport(week: $0, loadsByRegion: weeklyBodyLoads[$0] ?? [:]) },
            progressionSummary: progression.summary,
            coachActionLedger: actionLedger,
            violations: violations
        )
    }

    private func simulateDay(
        persona: YearSimulationPersona,
        program: TrainingProgram,
        day: ProgramDay,
        date: Date,
        absoluteDay: Int,
        progression: inout SimulationProgressionTracker
    ) async -> DaySimulationResult {
        guard !day.isRestDay, let workout = day.workout else {
            let bodyLoads = BodyRegionTrainingLedger.loads(for: recoveryDraft(
                persona: persona,
                activities: day.recoveryActivities,
                date: date
            ))
            return DaySimulationResult(
                day: YearDayExport(
                    absoluteDay: absoluteDay,
                    date: dateString(date),
                    blockDay: day.dayNumber,
                    wave: waveLabel(program: program, date: date),
                    label: day.label,
                    isRestDay: true,
                    completed: true,
                    workoutName: nil,
                    estimatedMinutes: 0,
                    exercises: [],
                    notes: []
                ),
                violations: [],
                actions: [],
                bodyLoads: bodyLoads
            )
        }

        var violations: [YearConstraintViolation] = []
        var actions: [YearCoachActionExport] = []
        let missed = shouldMissWorkout(persona: persona, absoluteDay: absoluteDay)
        let travel = isTravelDay(persona: persona, absoluteDay: absoluteDay)
        let stressed = isStressSpike(persona: persona, absoluteDay: absoluteDay)
        let modifierContext = DailyWorkoutModifierContext(
            availableEquipment: travel ? [.bodyweight, .bands] : nil,
            deloadFactor: stressed ? 0.75 : nil
        )
        let scheduledSkillIds = scheduledSkillIds(for: persona, absoluteDay: absoluteDay)
        let shouldAttachCarry = shouldAttachCarryFinisher(persona: persona, absoluteDay: absoluteDay)
        let resolved = await MainActor.run {
            let resolvedWorkout = DailyWorkoutResolver.resolvedWorkout(
                from: workout,
                date: date,
                scheduledSkillIds: scheduledSkillIds,
                modifierContext: modifierContext
            )
            var draft = DailyWorkoutResolver.programDraft(
                from: workout,
                userId: persona.id,
                programId: program.id,
                dayNumber: day.dayNumber,
                date: date,
                scheduledSkillIds: scheduledSkillIds,
                modifierContext: modifierContext
            )
            if shouldAttachCarry {
                draft.blocks.append(carryFinisherBlock())
            }
            return (resolvedWorkout, draft)
        }
        let effectiveWorkout = resolved.0
        let bodyLoads = missed ? [] : BodyRegionTrainingLedger.loads(for: resolved.1)

        if !scheduledSkillIds.isEmpty {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "scheduledSkillAttached",
                detail: "Simulation attached skill work: \(scheduledSkillIds.joined(separator: ", "))."
            ))
        }
        if shouldAttachCarry {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "carryFinisherAttached",
                detail: "Simulation attached a loaded carry finisher to test joint/tendon stress accounting."
            ))
        }

        if travel {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "travelModifierExpected",
                detail: "User is traveling; simulation checks the app-resolved workout after bodyweight/band substitutions."
            ))
        }
        if stressed {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "recoveryAdjustmentExpected",
                detail: "High stress/low sleep week should reduce friction or volume."
            ))
        }

        if effectiveWorkout.estimatedMinutes > persona.sessionLengthMinutes + 10 {
            violations.append(YearConstraintViolation(
                severity: .warning,
                day: absoluteDay,
                date: dateString(date),
                code: "session_length_overage",
                detail: "\(effectiveWorkout.name) estimates \(effectiveWorkout.estimatedMinutes)m for a \(persona.sessionLengthMinutes)m onboarding answer."
            ))
        }

        if effectiveWorkout.warmup.isEmpty {
            violations.append(YearConstraintViolation(
                severity: .info,
                day: absoluteDay,
                date: dateString(date),
                code: "empty_warmup",
                detail: "\(effectiveWorkout.name) has no generated warmup."
            ))
        }

        let exercises = effectiveWorkout.mainExercises.map { exercise -> YearExerciseExport in
            let compatibilityEquipment: [Equipment] = travel ? [.bodyweight, .bands] : persona.equipment
            if let definition = MovementCatalog.canonicalExercise(named: exercise.name),
               !MovementCatalog.isProgramCompatible(definition, style: travel ? .bodyweight : persona.trainingStyle, userEquipment: compatibilityEquipment) {
                violations.append(YearConstraintViolation(
                    severity: .critical,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "equipment_mismatch",
                    detail: "\(exercise.name) does not fit available equipment \(compatibilityEquipment.map(\.rawValue).joined(separator: ", "))."
                ))
            } else if MovementCatalog.canonicalExercise(named: exercise.name) == nil {
                violations.append(YearConstraintViolation(
                    severity: .warning,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "uncatalogued_exercise",
                    detail: "\(exercise.name) could not be resolved in MovementCatalog."
                ))
            }

            let outcome = progression.log(
                exercise: exercise,
                date: date,
                shouldGrind: stressed || absoluteDay % 43 == 0,
                shouldUnderperform: missed || absoluteDay % 37 == 0,
                cutModeActive: persona.cutModeActive
            )
            if outcome.bumpedOnGrindyRPE {
                violations.append(YearConstraintViolation(
                    severity: .warning,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "progressed_on_grindy_rpe",
                    detail: "\(exercise.name) progressed after top-range reps at RPE \(outcome.rpe), which should probably be held or reviewed."
                ))
            }
            if outcome.accessoryRepCeilingTooHigh {
                violations.append(YearConstraintViolation(
                    severity: .warning,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "accessory_rep_ceiling_runaway",
                    detail: "\(exercise.name) accessory rep ceiling reached \(outcome.targetRepMaxAfter); load may never bump."
                ))
            }

            return YearExerciseExport(
                name: exercise.name,
                sets: exercise.sets,
                reps: exercise.reps,
                rpe: exercise.rpe,
                completedSets: missed ? 0 : exercise.sets,
                simulatedTopSetReps: missed ? 0 : outcome.reps,
                simulatedTopSetRPE: missed ? nil : outcome.rpe,
                simulatedWeightKg: outcome.weightKg,
                classification: outcome.classification.rawValue,
                substitution: exercise.substitution
            )
        }

        return DaySimulationResult(
            day: YearDayExport(
                absoluteDay: absoluteDay,
                date: dateString(date),
                blockDay: day.dayNumber,
                wave: waveLabel(program: program, date: date),
                label: day.label,
                isRestDay: false,
                completed: !missed,
                workoutName: effectiveWorkout.name,
                estimatedMinutes: effectiveWorkout.estimatedMinutes,
                exercises: exercises,
                notes: [
                    travel ? "travel" : nil,
                    stressed ? "stress-spike" : nil,
                    missed ? "missed" : nil,
                    !scheduledSkillIds.isEmpty ? "skill-attached" : nil,
                    shouldAttachCarry ? "carry-finisher" : nil
                ].compactMap { $0 }
            ),
            violations: violations,
            actions: actions,
            bodyLoads: bodyLoads
        )
    }

    private func scheduledSkillIds(for persona: YearSimulationPersona, absoluteDay: Int) -> [String] {
        guard !persona.simulatedSkillIds.isEmpty else { return [] }
        let week = max(0, (absoluteDay - 1) / 7)
        return [persona.simulatedSkillIds[week % persona.simulatedSkillIds.count]]
    }

    private func shouldAttachCarryFinisher(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        guard let cadence = persona.simulatedCarryEveryNDays, cadence > 0 else { return false }
        return absoluteDay % cadence == 0
    }

    private func carryFinisherBlock() -> TrainingBlock {
        TrainingBlock(
            kind: .carry,
            title: "Loaded Carry Finisher",
            prescriptions: [
                TrainingBlockPrescription(
                    exerciseName: "Farmer Carry",
                    sets: 3,
                    target: .distanceMeters(40),
                    restSeconds: 90,
                    muscleGroups: [.back, .arms, .shoulders]
                )
            ]
        )
    }

    private func recoveryDraft(
        persona: YearSimulationPersona,
        activities: [RecoveryActivity],
        date: Date
    ) -> TrainingSessionDraft {
        let mobilityActivities = activities.filter { activity in
            let text = "\(activity.name) \(activity.description)".lowercased()
            return text.contains("mobility") || text.contains("hips") || text.contains("shoulders")
        }
        guard !mobilityActivities.isEmpty else {
            return TrainingSessionDraft(
                userId: persona.id,
                source: .routine,
                title: "Rest Day Recovery",
                date: date,
                estimatedMinutes: 0,
                blocks: []
            )
        }

        return TrainingSessionDraft(
            userId: persona.id,
            source: .routine,
            title: "Rest Day Mobility",
            date: date,
            estimatedMinutes: mobilityActivities.reduce(0) { $0 + $1.durationMinutes },
            blocks: [
                TrainingBlock(
                    kind: .routine,
                    title: "Mobility Flow",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Deep Squat Hold",
                            sets: 2,
                            target: .holdSeconds(45),
                            restSeconds: 20
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Shoulder Dislocates",
                            sets: 2,
                            target: .repsRange(10, 15),
                            restSeconds: 20
                        )
                    ]
                )
            ]
        )
    }

    private func input(
        persona: YearSimulationPersona,
        date: Date,
        previousBlock: ProgramBlock?,
        exerciseRotationsToApply: [String],
        progressionStates: [String: ProgressionState],
        calibration: ProgramCalibrationInput
    ) -> ProgramGeneratorInput {
        ProgramGeneratorInput(
            userId: persona.id,
            scanId: nil,
            analysisId: nil,
            buildIdentity: persona.buildIdentity,
            trainingStyle: persona.trainingStyle,
            equipment: persona.equipment,
            targetFrequency: persona.targetFrequency,
            trainingDays: persona.trainingDays,
            experience: persona.experience,
            sessionLengthMinutes: persona.sessionLengthMinutes,
            focusAreas: persona.focusAreas,
            cutModeActive: persona.cutModeActive,
            trainingFeedbackMode: TrainingFeedbackMode.default(for: persona.experience),
            progressionStates: progressionStates,
            previousBlock: previousBlock,
            exerciseRotationsToApply: exerciseRotationsToApply,
            weightKg: persona.experience == .current ? 82 : 72,
            heightCm: 178,
            age: persona.experience == .never ? 22 : 29,
            sex: .male,
            blockStartDate: date,
            exercisePreferences: [],
            calibration: calibration
        )
    }

    private func annualConstraintChecks(
        persona: YearSimulationPersona,
        days: [YearDayExport],
        programs: [YearProgramExport],
        progression: SimulationProgressionTracker
    ) -> [YearConstraintViolation] {
        var violations: [YearConstraintViolation] = []
        let completed = days.filter { !$0.isRestDay && $0.completed }.count
        let missed = days.filter { !$0.isRestDay && !$0.completed }.count
        if completed == 0 {
            violations.append(YearConstraintViolation(
                severity: .critical,
                day: nil,
                date: nil,
                code: "no_completed_training",
                detail: "\(persona.displayName) completed zero training sessions."
            ))
        }
        if missed > completed / 2 && persona.adherence != .inconsistent {
            violations.append(YearConstraintViolation(
                severity: .warning,
                day: nil,
                date: nil,
                code: "unexpected_adherence_collapse",
                detail: "\(persona.displayName) missed \(missed) sessions against \(completed) completed."
            ))
        }
        if programs.filter({ $0.hasArc }).count < 10 {
            violations.append(YearConstraintViolation(
                severity: .critical,
                day: nil,
                date: nil,
                code: "insufficient_annual_arcs",
                detail: "Only \(programs.filter { $0.hasArc }.count) arc programs generated across the simulated year."
            ))
        }
        if persona.cutModeActive && progression.summary.totalWeightBumps > 0 {
            violations.append(YearConstraintViolation(
                severity: .critical,
                day: nil,
                date: nil,
                code: "cut_mode_weight_bumps",
                detail: "Cut-mode persona recorded \(progression.summary.totalWeightBumps) simulated weight bumps."
            ))
        }
        return violations
    }

    private func shouldMissWorkout(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        switch persona.adherence {
        case .steady:
            return absoluteDay % 61 == 0
        case .aggressive:
            return absoluteDay % 89 == 0
        case .inconsistent:
            return absoluteDay % 11 == 0 || (absoluteDay >= 120 && absoluteDay <= 127)
        case .stressed:
            return absoluteDay % 29 == 0
        }
    }

    private func isTravelDay(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        persona.adherence == .inconsistent && ((80...87).contains(absoluteDay) || (210...218).contains(absoluteDay))
    }

    private func isStressSpike(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        persona.stressLevel >= 7 && absoluteDay % 23 == 0
    }

    private func waveLabel(program: TrainingProgram, date: Date) -> String? {
        guard let wave = ArcScheduler.context(for: program, asOf: date, calendar: calendar)?.wave else { return nil }
        return wave.rawValue
    }

    private func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private func exerciseKey(_ exercise: Exercise) -> String {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        }
        return MovementCatalog.normalized(exercise.name)
    }

    private func prescriptionSignature(_ program: TrainingProgram) -> String {
        program.days.map { day in
            guard let workout = day.workout else { return "\(day.dayNumber):rest" }
            let exercises = workout.mainExercises.map {
                "\($0.name)|\($0.sets)|\($0.reps)|\($0.rpe ?? -1)"
            }.joined(separator: ",")
            return "\(day.dayNumber):\(exercises)"
        }.joined(separator: ";")
    }
}

private struct SimulationProgressionTracker {
    private(set) var states: [String: ProgressionState] = [:]
    private var bumpCount = 0
    private var grindBumpCount = 0
    private var accessoryRunawayCount = 0

    let userId: String
    let experience: Experience

    init(userId: String, experience: Experience) {
        self.userId = userId
        self.experience = experience
    }

    var summary: YearProgressionSummary {
        YearProgressionSummary(
            trackedExerciseCount: states.count,
            totalWeightBumps: bumpCount,
            grindyRPEBumps: grindBumpCount,
            accessoryRepCeilingWarnings: accessoryRunawayCount,
            finalStates: states.values.sorted { $0.exerciseKey < $1.exerciseKey }.map {
                YearProgressionStateExport(
                    exerciseKey: $0.exerciseKey,
                    displayName: $0.displayName,
                    currentWorkingWeightKg: rounded($0.currentWorkingWeightKg),
                    targetRepMin: $0.targetRepMin,
                    targetRepMax: $0.targetRepMax,
                    targetRPE: $0.targetRPE,
                    blockType: $0.blockType.rawValue,
                    consecutiveSessionsAtTarget: $0.consecutiveSessionsAtTarget
                )
            }
        )
    }

    mutating func log(
        exercise: Exercise,
        date: Date,
        shouldGrind: Bool,
        shouldUnderperform: Bool,
        cutModeActive: Bool
    ) -> ProgressionLogOutcome {
        let key = exerciseKey(exercise)
        var state = states[key] ?? seedState(for: exercise, key: key)
        let classification = state.classification
        let reps: Int
        if shouldUnderperform {
            reps = max(1, state.targetRepMax - 2)
        } else {
            reps = state.targetRepMax
        }
        let rpe = shouldGrind ? min(10, max(state.targetRPE + 2, 9)) : state.targetRPE
        let hitTopOfRange = reps >= state.targetRepMax
        let hitTargetRPE = state.targetRPE == 0 || rpe <= state.targetRPE
        let previousWeight = state.currentWorkingWeightKg

        if hitTopOfRange && hitTargetRPE {
            state.consecutiveSessionsAtTarget += 1
        } else {
            state.consecutiveSessionsAtTarget = 0
        }

        var bumpedOnGrindyRPE = false
        let accessoryCeilingTooHigh = false
        if state.consecutiveSessionsAtTarget >= 2 {
            switch classification {
            case .upperCompound, .lowerCompound:
                if !cutModeActive {
                    state.currentWorkingWeightKg = WeightPlatePolicy.progressedWeightKilograms(
                        from: state.currentWorkingWeightKg,
                        classification: classification,
                        unit: .kilograms,
                        microloadingEnabled: false
                    )
                    if state.currentWorkingWeightKg > previousWeight {
                        bumpCount += 1
                        if shouldGrind {
                            grindBumpCount += 1
                            bumpedOnGrindyRPE = true
                        }
                    }
                }
                state.consecutiveSessionsAtTarget = 0
            case .accessory:
                let ceiling = accessoryRepCeiling(for: state)
                if state.targetRepMax < ceiling {
                    state.targetRepMax = min(ceiling, state.targetRepMax + 2)
                    state.consecutiveSessionsAtTarget = 0
                } else {
                    state.currentWorkingWeightKg = WeightPlatePolicy.progressedWeightKilograms(
                        from: state.currentWorkingWeightKg,
                        classification: classification,
                        unit: .kilograms,
                        microloadingEnabled: false
                    )
                    state.targetRepMax = classification.defaultRepRange(for: state.blockType).upperBound
                    state.consecutiveSessionsAtTarget = 0
                }
            case .bodyweightSkill:
                state.consecutiveSessionsAtTarget = 0
            }
        }
        state.updatedAt = date
        states[key] = state

        return ProgressionLogOutcome(
            reps: reps,
            rpe: rpe,
            weightKg: rounded(state.currentWorkingWeightKg),
            classification: classification,
            targetRepMaxAfter: state.targetRepMax,
            bumpedOnGrindyRPE: bumpedOnGrindyRPE,
            accessoryRepCeilingTooHigh: accessoryCeilingTooHigh
        )
    }

    private func exerciseKey(_ exercise: Exercise) -> String {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        }
        return MovementCatalog.normalized(exercise.name)
    }

    private func seedState(for exercise: Exercise, key: String) -> ProgressionState {
        var state = ProgressionState.seed(
            userId: userId,
            exercise: key,
            startingWeightKg: startingWeight(for: key)
        )
        state.displayName = exercise.name
        if let rpe = exercise.rpe {
            state.targetRPE = rpe
        }
        return state
    }

    private func startingWeight(for key: String) -> Double {
        let classification = ExerciseClassification.classify(exerciseKey: key)
        let multiplier: Double
        switch experience {
        case .never: multiplier = 0.65
        case .tried: multiplier = 0.8
        case .used: multiplier = 0.95
        case .current: multiplier = 1.15
        }
        switch classification {
        case .lowerCompound: return 80 * multiplier
        case .upperCompound: return 50 * multiplier
        case .accessory: return 16 * multiplier
        case .bodyweightSkill: return 0
        }
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func accessoryRepCeiling(for state: ProgressionState) -> Int {
        max(20, state.classification.defaultRepRange(for: state.blockType).upperBound)
    }
}

private struct BaselineYearSimulationArtifactWriter {
    func write(_ report: YearSimulationReport) throws -> URL {
        let root = try writableRoot()

        try writeJSON(report, to: root.appendingPathComponent("\(report.simulationDays)-day-program-export.json"))
        try writeJSON(report.personaRuns.map(\.persona), to: root.appendingPathComponent("personas.json"))
        try markdownSummary(report).write(
            to: root.appendingPathComponent("year-simulation-summary.md"),
            atomically: true,
            encoding: .utf8
        )
        try violationsMarkdown(report).write(
            to: root.appendingPathComponent("constraint-violations.md"),
            atomically: true,
            encoding: .utf8
        )
        try weeklyVolumeCSV(report).write(
            to: root.appendingPathComponent("weekly-volume-report.csv"),
            atomically: true,
            encoding: .utf8
        )
        try bodyRegionLoadCSV(report).write(
            to: root.appendingPathComponent("weekly-body-region-load-report.csv"),
            atomically: true,
            encoding: .utf8
        )
        return root
    }

    private func writableRoot() throws -> URL {
        let candidates = [
            overrideRoot(),
            sourceRoot(),
            temporaryRoot()
        ].compactMap { $0 }

        var lastError: Error?
        for candidate in candidates {
            do {
                try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
                return candidate
            } catch {
                lastError = error
            }
        }
        throw lastError ?? CocoaError(.fileWriteUnknown)
    }

    private func overrideRoot() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_EXPORT_DIR"],
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("unbound-year-simulation-\(timestamp())", isDirectory: true)
    }

    private func sourceRoot() -> URL {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return projectRoot
            .appendingPathComponent("LocalArtifacts", isDirectory: true)
            .appendingPathComponent("year-simulation-\(timestamp())", isDirectory: true)
    }

    private func temporaryRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("unbound-year-simulation-\(timestamp())", isDirectory: true)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url)
    }

    private func markdownSummary(_ report: YearSimulationReport) -> String {
        var lines: [String] = [
            "# UNBOUND Year Simulation Baseline",
            "",
            "- Generated: \(report.generatedAt)",
            "- Start date: \(report.simulationStartDate)",
            "- Days: \(report.simulationDays)",
            "- Personas: \(report.personaRuns.count)",
            "",
            "## Persona Results"
        ]
        for run in report.personaRuns {
            let completed = run.days.filter { !$0.isRestDay && $0.completed }.count
            let missed = run.days.filter { !$0.isRestDay && !$0.completed }.count
            let critical = run.violations.filter { $0.severity == .critical }.count
            let warnings = run.violations.filter { $0.severity == .warning }.count
            lines.append("")
            lines.append("### \(run.persona.displayName)")
            lines.append("- Lens: \(run.persona.lens)")
            lines.append("- Programs generated: \(run.programs.count)")
            lines.append("- Completed workouts: \(completed)")
            lines.append("- Missed workouts: \(missed)")
            lines.append("- Critical violations: \(critical)")
            lines.append("- Warnings: \(warnings)")
            lines.append("- Weight bumps: \(run.progressionSummary.totalWeightBumps)")
            lines.append("- Grindy RPE bumps: \(run.progressionSummary.grindyRPEBumps)")
            lines.append("- Accessory ceiling warnings: \(run.progressionSummary.accessoryRepCeilingWarnings)")
        }
        lines.append("")
        lines.append("## Static Known Findings")
        for finding in report.staticFindings {
            lines.append("- [\(finding.severity.rawValue)] \(finding.code): \(finding.detail)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func violationsMarkdown(_ report: YearSimulationReport) -> String {
        var lines = ["# Constraint Violations", ""]
        for run in report.personaRuns {
            lines.append("## \(run.persona.displayName)")
            if run.violations.isEmpty {
                lines.append("- None")
            } else {
                for violation in run.violations {
                    let location = [violation.day.map { "day \($0)" }, violation.date].compactMap { $0 }.joined(separator: ", ")
                    lines.append("- [\(violation.severity.rawValue)] \(violation.code)\(location.isEmpty ? "" : " (\(location))"): \(violation.detail)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func weeklyVolumeCSV(_ report: YearSimulationReport) -> String {
        var rows = ["persona_id,week,muscle_group,sets"]
        for run in report.personaRuns {
            for week in run.weeklyVolume {
                for muscle in week.setsByMuscle.keys.sorted() {
                    rows.append("\(run.persona.id),\(week.week),\(muscle),\(week.setsByMuscle[muscle] ?? 0)")
                }
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private func bodyRegionLoadCSV(_ report: YearSimulationReport) -> String {
        var rows = [
            "persona_id,week,body_region,direct_hard_sets,secondary_exposure_sets,skill_practice_sets,mobility_control_sets,joint_tendon_stress_sets,coach_load_score,raw_tagged_sets"
        ]
        for run in report.personaRuns {
            for week in run.weeklyBodyRegionLoad {
                for region in week.loadsByRegion.keys.sorted() {
                    guard let load = week.loadsByRegion[region] else { continue }
                    rows.append([
                        run.persona.id,
                        "\(week.week)",
                        region,
                        format(load.directHardSets),
                        format(load.secondaryExposureSets),
                        format(load.skillPracticeSets),
                        format(load.mobilityControlSets),
                        format(load.jointTendonStressSets),
                        format(load.coachLoadScore),
                        format(load.rawTaggedSets)
                    ].joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.2f", value)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private struct YearSimulationPersona {
    let id: String
    let displayName: String
    let lens: String
    let buildIdentity: BuildIdentity
    let trainingStyle: TrainingStyle
    let equipment: [Equipment]
    let targetFrequency: TargetFrequency
    let trainingDays: Set<Weekday>
    let experience: Experience
    let sessionLengthMinutes: Int
    let goals: [String]
    let obstacles: [String]
    let sleepQuality: Int
    let stressLevel: Int
    let commitment: Int
    let focusAreas: [FocusArea]
    let cutModeActive: Bool
    let adherence: YearAdherenceProfile
    let simulatedSkillIds: [String]
    let simulatedCarryEveryNDays: Int?

    init(
        id: String,
        displayName: String,
        lens: String,
        buildIdentity: BuildIdentity,
        trainingStyle: TrainingStyle,
        equipment: [Equipment],
        targetFrequency: TargetFrequency,
        trainingDays: Set<Weekday>,
        experience: Experience,
        sessionLengthMinutes: Int,
        goals: [String],
        obstacles: [String],
        sleepQuality: Int,
        stressLevel: Int,
        commitment: Int,
        focusAreas: [FocusArea],
        cutModeActive: Bool,
        adherence: YearAdherenceProfile,
        simulatedSkillIds: [String] = [],
        simulatedCarryEveryNDays: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.lens = lens
        self.buildIdentity = buildIdentity
        self.trainingStyle = trainingStyle
        self.equipment = equipment
        self.targetFrequency = targetFrequency
        self.trainingDays = trainingDays
        self.experience = experience
        self.sessionLengthMinutes = sessionLengthMinutes
        self.goals = goals
        self.obstacles = obstacles
        self.sleepQuality = sleepQuality
        self.stressLevel = stressLevel
        self.commitment = commitment
        self.focusAreas = focusAreas
        self.cutModeActive = cutModeActive
        self.adherence = adherence
        self.simulatedSkillIds = simulatedSkillIds
        self.simulatedCarryEveryNDays = simulatedCarryEveryNDays
    }

    var export: YearPersonaExport {
        YearPersonaExport(
            id: id,
            displayName: displayName,
            lens: lens,
            buildIdentity: buildIdentity.displayName,
            trainingStyle: trainingStyle.rawValue,
            equipment: equipment.map(\.rawValue),
            targetFrequency: targetFrequency.rawValue,
            trainingDays: trainingDays.map(\.rawValue).sorted(),
            experience: experience.rawValue,
            sessionLengthMinutes: sessionLengthMinutes,
            goals: goals,
            obstacles: obstacles,
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            commitment: commitment,
            focusAreas: focusAreas.map { $0.muscleGroup.rawValue },
            cutModeActive: cutModeActive,
            adherence: adherence.rawValue
        )
    }
}

private enum YearAdherenceProfile: String, Codable {
    case steady
    case aggressive
    case inconsistent
    case stressed
}

private struct DaySimulationResult {
    let day: YearDayExport
    let violations: [YearConstraintViolation]
    let actions: [YearCoachActionExport]
    let bodyLoads: [BodyRegionTrainingLoad]
}

private struct ProgressionLogOutcome {
    let reps: Int
    let rpe: Int
    let weightKg: Double
    let classification: ExerciseClassification
    let targetRepMaxAfter: Int
    let bumpedOnGrindyRPE: Bool
    let accessoryRepCeilingTooHigh: Bool
}

private struct StaticTrainingLogicFinding: Codable {
    let severity: YearViolationSeverity
    let code: String
    let detail: String

    static let knownBaselineFindings: [StaticTrainingLogicFinding] = []
}

private struct YearSimulationReport: Codable {
    let generatedAt: Date
    let simulationStartDate: String
    let simulationDays: Int
    let staticFindings: [StaticTrainingLogicFinding]
    let personaRuns: [YearPersonaRun]
}

private struct YearPersonaExport: Codable {
    let id: String
    let displayName: String
    let lens: String
    let buildIdentity: String
    let trainingStyle: String
    let equipment: [String]
    let targetFrequency: String
    let trainingDays: [String]
    let experience: String
    let sessionLengthMinutes: Int
    let goals: [String]
    let obstacles: [String]
    let sleepQuality: Int
    let stressLevel: Int
    let commitment: Int
    let focusAreas: [String]
    let cutModeActive: Bool
    let adherence: String
}

private struct YearPersonaRun: Codable {
    let persona: YearPersonaExport
    let days: [YearDayExport]
    let programs: [YearProgramExport]
    let weeklyVolume: [YearWeeklyVolumeExport]
    let weeklyBodyRegionLoad: [YearWeeklyBodyRegionLoadExport]
    let progressionSummary: YearProgressionSummary
    let coachActionLedger: [YearCoachActionExport]
    let violations: [YearConstraintViolation]
}

private struct YearProgramExport: Codable {
    let blockNumber: Int
    let programId: String
    let name: String
    let startedAt: String
    let durationDays: Int
    let hasArc: Bool
    let requiredEquipment: [String]
    let estimatedDailyMinutes: Int
    let trainingDayCount: Int
    let rolloverRotationsSuggested: [String]
}

private struct YearDayExport: Codable {
    let absoluteDay: Int
    let date: String
    let blockDay: Int
    let wave: String?
    let label: String
    let isRestDay: Bool
    let completed: Bool
    let workoutName: String?
    let estimatedMinutes: Int
    let exercises: [YearExerciseExport]
    let notes: [String]
}

private struct YearExerciseExport: Codable {
    let name: String
    let sets: Int
    let reps: String
    let rpe: Int?
    let completedSets: Int
    let simulatedTopSetReps: Int
    let simulatedTopSetRPE: Int?
    let simulatedWeightKg: Double
    let classification: String
    let substitution: String?
}

private struct YearWeeklyVolumeExport: Codable {
    let week: Int
    let setsByMuscle: [String: Int]
}

private struct YearWeeklyBodyRegionLoadExport: Codable {
    let week: Int
    let loadsByRegion: [String: BodyRegionTrainingLoad]
}

private struct YearProgressionSummary: Codable {
    let trackedExerciseCount: Int
    let totalWeightBumps: Int
    let grindyRPEBumps: Int
    let accessoryRepCeilingWarnings: Int
    let finalStates: [YearProgressionStateExport]
}

private struct YearProgressionStateExport: Codable {
    let exerciseKey: String
    let displayName: String
    let currentWorkingWeightKg: Double
    let targetRepMin: Int
    let targetRepMax: Int
    let targetRPE: Int
    let blockType: String
    let consecutiveSessionsAtTarget: Int
}

private struct YearCoachActionExport: Codable {
    let day: Int
    let date: String
    let kind: String
    let detail: String
}

private struct YearConstraintViolation: Codable {
    let severity: YearViolationSeverity
    let day: Int?
    let date: String?
    let code: String
    let detail: String
}

private enum YearViolationSeverity: String, Codable {
    case info
    case warning
    case critical
}
