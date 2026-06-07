import XCTest
import UIKit
@testable import UNBOUND

extension MovementProgressServiceTests {
    func testTrainingCompletionDoesNotFinalizeWhenMovementProgressPersistenceFails() async throws {
        let database = TestProgressionDatabase(failingCreateCollections: ["movement_progress"])
        let services = makeServices(database: database, workoutLog: MockWorkoutLogService())
        let service = TrainingCompletionService(
            squadMission: NoOpSquadMissionService(),
            friendChallenge: NoOpFriendChallengeService()
        )
        let log = benchPerformanceLog(id: "perf-progress-write-failure")

        do {
            _ = try await service.complete(log, services: services)
            XCTFail("Completion should fail when critical movement progression persistence fails")
        } catch {
            // Expected: the strict progression path must propagate the write error.
        }

        do {
            let _: TrainingCompletionRecord = try await database.read(
                collection: "training_completion_records",
                documentId: "perf-progress-write-failure"
            )
            XCTFail("Completion record must not be written after progression persistence failure")
        } catch {
            // Expected: no finalized completion record.
        }
    }

    func testTrainingCompletionRetriesAfterMovementAPGainPersistenceFailure() async throws {
        try await assertCompletionRetriesAfterSingleCreateFailure(in: "movement_ap_gains")
    }

    func testTrainingCompletionRetriesAfterBodyMapPersistenceFailure() async throws {
        try await assertCompletionRetriesAfterSingleCreateFailure(in: "body_map_profiles")
    }

    func testTrainingCompletionRetriesAfterOverallLevelPersistenceFailure() async throws {
        try await assertCompletionRetriesAfterSingleCreateFailure(in: "overall_level_progress")
    }

    func testTrainingCompletionRetryAfterCompletionRecordFailureReusesCanonicalRewards() async throws {
        let database = TestProgressionDatabase(failingCreateAttempts: ["training_completion_records": 1])
        let services = makeServices(database: database, workoutLog: MockWorkoutLogService())
        let attribute = try XCTUnwrap(services.attribute as? MockAttributeService)
        let sessionXP = try XCTUnwrap(services.sessionXP as? MockSessionXPService)
        let service = TrainingCompletionService(
            squadMission: NoOpSquadMissionService(),
            friendChallenge: NoOpFriendChallengeService()
        )
        let log = TrainingSessionAdapters.performanceLogForSkillSession(
            id: "perf-retry-completion-record",
            userId: "mock-user-123",
            skillId: "hs.wall-handstand-30",
            skillTitle: "Wall Handstand",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            durationSeconds: 300,
            exercises: [
                LoggedExercise(
                    name: "Wall Handstand Hold",
                    sets: [LoggedSet(reps: 0, holdSeconds: 30, weightKg: nil, rpe: 7)]
                )
            ]
        )

        do {
            _ = try await service.complete(log, services: services, skillXPAwarded: 25)
            XCTFail("First completion should fail at the final completion record")
        } catch {
            // Expected: all strict reward writes happened, but no canonical record exists yet.
        }

        let profileAfterFailedAttempt = attribute.profile(userId: "mock-user-123")
        let failedReceipt: TrainingCompletionReplayReceipt = try await database.read(
            collection: "training_completion_replay_receipts",
            documentId: log.id
        )
        XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 1)

        let interleaved = try await service.complete(
            benchPerformanceLog(id: "perf-interleaved-after-failed-skill"),
            services: services
        )
        XCTAssertGreaterThan(interleaved.overallLevelXPGained, 0)

        let retryLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: log.id,
            userId: "mock-user-123",
            skillId: "hs.wall-handstand-30",
            skillTitle: "Wall Handstand",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            durationSeconds: 300,
            exercises: [
                LoggedExercise(
                    name: "Wall Handstand Hold",
                    sets: [LoggedSet(reps: 0, holdSeconds: 30, weightKg: nil, rpe: 7)]
                )
            ]
        )

        let result = try await service.complete(retryLog, services: services, skillXPAwarded: 25)
        let profileAfterRetry = attribute.profile(userId: "mock-user-123")
        let record: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertFalse(result.wasAlreadyCompleted)
        XCTAssertEqual(record.performanceLogId, log.id)
        XCTAssertGreaterThan(profileAfterRetry.value(for: .power).xp, profileAfterFailedAttempt.value(for: .power).xp)
        XCTAssertEqual(result.attributeProfileAfter, failedReceipt.replay.attributeProfileAfter)
        XCTAssertEqual(result.overallLevelReward, failedReceipt.replay.overallLevelReward)
        XCTAssertGreaterThan(result.attributeRewards.reduce(0) { $0 + $1.xpGained }, 0)
        XCTAssertGreaterThan(result.bodyMapRegionRewards.count, 0)
        XCTAssertGreaterThan(result.overallLevelXPGained, 0)
        XCTAssertEqual(result.skillXPGained, 25)
        XCTAssertEqual(result.streakCount, 1)
        XCTAssertTrue(result.streakExtended)
        XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 2)
        let retrySessionLogCount = await database.countKeys(prefix: "sessionLogs/\(log.id):hs.wall-handstand-30:session")
        XCTAssertEqual(retrySessionLogCount, 1)
        XCTAssertNotNil(record.replay)
    }

    func testTrainingCompletionRetryAfterReplayReceiptFailureUsesProgressionCheckpoint() async throws {
        let database = TestProgressionDatabase(failingCreateAttempts: ["training_completion_replay_receipts": 1])
        let services = makeServices(database: database, workoutLog: MockWorkoutLogService())
        let sessionXP = try XCTUnwrap(services.sessionXP as? MockSessionXPService)
        let service = TrainingCompletionService(
            squadMission: NoOpSquadMissionService(),
            friendChallenge: NoOpFriendChallengeService()
        )
        let log = benchPerformanceLog(id: "perf-retry-missing-replay-receipt")

        do {
            _ = try await service.complete(log, services: services)
            XCTFail("First completion should fail while writing the replay receipt")
        } catch {
            // Expected: progression/session side effects may have landed, but no final record exists.
        }

        let checkpoint: TrainingCompletionProgressionReceipt = try await database.read(
            collection: "training_completion_progression_receipts",
            documentId: log.id
        )
        XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 1)

        let interleaved = try await service.complete(
            benchPerformanceLog(id: "perf-interleaved-after-missing-replay"),
            services: services
        )
        XCTAssertGreaterThan(interleaved.overallLevelXPGained, 0)
        XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 2)

        let retry = try await service.complete(log, services: services)
        let record: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertFalse(retry.wasAlreadyCompleted)
        XCTAssertEqual(record.performanceLogId, log.id)
        XCTAssertEqual(retry.movementAPGains, checkpoint.replay.movementAPGains)
        XCTAssertEqual(retry.movementProgressStates, checkpoint.replay.movementProgressStates)
        XCTAssertEqual(retry.attributeRewards, checkpoint.replay.attributeRewards)
        XCTAssertEqual(retry.attributeProfileAfter, checkpoint.replay.attributeProfileAfter)
        XCTAssertEqual(retry.bodyMapRegionRewards, checkpoint.replay.bodyMapRegionRewards)
        XCTAssertEqual(retry.overallLevelReward, checkpoint.replay.overallLevelReward)
        XCTAssertEqual(retry.streakCount, 1)
        XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 2)
    }

}
