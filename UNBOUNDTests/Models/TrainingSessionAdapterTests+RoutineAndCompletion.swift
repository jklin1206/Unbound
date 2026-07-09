import XCTest
@testable import UNBOUND

@MainActor
extension TrainingSessionAdapterTests {
    func testRoutineAdapterPrefersCapturedPerformanceEntriesOverAuthoredInference() {
        let routine = RoutineLibrary.routines.first { $0.id == "saitama-protocol" }!
        let record = RoutineCompletionRecord(
            id: "exact-routine-record",
            routineId: routine.id,
            completedAt: Date(timeIntervalSince1970: 2_500),
            elapsedSeconds: 2700,
            primaryMetric: .repCount(total: 310, bursts: [40, 30, 30, 100, 100, 10]),
            spAwarded: 0,
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
                    name: "Run",
                    distanceMeters: 10_000
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

    func testRoutineAdapterDoesNotInferCapturedInstructionOnlyWork() {
        let routine = RoutineLibrary.routines.first { $0.id == "daily-quest" }!
        let record = RoutineCompletionRecord(
            id: "instruction-only-routine-record",
            routineId: routine.id,
            completedAt: Date(timeIntervalSince1970: 2_600),
            elapsedSeconds: 120,
            primaryMetric: .steps(done: 1, total: 1),
            spAwarded: 0,
            performanceEntries: [
                RoutinePerformanceEntry(
                    stepId: 3,
                    source: .instruction,
                    name: "2 km run (or 12-min treadmill walk/jog)"
                )
            ]
        )

        let log = TrainingSessionAdapters.performanceLogForRoutine(
            routine,
            record: record,
            userId: "u1"
        )
        let exercises = log.blocks.first?.exercises ?? []
        let gains = MovementAPCalculator.gains(from: log)

        XCTAssertTrue(exercises.isEmpty)
        XCTAssertEqual(gains.reduce(0) { $0 + $1.rawAP }, 0)
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

    func testCompatibleWorkoutLogDoesNotInventProgramIdForSkillSource() {
        let performanceLog = PerformanceLog(
            id: "perf-skill-source",
            userId: "u1",
            source: .skill,
            title: "Handstand",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 700),
            blocks: [
                PerformanceBlock(
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.wall-handstand-30",
                    exercises: [
                        PerformanceExercise(
                            name: "Wall Walk",
                            plannedSets: 1,
                            plannedTarget: "4 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 4)]
                        )
                    ]
                )
            ]
        )

        let workoutLog = TrainingSessionAdapters.workoutLog(from: performanceLog)
        XCTAssertEqual(workoutLog?.programId, "")
        XCTAssertEqual(workoutLog?.dayNumber, 0)
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
