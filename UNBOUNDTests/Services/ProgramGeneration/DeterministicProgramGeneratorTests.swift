import XCTest
@testable import UNBOUND

// MIGRATION (Phase 2e): ProgramGeneratorInput.archetype replaced by buildIdentity.

final class DeterministicProgramGeneratorTests: XCTestCase {

    func testGeneratesExactlyOneArcLengthForStandardReadyArc() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        XCTAssertEqual(program.days.count, Arc.durationDays)
    }

    func testTrainingDayCountMatchesFrequencyAcrossArc() throws {
        let days: Set<Weekday> = [.monday, .wednesday, .friday]
        let input = makeInput(frequency: .three, trainingDays: days)
        let program = try DeterministicProgramGenerator.generate(input: input)
        let trainingCount = program.days.filter { !$0.isRestDay }.count
        // Every day is scheduled, and the 3/wk cadence holds across the Arc: each
        // full week contributes 3, and the final partial week adds at most one day
        // per leftover weekday. Anchored to Arc.durationDays so it survives retunes.
        let fullWeeks = Arc.durationDays / 7
        let partialDays = Arc.durationDays % 7
        XCTAssertEqual(program.days.count, Arc.durationDays)
        XCTAssertGreaterThanOrEqual(trainingCount, fullWeeks * 3)
        XCTAssertLessThanOrEqual(trainingCount, fullWeeks * 3 + partialDays)
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

    func testDurationDaysMatchesArcLength() throws {
        let input = makeInput(frequency: .three, trainingDays: [.monday, .wednesday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        XCTAssertEqual(program.durationDays, Arc.durationDays)
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

        XCTAssertEqual(program.durationDays, Arc.durationDays)
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
        XCTAssertEqual(program.currentArc?.endDate, input.blockStartDate.addingTimeInterval(Double(Arc.durationDays) * 86_400))
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

    @MainActor
    func testProgressionStateCarriesSuggestedLoadIntoGeneratedDraft() throws {
        let baseInput = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )
        let baseline = try DeterministicProgramGenerator.generate(input: baseInput)
        let baselineExercise = try XCTUnwrap(
            baseline.days
                .compactMap(\.workout)
                .flatMap(\.mainExercises)
                .first { exercise in
                    guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else { return false }
                    return definition.movementSlot == .horizontalPush
                }
        )

        var state = ProgressionState.seed(
            userId: "u-1",
            exercise: baselineExercise.name,
            startingWeightKg: 60
        )
        state.targetRepMin = 6
        state.targetRepMax = 9
        state.targetRPE = 8

        let progressedInput = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym],
            progressionStates: [MovementCatalog.normalized(state.exerciseKey): state]
        )

        UserDefaults.standard.set(TrainingWeightUnit.kilograms.rawValue, forKey: WeightPlatePolicy.unitDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: WeightPlatePolicy.unitDefaultsKey) }

        let program = try DeterministicProgramGenerator.generate(input: progressedInput)
        let workout = try XCTUnwrap(program.days.compactMap(\.workout).first {
            $0.mainExercises.contains { $0.name == baselineExercise.name }
        })
        let exercise = try XCTUnwrap(workout.mainExercises.first { $0.name == baselineExercise.name })

        XCTAssertEqual(exercise.suggestedWeightKg, 60)
        // Single-target contract: state window 6...9, no session history →
        // the plan asks for the bottom of the window.
        XCTAssertEqual(exercise.reps, "\(state.currentTargetReps)")
        XCTAssertEqual(exercise.reps, "6")
        XCTAssertNil(exercise.rpe, "prescriptions are RPE-free now")

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u-1",
            programId: program.id,
            dayNumber: 1,
            date: progressedInput.blockStartDate,
            scheduledSkillIds: []
        )
        let prescription = try XCTUnwrap(draft.blocks.flatMap(\.prescriptions).first {
            $0.exerciseName == baselineExercise.name
        })

        XCTAssertEqual(prescription.suggestedWeightKg, 60)
        XCTAssertTrue(prescription.displayTargetText.contains("@ 60 kg"))
    }

    func testBodyweightOverrideCreatesActualSkillDayForNonControlIdentity() throws {
        let input = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .hybrid),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight, .pullupBar]
        )

        let program = try DeterministicProgramGenerator.generate(input: input)
        let skillDay = try XCTUnwrap(program.days.first { $0.sessionRole == .skillOnly })
        let workout = try XCTUnwrap(skillDay.workout)
        let firstExercise = try XCTUnwrap(workout.mainExercises.first)
        let firstDefinition = try XCTUnwrap(
            MovementCatalog.definition(for: MovementResolver.resolve(firstExercise.name).movementId)
        )

        XCTAssertEqual(firstDefinition.movementSlot, .skill)
        XCTAssertTrue(workout.mainExercises.contains { exercise in
            guard let definition = MovementCatalog.definition(
                for: MovementResolver.resolve(exercise.name).movementId
            ) else { return false }
            return definition.movementSlot == .skill
        })
    }

    func testBodyweightFoundationExperienceGatesOutAdvancedCalisthenics() throws {
        let input = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .hybrid),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight, .pullupBar, .dipStation, .rings],
            experience: .never
        )

        let program = try DeterministicProgramGenerator.generate(input: input)
        let definitions = program.days
            .compactMap(\.workout)
            .flatMap(\.mainExercises)
            .compactMap { exercise in
                MovementCatalog.definition(for: MovementResolver.resolve(exercise.name).movementId)
            }

        XCTAssertFalse(definitions.isEmpty)
        XCTAssertTrue(definitions.allSatisfy { $0.difficulty == .beginner })
        XCTAssertFalse(definitions.contains {
            $0.displayName.contains("Dip") || $0.displayName == "Muscle-Up"
        })
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
            .flatMap { $0.warmup + $0.mainExercises + $0.cooldown }
            .map { $0.name.lowercased() }
        let equipmentRequiredTerms = [
            "band",
            "pull-up",
            "pullup",
            "chin-up",
            "chin up",
            "dip",
            "incline",
            "inverted row",
            "ab wheel",
            "hanging",
            // Eponymous barbell rows whose names carry no equipment keyword — must
            // not leak into a bodyweight program via name-derived classification.
            "meadows",
            "pendlay"
        ]
        for name in allNames {
            XCTAssertFalse(name.contains("barbell"),
                           "Bodyweight user shouldn't have a barbell exercise; saw \(name)")
            XCTAssertFalse(name.contains("back squat"),
                           "Bodyweight user shouldn't get back squat; saw \(name)")
            XCTAssertFalse(name.contains("deadlift"),
                           "Bodyweight user shouldn't get deadlift; saw \(name)")
            for term in equipmentRequiredTerms {
                XCTAssertFalse(
                    name.contains(term),
                    "Bodyweight-only user shouldn't get equipment-required movement \(term); saw \(name)"
                )
            }
        }
    }

    func testFloorOnlyBeginnerProgramDoesNotDuplicateSkillAndExerciseAliases() throws {
        var input = makeInput(
            frequency: .three,
            trainingDays: [.monday, .wednesday, .friday],
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            experience: .never
        )
        input.sessionLengthMinutes = 30
        input.focusAreas = [
            FocusArea(muscleGroup: .chest, priority: 1, rationale: "test", suggestedFocus: "upper body"),
            FocusArea(muscleGroup: .core, priority: 2, rationale: "test", suggestedFocus: "control")
        ]

        let program = try DeterministicProgramGenerator.generate(input: input)
        let workouts = program.days.compactMap(\.workout)

        XCTAssertFalse(workouts.isEmpty)
        for workout in workouts {
            let names = workout.mainExercises.map(\.name)
            let rankKeys = names.map { MovementResolver.resolve($0).rankStandardMovementId }

            XCTAssertEqual(
                rankKeys.count,
                Set(rankKeys).count,
                "\(workout.name) should not contain semantic duplicates: \(names)"
            )
            // Every main movement must resolve to a loggable exercise/drill, not
            // the non-rankable skill-target wrapper. The wrapper and the canonical
            // exercise now share the display name "Push-Up", so check what each
            // name resolves to, not the literal string.
            for name in names {
                XCTAssertNotEqual(
                    MovementResolver.resolve(name).role, .skillTarget,
                    "\(workout.name): '\(name)' resolves to the non-rankable skill-target wrapper; use the loggable exercise: \(names)"
                )
            }
        }

        let pushSkill = try XCTUnwrap(MovementCatalog.definition(for: "skill.cal.pushup"))
        let pushExercise = try XCTUnwrap(MovementCatalog.definition(for: "exercise.pushup"))
        XCTAssertEqual(
            DeterministicProgramGenerator.workoutEquivalenceKey(for: pushSkill),
            DeterministicProgramGenerator.workoutEquivalenceKey(for: pushExercise)
        )
    }

    func testFloorOnlyBeginnerFullBodySessionsRotateMovementSlots() throws {
        var input = makeInput(
            frequency: .three,
            trainingDays: [.monday, .wednesday, .friday],
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            experience: .never
        )
        input.sessionLengthMinutes = 30
        input.focusAreas = [
            FocusArea(muscleGroup: .chest, priority: 1, rationale: "test", suggestedFocus: "upper body"),
            FocusArea(muscleGroup: .core, priority: 2, rationale: "test", suggestedFocus: "control")
        ]

        let program = try DeterministicProgramGenerator.generate(input: input)
        let firstWeekSequences = Array(
            program.days
                .compactMap(\.workout)
                .prefix(3)
                .map { $0.mainExercises.map(\.name).joined(separator: " | ") }
        )

        XCTAssertEqual(firstWeekSequences.count, 3)
        XCTAssertGreaterThan(
            Set(firstWeekSequences).count,
            1,
            "Floor-only full-body sessions should rotate instead of repeating one sequence: \(firstWeekSequences)"
        )
        XCTAssertTrue(
            firstWeekSequences.contains { $0.localizedCaseInsensitiveContains("Glute Bridge") },
            "The first week should include a hinge pattern when floor-only equipment is available: \(firstWeekSequences)"
        )
    }

    func testFloorOnlyBeginnerGetsAtLeastOnePullMovement() throws {
        var input = makeInput(
            frequency: .three,
            trainingDays: [.monday, .wednesday, .friday],
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            experience: .never
        )
        input.sessionLengthMinutes = 30

        let program = try DeterministicProgramGenerator.generate(input: input)
        let mainNames = program.days
            .compactMap(\.workout)
            .flatMap { $0.mainExercises }
            .map(\.name)

        let hasPull = mainNames.contains { name in
            guard let definition = MovementCatalog.canonicalExercise(named: name) else { return false }
            return definition.movementSlot == .horizontalPull || definition.movementSlot == .verticalPull
        }
        XCTAssertTrue(
            hasPull,
            "A bodyweight-only beginner must get at least one pulling movement, not push/legs/core only; got: \(Set(mainNames).sorted())"
        )
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

    // 5-day weights runs PPL as a continuous cycle across week boundaries:
    // week 1 is Push Pull Legs Push Pull, and week 2 picks up the cycle at
    // Legs instead of restarting at Push.
    func testFiveDayWeightsPPLCycleContinuesAcrossWeeks() throws {
        let input = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )

        let program = try DeterministicProgramGenerator.generate(input: input)
        let sessionLabels = program.days.filter { !$0.isRestDay }.map(\.label)
        XCTAssertEqual(
            Array(sessionLabels.prefix(10)),
            ["Push", "Pull", "Legs", "Push", "Pull", "Legs", "Push", "Pull", "Legs", "Push"]
        )
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
        XCTAssertFalse(
            names.contains(original.displayName),
            "original \(original.displayName) still present"
        )
        XCTAssertTrue(
            names.contains(replacement.displayName),
            "substitute \(replacement.displayName) for \(original.displayName) missing from: \(Set(names).sorted().joined(separator: ", "))"
        )
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

        // Single-target contract: fresh intensification seed (6...8 window,
        // no history) prescribes the bottom of the window.
        XCTAssertEqual(adjusted?.reps, "\(state.currentTargetReps)")
        XCTAssertNil(adjusted?.rpe, "prescriptions are RPE-free now")
    }

    func testGrindyProgressionStateRegressesLoadRepsRestAndRPE() throws {
        var baseInput = makeInput(
            frequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .balancedAthlete),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )
        // Generous budget keeps session-fit compression out of the way: this
        // test checks the easier-bias per-exercise contract, and rest deltas
        // are legitimately trimmed when a session has to fit its window.
        baseInput.sessionLengthMinutes = 90
        let baseline = try DeterministicProgramGenerator.generate(input: baseInput)
        let baselineExercise = try XCTUnwrap(
            baseline.days
                .compactMap(\.workout)
                .flatMap(\.mainExercises)
                .first { exercise in
                    guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else { return false }
                    return definition.movementSlot == .horizontalPush
                }
        )
        let definition = try XCTUnwrap(MovementCatalog.canonicalExercise(named: baselineExercise.name))
        var state = ProgressionState.seed(
            userId: "u-1",
            exercise: definition.canonicalExerciseName ?? definition.displayName,
            startingWeightKg: 100,
            block: .accumulation
        )
        state.targetRepMin = 6
        state.targetRepMax = 10
        state.targetRPE = 8
        state.lastSessionWasGrindy = true
        state.lastSessionHitTarget = false
        state.underTargetSessionCount = 2
        state.prescriptionBias = .easier

        var progressedInput = baseInput
        progressedInput.progressionStates = [
            MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName): state
        ]

        UserDefaults.standard.set(TrainingWeightUnit.kilograms.rawValue, forKey: WeightPlatePolicy.unitDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: WeightPlatePolicy.unitDefaultsKey) }

        let program = try DeterministicProgramGenerator.generate(input: progressedInput)
        let adjusted = try XCTUnwrap(
            program.days
                .compactMap(\.workout)
                .flatMap(\.mainExercises)
                .first { $0.name == baselineExercise.name }
        )

        XCTAssertEqual(adjusted.suggestedWeightKg, 95)
        XCTAssertEqual(adjusted.reps, "6-8")
        XCTAssertNil(adjusted.rpe, "prescriptions are RPE-free now")
        XCTAssertEqual(adjusted.notes?.contains("Progression adjusted"), true)

        // The +30s recovery contract is asserted at the prescription layer:
        // the assembled program legitimately re-tightens rest when the
        // back-filled session has to fit its time window.
        let baselineDirect = DeterministicProgramGenerator.toExercise(
            definition: definition,
            input: baseInput,
            goal: baseInput.goal
        )
        let adjustedDirect = DeterministicProgramGenerator.toExercise(
            definition: definition,
            input: progressedInput,
            goal: progressedInput.goal
        )
        XCTAssertEqual(adjustedDirect.restSeconds, baselineDirect.restSeconds + 30)
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

    func testArcUsesAccumulationBuildIntensificationAndDeloadWaves() {
        XCTAssertEqual(ProgramTrainingWave.forDay(1), .accumulation)
        XCTAssertEqual(ProgramTrainingWave.forDay(9), .build)
        XCTAssertEqual(ProgramTrainingWave.forDay(16), .intensification)
        XCTAssertEqual(ProgramTrainingWave.forDay(30), .deload)
    }

    func testWaveChangesLoadAndVolumeFromSameProgressionState() throws {
        let definition = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "Bench Press"))
        var state = ProgressionState.seed(
            userId: "u-1",
            exercise: definition.canonicalExerciseName ?? definition.displayName,
            startingWeightKg: 100
        )
        state.targetRepMin = 6
        state.targetRepMax = 10
        var input = makeInput(
            frequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .friday],
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
            trainingStyle: .freeWeights,
            equipment: [.fullGym]
        )
        input.progressionStates = [
            MovementCatalog.normalized(state.exerciseKey): state
        ]

        let base = DeterministicProgramGenerator.toExercise(
            definition: definition,
            input: input,
            goal: .strength,
            wave: .accumulation
        )
        let heavy = DeterministicProgramGenerator.toExercise(
            definition: definition,
            input: input,
            goal: .strength,
            wave: .intensification
        )
        let deload = DeterministicProgramGenerator.toExercise(
            definition: definition,
            input: input,
            goal: .strength,
            wave: .deload
        )

        XCTAssertGreaterThan(heavy.suggestedWeightKg ?? 0, base.suggestedWeightKg ?? 0)
        XCTAssertLessThan(deload.suggestedWeightKg ?? 0, base.suggestedWeightKg ?? 0)
        XCTAssertLessThan(deload.sets, base.sets)
    }

    func testIsometricPrescriptionUsesMovementDurationLadder() throws {
        let definition = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "Plank"))
        let input = makeInput(
            frequency: .three,
            trainingDays: [.monday, .wednesday, .friday]
        )

        let base = DeterministicProgramGenerator.toExercise(
            definition: definition,
            input: input,
            goal: .skill,
            wave: .accumulation
        )
        let build = DeterministicProgramGenerator.toExercise(
            definition: definition,
            input: input,
            goal: .skill,
            wave: .build
        )

        XCTAssertEqual(base.reps, "20s")
        XCTAssertEqual(build.reps, "30s")
        XCTAssertFalse(base.reps.localizedCaseInsensitiveContains("rep"))
    }

    // MARK: — helper

    // MIGRATION: was archetype: .shredded — now control specialist (equivalent calisthenic identity)
    private func makeInput(
        frequency: TargetFrequency,
        trainingDays: Set<Weekday>,
        buildIdentity: BuildIdentity = BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
        trainingStyle: TrainingStyle = .bodyweight,
        equipment: [Equipment] = [.bodyweight],
        experience: Experience = .current,
        progressionStates: [String: ProgressionState] = [:]
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
            experience: experience,
            focusAreas: [],
            cutModeActive: false,
            trainingFeedbackMode: .quick,
            progressionStates: progressionStates,
            previousBlock: nil,
            weightKg: 75,
            heightCm: 178,
            age: 24,
            sex: .male,
            blockStartDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
