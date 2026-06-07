import XCTest
@testable import UNBOUND

@MainActor
extension TrainingSessionAdapterTests {
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
                    selectedRungId: "hs.wall-handstand-30.main",
                    selectedRungSource: .main,
                    selectedRungReason: "Train direct Handstand work.",
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
        XCTAssertEqual(log.blocks[1].selectedRungId, "hs.wall-handstand-30.main")
        XCTAssertEqual(log.blocks[1].selectedRungSource, .main)
        XCTAssertEqual(log.blocks[1].selectedRungReason, "Train direct Handstand work.")
        XCTAssertEqual(log.blocks[0].exercises[0].movementId, "exercise.pullup")
        XCTAssertEqual(log.blocks[0].exercises[0].rankStandardMovementId, "exercise.pullup")
        XCTAssertEqual(log.blocks[1].exercises[0].movementId, "skill-drill.wall-handstand")
        XCTAssertEqual(log.blocks[1].exercises[0].rankStandardMovementId, "skill-drill.wall-handstand")
        XCTAssertEqual(log.blocks[1].exercises[0].sets[0].holdSeconds, 34)

        let sessionLogs = TrainingSessionAdapters.sessionLogs(from: log, xpAwarded: 20)
        XCTAssertEqual(sessionLogs.first?.skillId, "hs.wall-handstand-30")
        XCTAssertEqual(sessionLogs.first?.selectedRungId, "hs.wall-handstand-30.main")
        XCTAssertEqual(sessionLogs.first?.selectedRungSource, .main)
        XCTAssertEqual(sessionLogs.first?.selectedRungReason, "Train direct Handstand work.")
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

}
