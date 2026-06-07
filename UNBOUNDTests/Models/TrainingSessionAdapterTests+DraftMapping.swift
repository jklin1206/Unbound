import XCTest
@testable import UNBOUND

@MainActor
extension TrainingSessionAdapterTests {
    func testProgramWorkoutMapsToDraftAndCompatibleWorkoutLog() {
        let workout = Workout(
            name: "Push Day",
            targetMuscleGroups: [.chest],
            warmup: [],
            mainExercises: [
                Exercise(
                    id: "pushup",
                    name: "pushup",
                    muscleGroups: [.chest],
                    sets: 3,
                    reps: "8-12",
                    restSeconds: 90,
                    rpe: 8,
                    notes: "clean reps",
                    substitution: nil
                )
            ],
            cooldown: [],
            estimatedMinutes: 35,
            notes: nil,
            blockType: nil
        )

        let draft = TrainingSessionAdapters.draft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 2
        )

        XCTAssertEqual(draft.source, .program)
        XCTAssertEqual(draft.blocks.count, 1)
        XCTAssertEqual(draft.blocks[0].prescriptions[0].target, .repsRange(8, 12))
        XCTAssertEqual(draft.blocks[0].prescriptions[0].movementId, "exercise.pushup")
        XCTAssertEqual(draft.blocks[0].prescriptions[0].rankStandardMovementId, "exercise.pushup")

        let performanceLog = PerformanceLog(
            userId: "u1",
            source: .program,
            title: draft.title,
            startedAt: Date(),
            programId: draft.programId,
            dayNumber: draft.dayNumber,
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Push Day",
                    exercises: [
                        PerformanceExercise(
                            name: "pushup",
                            plannedSets: 3,
                            plannedTarget: "8-12 reps",
                            sets: [
                                PerformanceSet(setNumber: 1, reps: 12, weightKg: nil, rpe: 8)
                            ]
                        )
                    ]
                )
            ]
        )

        let workoutLog = TrainingSessionAdapters.workoutLog(from: performanceLog)
        XCTAssertEqual(workoutLog?.programId, "p1")
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.exerciseName, "pushup")
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.movementId, "exercise.pushup")
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.rankStandardMovementId, "exercise.pushup")
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.sets.first?.reps, 12)
    }

    func testVariantMovementIdentityCarriesIntoCompatibleWorkoutLog() {
        let performanceLog = PerformanceLog(
            userId: "u1",
            source: .program,
            title: "Pull Day",
            startedAt: Date(),
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Pull Day",
                    exercises: [
                        PerformanceExercise(
                            name: "Lat Pulldown (Neutral)",
                            plannedSets: 3,
                            plannedTarget: "10 reps",
                            sets: [
                                PerformanceSet(setNumber: 1, reps: 10, weightKg: 70, rpe: 8)
                            ]
                        )
                    ]
                )
            ]
        )

        let exercise = performanceLog.blocks[0].exercises[0]
        XCTAssertEqual(exercise.movementId, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(exercise.rankStandardMovementId, "exercise.lat-pulldown")

        let workoutLog = TrainingSessionAdapters.workoutLog(from: performanceLog)
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.movementId, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.rankStandardMovementId, "exercise.lat-pulldown")
    }

    func testProgramDraftUsesMovementCatalogMetadataForVariantExercise() {
        let workout = Workout(
            name: "Pull Day",
            targetMuscleGroups: [.back],
            warmup: [],
            mainExercises: [
                Exercise(
                    id: "neutral-pulldown",
                    name: "Lat Pulldown (Neutral)",
                    muscleGroups: [.chest],
                    sets: 3,
                    reps: "10",
                    restSeconds: 90,
                    rpe: 8,
                    notes: nil,
                    substitution: nil
                )
            ],
            cooldown: [],
            estimatedMinutes: 35,
            notes: nil,
            blockType: nil
        )

        let draft = TrainingSessionAdapters.draft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 1
        )
        let prescription = draft.blocks[0].prescriptions[0]

        XCTAssertEqual(prescription.movementId, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(prescription.rankStandardMovementId, "exercise.lat-pulldown")
        XCTAssertTrue(prescription.muscleGroups.contains(.lats))
        XCTAssertFalse(prescription.muscleGroups.contains(.chest))
    }

    func testAmrapLoggerDefaultAndCompletionMetadataComeFromMovementCatalog() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .custom,
            title: "Core Hold",
            estimatedMinutes: 10,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Core",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Plank",
                            sets: 1,
                            target: .amrap,
                            restSeconds: 60
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        XCTAssertEqual(session.exercises.first?.movementId, "exercise.plank")
        XCTAssertEqual(session.exercises.first?.rankStandardMovementId, "exercise.plank")
        XCTAssertEqual(session.exercises.first?.metricKind, .holdSeconds)
        XCTAssertTrue(session.exercises.first?.tracksHold == true)

        session.exercises[0].sets[0].holdSeconds = 45
        session.exercises[0].sets[0].logged = true

        let log = session.assemblePerformanceLog(userId: "u1")
        let gains = MovementAPCalculator.gains(from: log)
        guard let gain = gains.first else {
            return XCTFail("Expected a MovementCatalog-backed AP gain for the logged plank hold.")
        }

        XCTAssertEqual(gain.movementId, "exercise.plank")
        XCTAssertEqual(gain.rankStandardMovementId, "exercise.plank")
        XCTAssertEqual(gain.holdSeconds, 45)

        let movement = MovementCatalog.definition(for: gain.movementId)
        XCTAssertFalse(movement?.bodyRegions.isEmpty ?? true)
        XCTAssertFalse(movement?.attributeWeights.isEmpty ?? true)

        let contribution = AttributeCatalog().contribution(
            forMovementId: gain.movementId,
            rankStandardMovementId: gain.rankStandardMovementId,
            fallbackExerciseName: "Plank"
        )
        XCTAssertFalse(contribution.weights.isEmpty)
    }

    func testSkillPerformanceLogMapsToSessionLogAndWorkoutCompatibleEntry() {
        let log = PerformanceLog(
            id: "perf-skill-handstand",
            userId: "u1",
            source: .skill,
            title: "Handstand",
            startedAt: Date(),
            blocks: [
                PerformanceBlock(
                    id: "block-handstand",
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.freestanding-hs-30",
                    exercises: [
                        PerformanceExercise(
                            name: "Freestanding Handstand Attempts",
                            plannedSets: 4,
                            plannedTarget: "20s hold",
                            sets: [
                                PerformanceSet(setNumber: 1, holdSeconds: 18, rpe: 7, qualityFlags: [.clean])
                            ]
                        )
                    ],
                    durationSeconds: 600
                )
            ]
        )

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: log)
        XCTAssertEqual(sessionLogs.count, 1)
        XCTAssertEqual(sessionLogs[0].id, "perf-skill-handstand:hs.freestanding-hs-30:session")
        XCTAssertEqual(sessionLogs[0].skillId, "hs.freestanding-hs-30")
        XCTAssertEqual(sessionLogs[0].exercises[0].sets[0].holdSeconds, 18)

        let workoutLog = TrainingSessionAdapters.workoutLog(from: log)
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.exerciseName, "Freestanding Handstand Attempts")
        // Foundation 2: a hold maps to durationSeconds, not the reps column.
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.sets.first?.reps, 0)
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.sets.first?.durationSeconds, 18)
    }

    func testSkillSessionLoggedExercisesMapIntoPerformanceLog() {
        let log = TrainingSessionAdapters.performanceLogForSkillSession(
            userId: "u1",
            skillId: "hs.wall-handstand-30",
            skillTitle: "Wall Handstand",
            startedAt: Date(),
            durationSeconds: 300,
            exercises: [
                LoggedExercise(
                    name: "Wall Handstand Hold",
                    sets: [
                        LoggedSet(
                            reps: 0,
                            holdSeconds: 32,
                            weightKg: nil,
                            rpe: 7,
                            qualityFlags: [.clean],
                            notes: "Chest-to-wall, quiet toes"
                        ),
                        LoggedSet(reps: 0, holdSeconds: 28, weightKg: nil, rpe: 8)
                    ]
                ),
                LoggedExercise(
                    name: "Wall Walk",
                    sets: [
                        LoggedSet(reps: 4, holdSeconds: nil, weightKg: 5, rpe: 8)
                    ]
                )
            ],
            selectedRungId: "hs.wall-handstand-30.main",
            selectedRungSource: .main,
            selectedRungReason: "Train direct Wall Handstand work."
        )

        XCTAssertEqual(log.source, .skill)
        XCTAssertEqual(log.blocks.first?.id, "\(log.id):hs.wall-handstand-30:block")
        XCTAssertEqual(log.blocks.first?.skillId, "hs.wall-handstand-30")
        XCTAssertEqual(log.blocks.first?.selectedRungId, "hs.wall-handstand-30.main")
        XCTAssertEqual(log.blocks.first?.selectedRungSource, .main)
        XCTAssertEqual(log.blocks.first?.selectedRungReason, "Train direct Wall Handstand work.")
        XCTAssertEqual(log.blocks.first?.durationSeconds, 300)
        XCTAssertEqual(log.blocks.first?.exercises[0].sets[0].holdSeconds, 32)
        XCTAssertEqual(log.blocks.first?.exercises[0].sets[0].qualityFlags, Set([.clean]))
        XCTAssertEqual(log.blocks.first?.exercises[0].sets[0].notes, "Chest-to-wall, quiet toes")
        XCTAssertEqual(log.blocks.first?.exercises[1].sets[0].reps, 4)
        XCTAssertEqual(log.blocks.first?.exercises[1].sets[0].weightKg, 5)
        XCTAssertEqual(log.blocks.first?.exercises[1].sets[0].rpe, 8)

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: log, xpAwarded: 12)
        XCTAssertEqual(sessionLogs.first?.xpAwarded, 12)
        XCTAssertEqual(sessionLogs.first?.selectedRungId, "hs.wall-handstand-30.main")
        XCTAssertEqual(sessionLogs.first?.selectedRungSource, .main)
        XCTAssertEqual(sessionLogs.first?.selectedRungReason, "Train direct Wall Handstand work.")
        XCTAssertEqual(sessionLogs.first?.exercises[0].sets[0].holdSeconds, 32)
        XCTAssertEqual(sessionLogs.first?.exercises[0].sets[0].effectiveQualityFlags, Set([.clean]))
        XCTAssertEqual(sessionLogs.first?.exercises[0].sets[0].notes, "Chest-to-wall, quiet toes")

        let workoutLog = TrainingSessionAdapters.workoutLog(from: log)
        XCTAssertEqual(workoutLog?.exerciseEntries[0].sets[0].qualityFlags, Set([.clean]))
        XCTAssertEqual(workoutLog?.exerciseEntries[0].sets[0].notes, "Chest-to-wall, quiet toes")
    }

}
