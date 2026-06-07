import XCTest
import UIKit
@testable import UNBOUND

extension MovementProgressServiceTests {
    func testTrainingCompletionQuarantinesCompatibleWorkoutLogWhenWriterIsMissing() async throws {
        let database = MockDatabaseService()
        let workoutLog = NonCompatibilityWriterWorkoutLogService()
        let services = makeServices(database: database, workoutLog: workoutLog)
        let log = PerformanceLog(
            id: "perf-quarantined-compatible-write",
            userId: "mock-user-123",
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

        let result = try await TrainingCompletionService.shared.complete(log, services: services)
        let savedWorkoutLogId = try XCTUnwrap(result.savedWorkoutLogId)
        let saved: WorkoutLog = try await database.read(collection: "workoutLogs", documentId: savedWorkoutLogId)

        XCTAssertTrue(workoutLog.logs.isEmpty)
        XCTAssertEqual(saved.id, savedWorkoutLogId)
        XCTAssertEqual(saved.plannedWorkoutName, "Push")
        XCTAssertEqual(saved.exerciseEntries.first?.exerciseName, "Bench Press")
    }

    func testTrainingCompletionRecordPreventsDuplicateSkillSessionLogs() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-skill-once",
            userId: "mock-user-123",
            source: .skill,
            title: "Wall Handstand",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    id: "skill-block",
                    kind: .skill,
                    title: "Wall Handstand",
                    skillId: "hs.wall-handstand-30",
                    exercises: [
                        PerformanceExercise(
                            name: "Wall Handstand Hold",
                            plannedSets: 1,
                            plannedTarget: "30s",
                            sets: [PerformanceSet(setNumber: 1, holdSeconds: 30, rpe: 7)]
                        )
                    ],
                    durationSeconds: 300
                )
            ]
        )

        let first = try await TrainingCompletionService.shared.complete(log, services: services, skillXPAwarded: 25)
        let second = try await TrainingCompletionService.shared.complete(log, services: services, skillXPAwarded: 25)
        let database = try XCTUnwrap(services.database as? MockDatabaseService)
        let sessionLogKeys = database.store.keys.filter { $0.hasPrefix("sessionLogs/") }

        XCTAssertFalse(first.wasAlreadyCompleted)
        XCTAssertTrue(second.wasAlreadyCompleted)
        XCTAssertEqual(sessionLogKeys, ["sessionLogs/perf-skill-once:hs.wall-handstand-30:session"])
        XCTAssertEqual(second.savedSessionLogIds, first.savedSessionLogIds)
        XCTAssertEqual(second.skillXPGained, first.skillXPGained)
        XCTAssertEqual(second.progressionReceipt.skillXPGained, first.progressionReceipt.skillXPGained)
    }

    func testQuickLogShapedSkillCompletionWritesUnifiedAndCompatibleHistory() async throws {
        let services = ServiceContainer.mock
        let log = TrainingSessionAdapters.performanceLogForSkillSession(
            id: "perf-quick-log-wall-handstand",
            userId: "mock-user-123",
            skillId: "hs.wall-handstand-30",
            skillTitle: "Wall Handstand",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 100),
            durationSeconds: 0,
            exercises: [
                LoggedExercise(
                    name: "Wall Walk",
                    sets: [LoggedSet(reps: 3, holdSeconds: nil, weightKg: nil, rpe: 7)]
                )
            ]
        )

        let result = try await TrainingCompletionService.shared.complete(log, services: services, skillXPAwarded: 10)
        let database = try XCTUnwrap(services.database as? MockDatabaseService)
        let performance: PerformanceLog = try await database.read(
            collection: "performanceLogs",
            documentId: "perf-quick-log-wall-handstand"
        )
        let workoutLog = try XCTUnwrap(result.savedWorkoutLogId)
        let sessionLog = try XCTUnwrap(result.savedSessionLogIds.first)
        let workoutService = try XCTUnwrap(services.workoutLog as? MockWorkoutLogService)
        let compatibleWorkout = try XCTUnwrap(workoutService.logs.first { $0.id == workoutLog })
        let compatibleSession: SessionLog = try await database.read(collection: "sessionLogs", documentId: sessionLog)

        XCTAssertEqual(performance.blocks.first?.skillId, "hs.wall-handstand-30")
        XCTAssertEqual(performance.blocks.first?.durationSeconds, 0)
        XCTAssertEqual(compatibleWorkout.exerciseEntries.first?.exerciseName, "Wall Walk")
        XCTAssertEqual(compatibleWorkout.exerciseEntries.first?.sets.first?.reps, 3)
        XCTAssertEqual(compatibleSession.skillId, "hs.wall-handstand-30")
        XCTAssertEqual(compatibleSession.exercises.first?.sets.first?.reps, 3)
        XCTAssertGreaterThanOrEqual(result.progressionReceipt.totalMovementAP, 0)
    }

    func testOverallLevelServicePersistsNoveltyAdjustedXPOncePerSource() async throws {
        let database = MockDatabaseService()
        let service = OverallLevelService.shared

        let first = await service.ingest(
            rawAP: 100,
            noveltyMultiplier: 1.5,
            sourceLogId: "perf-lv",
            userId: "u1",
            at: Date(timeIntervalSince1970: 200),
            database: database
        )
        let duplicate = await service.ingest(
            rawAP: 100,
            noveltyMultiplier: 1.5,
            sourceLogId: "perf-lv",
            userId: "u1",
            at: Date(timeIntervalSince1970: 300),
            database: database
        )
        let progress: OverallLevelProgress = try await database.read(
            collection: "overall_level_progress",
            documentId: "u1"
        )

        XCTAssertEqual(first.xpGained, 150, accuracy: 0.001)
        XCTAssertEqual(duplicate.xpGained, 0, accuracy: 0.001)
        XCTAssertEqual(progress.totalXP, 150, accuracy: 0.001)
        XCTAssertEqual(progress.processedSourceLogIds, ["perf-lv"])
    }

    func testOverallLevelServiceStoresWholeXPAndNeverPenalizesLowNovelty() async throws {
        let database = MockDatabaseService()
        let service = OverallLevelService.shared

        let reward = await service.ingest(
            rawAP: 19.2,
            noveltyMultiplier: 0.5,
            sourceLogId: "perf-whole-lv",
            userId: "u1",
            at: Date(timeIntervalSince1970: 200),
            database: database
        )
        let progress: OverallLevelProgress = try await database.read(
            collection: "overall_level_progress",
            documentId: "u1"
        )

        XCTAssertEqual(reward.xpGained, 19, accuracy: 0.001)
        XCTAssertEqual(progress.totalXP, 19, accuracy: 0.001)
    }

    func testOverallLevelServiceGrantsFlatXPOncePerSource() async throws {
        let database = MockDatabaseService()
        let service = OverallLevelService.shared
        let date = Date(timeIntervalSince1970: 400)

        let first = try await service.grantFlatXPStrict(
            amount: 120,
            sourceId: "weekly-vow-bonus:perf-1",
            userId: "u-flat-vow",
            at: date,
            database: database
        )
        let duplicate = try await service.grantFlatXPStrict(
            amount: 120,
            sourceId: "weekly-vow-bonus:perf-1",
            userId: "u-flat-vow",
            at: date.addingTimeInterval(60),
            database: database
        )
        let progress: OverallLevelProgress = try await database.read(
            collection: "overall_level_progress",
            documentId: "u-flat-vow"
        )

        XCTAssertEqual(first.xpGained, 120, accuracy: 0.001)
        XCTAssertEqual(duplicate.xpGained, 120, accuracy: 0.001)
        XCTAssertEqual(progress.totalXP, 120, accuracy: 0.001)
        XCTAssertEqual(progress.processedSourceLogIds, ["weekly-vow-bonus:perf-1"])
    }

    func testOverallLevelCostCapsAfterSoftCap() {
        let level100XP = OverallLevelCurve.xpRequired(forLevel: 100)
        let level101XP = OverallLevelCurve.xpRequired(forLevel: 101)
        let level500XP = OverallLevelCurve.xpRequired(forLevel: 500)
        let level501XP = OverallLevelCurve.xpRequired(forLevel: 501)
        let level500Midpoint = level500XP + OverallLevelCurve.cappedXPPerLevel / 2

        XCTAssertEqual(level101XP - level100XP, OverallLevelCurve.cappedXPPerLevel, accuracy: 0.001)
        XCTAssertEqual(level501XP - level500XP, OverallLevelCurve.cappedXPPerLevel, accuracy: 0.001)
        XCTAssertEqual(OverallLevelCurve.level(forXP: level500XP), 500)
        XCTAssertEqual(OverallLevelCurve.level(forXP: level500XP - 0.1), 499)
        XCTAssertEqual(OverallLevelCurve.progressFraction(forXP: level500Midpoint), 0.5, accuracy: 0.001)
    }

}
