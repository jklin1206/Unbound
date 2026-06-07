import XCTest
import UIKit
@testable import UNBOUND

extension MovementProgressServiceTests {
    func testVariantMovementRollsAPIntoRankStandard() async throws {
        let log = PerformanceLog(
            id: "perf-1",
            userId: "u1",
            source: .program,
            title: "Pull",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Pull",
                    exercises: [
                        PerformanceExercise(
                            name: "Lat Pulldown (Neutral)",
                            plannedSets: 1,
                            plannedTarget: "10 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 10, weightKg: 70, rpe: 8)]
                        )
                    ]
                )
            ]
        )

        let gains = MovementAPCalculator.gains(from: log)

        XCTAssertEqual(gains.count, 1)
        XCTAssertEqual(gains[0].movementId, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(gains[0].rankStandardMovementId, "exercise.lat-pulldown")
        XCTAssertEqual(gains[0].standardDisplayName, "Lat Pulldown (Bar)")
        XCTAssertGreaterThan(gains[0].rawAP, 0)
        XCTAssertEqual(gains[0].rawAP, floor(gains[0].rawAP))
    }

    func testWorkoutLogAPCanonicalizesSavedMovementIdsAndKeepsLegacyNamesWorking() async throws {
        let idBacked = workoutLog(
            id: "workout-id-backed-pulldown",
            exerciseName: "Saved Pulldown Label",
            movementId: "exercise.lat-pulldown-neutral",
            rankStandardMovementId: "exercise.lat-pulldown-neutral"
        )
        let legacyName = workoutLog(
            id: "workout-legacy-pulldown",
            exerciseName: "lat_pulldown_neutral"
        )

        let idBackedGain = try XCTUnwrap(MovementAPCalculator.gains(from: idBacked).first)
        let legacyGain = try XCTUnwrap(MovementAPCalculator.gains(from: legacyName).first)

        XCTAssertEqual(idBackedGain.movementId, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(idBackedGain.rankStandardMovementId, "exercise.lat-pulldown")
        XCTAssertEqual(idBackedGain.standardDisplayName, "Lat Pulldown (Bar)")
        XCTAssertEqual(legacyGain.movementId, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(legacyGain.rankStandardMovementId, "exercise.lat-pulldown")
    }

    func testPersistedProgressAggregatesVariantsByRankStandard() async throws {
        let database = MockDatabaseService()
        let service = MovementProgressService.shared
        let log = PerformanceLog(
            id: "perf-variants",
            userId: "u1",
            source: .program,
            title: "Pull",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Pull",
                    exercises: [
                        PerformanceExercise(
                            name: "Lat Pulldown (Neutral)",
                            plannedSets: 1,
                            plannedTarget: "10 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 10, weightKg: 70, rpe: 8)]
                        ),
                        PerformanceExercise(
                            name: "Wide-Grip Lat Pulldown",
                            plannedSets: 1,
                            plannedTarget: "8 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 8, weightKg: 65, rpe: 8)]
                        )
                    ]
                )
            ]
        )

        let result = await service.ingest(log, database: database)
        let state: MovementProgressState = try await database.read(
            collection: "movement_progress",
            documentId: "u1:exercise.lat-pulldown"
        )

        XCTAssertEqual(result.updatedStates.count, 1)
        XCTAssertEqual(state.rankStandardMovementId, "exercise.lat-pulldown")
        XCTAssertEqual(Set(state.contributingMovementIds), ["exercise.lat-pulldown-neutral", "exercise.wide-grip-lat-pulldown"])
        XCTAssertEqual(state.processedSourceLogIds, ["perf-variants"])
        XCTAssertEqual(state.provenTier, .initiate)
        XCTAssertEqual(state.totalAP, result.totalAP, accuracy: 0.001)
        XCTAssertGreaterThan(state.totalAP, 0)
    }

    func testExistingProgressStateRefreshesCurrentRankTemplateBeforeTierDerivation() async throws {
        let database = MockDatabaseService()
        let service = MovementProgressService.shared
        let stale = MovementProgressState(
            userId: "u1",
            rankStandardMovementId: "exercise.hanging-leg-raise",
            displayName: "Hanging Leg Raise",
            rankTemplate: .holdControl,
            provenTier: .initiate
        )
        try await database.create(
            stale,
            collection: "movement_progress",
            documentId: "u1:exercise.hanging-leg-raise"
        )

        let log = PerformanceLog(
            id: "perf-hlr-refresh",
            userId: "u1",
            source: .custom,
            title: "Core",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    kind: .bodyweight,
                    title: "Core",
                    exercises: [
                        PerformanceExercise(
                            name: "Hanging Leg Raise",
                            plannedSets: 1,
                            plannedTarget: "20 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 20, rpe: 8)]
                        )
                    ]
                )
            ]
        )

        _ = await service.ingest(log, database: database)
        let state: MovementProgressState = try await database.read(
            collection: "movement_progress",
            documentId: "u1:exercise.hanging-leg-raise"
        )

        XCTAssertEqual(state.rankTemplate, .bodyweightReps)
        XCTAssertEqual(state.bestReps, 20)
        XCTAssertGreaterThan(state.provenTier.rawValue, stale.provenTier.rawValue)
    }

    func testRepeatedSourceLogDoesNotDoubleCountAP() async throws {
        let database = MockDatabaseService()
        let service = MovementProgressService.shared
        let log = PerformanceLog(
            id: "perf-once",
            userId: "u1",
            source: .program,
            title: "Push",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Push",
                    exercises: [
                        PerformanceExercise(
                            name: "Bench Press",
                            plannedSets: 1,
                            plannedTarget: "5 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 5, weightKg: 100, rpe: 8)]
                        )
                    ]
                )
            ]
        )

        let first = await service.ingest(log, database: database)
        let second = await service.ingest(log, database: database)
        let state: MovementProgressState = try await database.read(
            collection: "movement_progress",
            documentId: "u1:exercise.bench-press"
        )

        XCTAssertGreaterThan(first.totalAP, 0)
        XCTAssertEqual(second.totalAP, 0)
        XCTAssertEqual(state.totalAP, first.totalAP, accuracy: 0.001)
    }

    func testHoldAndCardioMetricsEarnAPWithoutRepLoggerAssumptions() async throws {
        let log = PerformanceLog(
            id: "perf-mixed",
            userId: "u1",
            source: .custom,
            title: "Mixed",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.wall-handstand-30",
                    exercises: [
                        PerformanceExercise(
                            name: "Wall Handstand Hold",
                            plannedSets: 1,
                            plannedTarget: "30s",
                            sets: [PerformanceSet(setNumber: 1, holdSeconds: 35, rpe: 7, qualityFlags: [.clean])]
                        )
                    ]
                ),
                PerformanceBlock(
                    kind: .cardio,
                    title: "Row",
                    cardioType: .row,
                    exercises: [],
                    durationSeconds: 90,
                    distanceMeters: 400,
                    calories: 18
                )
            ]
        )

        let gains = MovementAPCalculator.gains(from: log)

        XCTAssertEqual(gains.map(\.rankStandardMovementId).sorted(), ["cardio.row", "skill-drill.wall-handstand"])
        XCTAssertTrue(gains.allSatisfy { $0.rawAP > 0 })
        XCTAssertEqual(gains.first(where: { $0.rankStandardMovementId == "skill-drill.wall-handstand" })?.holdSeconds, 35)
        XCTAssertEqual(gains.first(where: { $0.rankStandardMovementId == "cardio.row" })?.distanceMeters, 400)
    }

}
