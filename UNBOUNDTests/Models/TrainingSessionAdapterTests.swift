import XCTest
@testable import UNBOUND

final class TrainingSessionAdapterTests: XCTestCase {
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

    @MainActor
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
        XCTAssertEqual(sessionLogs[0].id, "perf-skill-handstand:block-handstand:session")
        XCTAssertEqual(sessionLogs[0].skillId, "hs.freestanding-hs-30")
        XCTAssertEqual(sessionLogs[0].exercises[0].sets[0].holdSeconds, 18)

        let workoutLog = TrainingSessionAdapters.workoutLog(from: log)
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.exerciseName, "Freestanding Handstand Attempts")
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.sets.first?.reps, 18)
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
                        LoggedSet(reps: 0, holdSeconds: 32, weightKg: nil, rpe: 7),
                        LoggedSet(reps: 0, holdSeconds: 28, weightKg: nil, rpe: 8)
                    ]
                ),
                LoggedExercise(
                    name: "Wall Walk",
                    sets: [
                        LoggedSet(reps: 4, holdSeconds: nil, weightKg: 5, rpe: 8)
                    ]
                )
            ]
        )

        XCTAssertEqual(log.source, .skill)
        XCTAssertEqual(log.blocks.first?.skillId, "hs.wall-handstand-30")
        XCTAssertEqual(log.blocks.first?.durationSeconds, 300)
        XCTAssertEqual(log.blocks.first?.exercises[0].sets[0].holdSeconds, 32)
        XCTAssertEqual(log.blocks.first?.exercises[1].sets[0].reps, 4)
        XCTAssertEqual(log.blocks.first?.exercises[1].sets[0].weightKg, 5)
        XCTAssertEqual(log.blocks.first?.exercises[1].sets[0].rpe, 8)

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: log, xpAwarded: 12)
        XCTAssertEqual(sessionLogs.first?.xpAwarded, 12)
        XCTAssertEqual(sessionLogs.first?.exercises[0].sets[0].holdSeconds, 32)
    }

    @MainActor
    func testScheduledSkillBlockSurvivesActiveWorkoutCompletion() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .program,
            title: "Upper + Handstand",
            estimatedMinutes: 45,
            programId: "p1",
            dayNumber: 1,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Upper",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Pull-up",
                            sets: 1,
                            target: .reps(5),
                            restSeconds: 120
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.wall-handstand-30",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Wall Handstand Hold",
                            sets: 1,
                            target: .holdSeconds(30),
                            restSeconds: 90
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        XCTAssertEqual(session.exercises.count, 2)
        XCTAssertEqual(session.exercises[1].blockKind, .skill)
        XCTAssertTrue(session.exercises[1].tracksHold)

        session.exercises[0].sets[0].reps = 5
        session.exercises[0].sets[0].logged = true
        session.exercises[1].sets[0].holdSeconds = 34
        session.exercises[1].sets[0].logged = true

        let log = session.assemblePerformanceLog(userId: "u1")
        XCTAssertEqual(log.blocks.count, 2)
        XCTAssertEqual(log.blocks[1].kind, .skill)
        XCTAssertEqual(log.blocks[1].skillId, "hs.wall-handstand-30")
        XCTAssertEqual(log.blocks[0].exercises[0].movementId, "exercise.pullup")
        XCTAssertEqual(log.blocks[0].exercises[0].rankStandardMovementId, "exercise.pullup")
        XCTAssertEqual(log.blocks[1].exercises[0].movementId, "skill-drill.wall-handstand")
        XCTAssertEqual(log.blocks[1].exercises[0].rankStandardMovementId, "skill-drill.wall-handstand")
        XCTAssertEqual(log.blocks[1].exercises[0].sets[0].holdSeconds, 34)

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: log, xpAwarded: 20)
        XCTAssertEqual(sessionLogs.first?.skillId, "hs.wall-handstand-30")
        XCTAssertEqual(sessionLogs.first?.exercises[0].sets[0].holdSeconds, 34)
    }

    @MainActor
    func testMixedProgramDraftPreservesStrengthSkillCardioAndCarryMetrics() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .program,
            title: "Mixed Proof Day",
            estimatedMinutes: 55,
            programId: "p1",
            dayNumber: 4,
            blocks: [
                TrainingBlock(
                    id: "strength-block",
                    kind: .strength,
                    title: "Upper Strength",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Bench Press",
                            sets: 1,
                            target: .reps(5),
                            restSeconds: 150
                        )
                    ]
                ),
                TrainingBlock(
                    id: "skill-block",
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.wall-handstand-30",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Wall Handstand Hold",
                            sets: 1,
                            target: .holdSeconds(30),
                            restSeconds: 90
                        )
                    ]
                ),
                TrainingBlock(
                    id: "cardio-block",
                    kind: .cardio,
                    title: "Row Sprint",
                    cardioType: .row,
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Row",
                            sets: 1,
                            target: .distanceMeters(400),
                            restSeconds: 0
                        )
                    ]
                ),
                TrainingBlock(
                    id: "carry-block",
                    kind: .carry,
                    title: "Farmer Carry",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Farmer Carry",
                            sets: 1,
                            target: .distanceMeters(40),
                            restSeconds: 90
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        XCTAssertEqual(session.exercises.map(\.blockKind), [.strength, .skill, .cardio, .carry])
        XCTAssertEqual(session.exercises[1].metricKind, .holdSeconds)
        XCTAssertEqual(session.exercises[2].metricKind, .distanceMeters)
        XCTAssertEqual(session.exercises[3].metricKind, .distanceMeters)

        session.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        session.exercises[0].sets[0].weightKg = 100
        session.confirmAsPlanned(exerciseIndex: 1, setIndex: 0)
        session.confirmAsPlanned(exerciseIndex: 2, setIndex: 0)
        session.confirmAsPlanned(exerciseIndex: 3, setIndex: 0)
        session.exercises[3].sets[0].weightKg = 48

        let log = session.assemblePerformanceLog(userId: "u1")
        XCTAssertEqual(log.blocks.map(\.kind), [.strength, .skill, .cardio, .carry])
        XCTAssertEqual(log.blocks[0].exercises[0].sets[0].weightKg, 100)
        XCTAssertEqual(log.blocks[0].exercises[0].sets[0].reps, 5)
        XCTAssertEqual(log.blocks[1].skillId, "hs.wall-handstand-30")
        XCTAssertEqual(log.blocks[1].exercises[0].sets[0].holdSeconds, 30)
        XCTAssertEqual(log.blocks[2].cardioType, .row)
        XCTAssertEqual(log.blocks[2].exercises[0].sets[0].distanceMeters, 400)
        XCTAssertEqual(log.blocks[3].exercises[0].sets[0].distanceMeters, 40)
        XCTAssertEqual(log.blocks[3].exercises[0].sets[0].weightKg, 48)
    }

    func testMixedDraftPreservesBlockKindsAndMetrics() {
        let log = PerformanceLog(
            userId: "u1",
            source: .custom,
            title: "Mixed Session",
            startedAt: Date(),
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Strength",
                    exercises: [
                        PerformanceExercise(
                            name: "weighted pullup",
                            plannedSets: 3,
                            plannedTarget: "3 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 3, weightKg: 40, rpe: 8)]
                        )
                    ]
                ),
                PerformanceBlock(
                    kind: .cardio,
                    title: "Rower Sprint",
                    cardioType: .row,
                    exercises: [],
                    durationSeconds: 90,
                    distanceMeters: 400
                )
            ]
        )

        XCTAssertEqual(log.blocks[0].exercises[0].sets[0].weightKg, 40)
        XCTAssertEqual(log.blocks[1].distanceMeters, 400)
        XCTAssertEqual(log.blocks[1].durationSeconds, 90)
    }

    @MainActor
    func testCustomCarryDraftPreservesLoadDistanceAndBlockIdentity() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .custom,
            title: "Carry Proof",
            estimatedMinutes: 15,
            blocks: [
                TrainingBlock(
                    id: "carry-block",
                    kind: .carry,
                    title: "Loaded Carry",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Farmer Carry",
                            sets: 1,
                            target: .distanceMeters(40),
                            restSeconds: 90
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        XCTAssertEqual(session.exercises.first?.blockKind, .carry)
        XCTAssertEqual(session.exercises.first?.blockTitle, "Loaded Carry")
        XCTAssertEqual(session.exercises.first?.metricKind, .distanceMeters)
        XCTAssertEqual(session.exercises.first?.sets.first?.suggestedDistanceMeters, 40)
        XCTAssertTrue(session.exercises.first?.tracksHold == true)

        session.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        session.exercises[0].sets[0].weightKg = 48

        let log = session.assemblePerformanceLog(userId: "u1")
        let block = log.blocks.first
        let set = block?.exercises.first?.sets.first
        let gains = MovementAPCalculator.gains(from: log)

        XCTAssertEqual(block?.kind, .carry)
        XCTAssertEqual(block?.title, "Loaded Carry")
        XCTAssertEqual(block?.exercises.first?.movementId, "carry.farmer-carry")
        XCTAssertEqual(set?.weightKg, 48)
        XCTAssertEqual(set?.distanceMeters, 40)
        XCTAssertTrue(gains.contains { $0.rankStandardMovementId == "carry.farmer-carry" })
        XCTAssertGreaterThan(gains.reduce(0) { $0 + $1.rawAP }, 0)
    }

    func testRoutineAdapterPrefersCapturedPerformanceEntriesOverAuthoredInference() {
        let routine = RoutineLibrary.placeholderRoutines.first { $0.id == "saitama-protocol" }!
        let record = RoutineCompletionRecord(
            id: "exact-routine-record",
            routineId: routine.id,
            completedAt: Date(timeIntervalSince1970: 2_500),
            elapsedSeconds: 2700,
            primaryMetric: .repCount(total: 310, bursts: [40, 30, 30, 100, 100, 10]),
            spAwarded: routine.spReward,
            performanceEntries: [
                RoutinePerformanceEntry(
                    stepId: 0,
                    source: .repTarget,
                    name: "Push-ups",
                    reps: 100,
                    bursts: [40, 30, 30]
                ),
                RoutinePerformanceEntry(
                    stepId: 1,
                    source: .repTarget,
                    name: "Sit-ups",
                    reps: 100,
                    bursts: [100]
                ),
                RoutinePerformanceEntry(
                    stepId: 2,
                    source: .repTarget,
                    name: "Bodyweight squats",
                    reps: 100,
                    bursts: [100]
                ),
                RoutinePerformanceEntry(
                    stepId: 3,
                    source: .instruction,
                    name: "10 km run — any pace, no stopping"
                )
            ]
        )

        let log = TrainingSessionAdapters.performanceLogForRoutine(
            routine,
            record: record,
            userId: "u1"
        )
        let exercises = log.blocks.first?.exercises ?? []
        let pushup = exercises.first { $0.name == "Push-ups" }
        let situp = exercises.first { $0.name == "Sit-ups" }
        let squat = exercises.first { $0.name == "Bodyweight squats" }
        let run = exercises.first { $0.name == "Run" }
        let gains = MovementAPCalculator.gains(from: log)

        XCTAssertEqual(pushup?.sets.map(\.reps), [40, 30, 30])
        XCTAssertEqual(situp?.sets.map(\.reps), [100])
        XCTAssertEqual(squat?.sets.map(\.reps), [100])
        XCTAssertEqual(run?.sets.first?.distanceMeters, 10_000)
        XCTAssertTrue(gains.contains { $0.rankStandardMovementId == "exercise.pushup" })
        XCTAssertTrue(gains.contains { $0.rankStandardMovementId == "cardio.run" })
    }

    @MainActor
    func testTimedRoutineDraftUsesTimeTrackingRows() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .custom,
            title: "Mobility",
            estimatedMinutes: 10,
            blocks: [
                TrainingBlock(
                    kind: .routine,
                    title: "Mobility Routine",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Mobility Routine",
                            sets: 1,
                            target: .timedSeconds(300),
                            restSeconds: 0
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        XCTAssertTrue(session.exercises[0].tracksHold)
        XCTAssertEqual(session.exercises[0].metricKind, .durationSeconds)
        XCTAssertEqual(session.exercises[0].sets[0].suggestedDurationSeconds, 300)
    }

    @MainActor
    func testCardioDistanceAndCalorieTargetsPreserveMetricType() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .custom,
            title: "Engine",
            estimatedMinutes: 12,
            blocks: [
                TrainingBlock(
                    kind: .cardio,
                    title: "Row",
                    cardioType: .row,
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Row",
                            sets: 1,
                            target: .distanceMeters(400),
                            restSeconds: 0
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Bike",
                            sets: 1,
                            target: .calories(20),
                            restSeconds: 0
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        XCTAssertEqual(session.exercises[0].metricKind, .distanceMeters)
        XCTAssertEqual(session.exercises[0].sets[0].suggestedDistanceMeters, 400)
        XCTAssertEqual(session.exercises[1].metricKind, .calories)
        XCTAssertEqual(session.exercises[1].sets[0].suggestedCalories, 20)

        session.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        session.confirmAsPlanned(exerciseIndex: 1, setIndex: 0)

        let log = session.assemblePerformanceLog(userId: "u1")
        XCTAssertEqual(log.blocks.first?.exercises[0].sets[0].distanceMeters, 400)
        XCTAssertEqual(log.blocks.first?.exercises[0].sets[0].reps, nil)
        XCTAssertEqual(log.blocks.first?.exercises[1].sets[0].calories, 20)
    }

    @MainActor
    func testDraftCompletionPropagatesProgramMetadataAndOnlyCompletedSets() {
        let draft = TrainingSessionDraft(
            id: "draft-program-progress",
            userId: "u1",
            source: .program,
            title: "Progress Guard",
            estimatedMinutes: 30,
            programId: "program-42",
            dayNumber: 6,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Push-up",
                            sets: 2,
                            target: .reps(8),
                            restSeconds: 90
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        session.exercises[0].sets[0].reps = 8
        session.exercises[0].sets[0].logged = true

        let performanceLog = session.assemblePerformanceLog(userId: "u1")
        let performanceExercise = performanceLog.blocks.first?.exercises.first
        let workoutLog = TrainingSessionAdapters.workoutLog(from: performanceLog)

        XCTAssertEqual(performanceLog.programId, "program-42")
        XCTAssertEqual(performanceLog.dayNumber, 6)
        XCTAssertEqual(performanceExercise?.sets.map(\.setNumber), [1])
        XCTAssertEqual(performanceExercise?.sets.first?.reps, 8)
        XCTAssertEqual(workoutLog?.programId, "program-42")
        XCTAssertEqual(workoutLog?.dayNumber, 6)
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.sets.count, 1)
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.sets.first?.reps, 8)
    }

    func testCompatibleWorkoutLogRequiresCompletedSetButKeepsSkippedContextWhenWorkExists() {
        let startedAt = Date(timeIntervalSince1970: 100)
        let completedAt = Date(timeIntervalSince1970: 700)
        let performanceLog = PerformanceLog(
            id: "perf-partial",
            userId: "u1",
            source: .program,
            title: "Partial",
            startedAt: startedAt,
            completedAt: completedAt,
            programId: "program-42",
            dayNumber: 2,
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Partial",
                    exercises: [
                        PerformanceExercise(
                            name: "Push-up",
                            plannedSets: 2,
                            plannedTarget: "8 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 8)]
                        ),
                        PerformanceExercise(
                            name: "Pull-up",
                            plannedSets: 2,
                            plannedTarget: "5 reps",
                            sets: []
                        ),
                        PerformanceExercise(
                            name: "Bodyweight Squat",
                            plannedSets: 2,
                            plannedTarget: "10 reps",
                            sets: [],
                            skipped: true
                        )
                    ]
                )
            ]
        )

        let workoutLog = TrainingSessionAdapters.workoutLog(from: performanceLog)
        XCTAssertEqual(workoutLog?.exerciseEntries.map(\.exerciseName), ["Push-up", "Bodyweight Squat"])
        XCTAssertEqual(workoutLog?.exerciseEntries.first?.sets.first?.reps, 8)
        XCTAssertEqual(workoutLog?.exerciseEntries.last?.sets.count, 0)
        XCTAssertEqual(workoutLog?.exerciseEntries.last?.skipped, true)

        var incomplete = performanceLog
        incomplete.blocks[0].exercises[0].sets = []
        XCTAssertNil(TrainingSessionAdapters.workoutLog(from: incomplete))
    }

    func testSessionLogsRequireCompletedSkillSets() {
        let log = PerformanceLog(
            id: "perf-skill-partial",
            userId: "u1",
            source: .skill,
            title: "Handstand",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 700),
            blocks: [
                PerformanceBlock(
                    id: "skill-block",
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.wall-handstand-30",
                    exercises: [
                        PerformanceExercise(
                            name: "Wall Handstand Hold",
                            plannedSets: 1,
                            plannedTarget: "30s",
                            sets: []
                        ),
                        PerformanceExercise(
                            name: "Wall Walk",
                            plannedSets: 1,
                            plannedTarget: "4 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 4)]
                        )
                    ],
                    durationSeconds: 600
                )
            ]
        )

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: log, xpAwarded: 15)
        XCTAssertEqual(sessionLogs.count, 1)
        XCTAssertEqual(sessionLogs[0].exercises.map(\.name), ["Wall Walk"])
        XCTAssertEqual(sessionLogs[0].exercises[0].sets[0].reps, 4)
        XCTAssertEqual(sessionLogs[0].xpAwarded, 15)

        var incomplete = log
        incomplete.blocks[0].exercises[1].sets = []
        XCTAssertTrue(TrainingSessionAdapters.sessionLogs(from: incomplete).isEmpty)
    }
}
