import XCTest
import UIKit
@testable import UNBOUND

extension MovementProgressServiceTests {
    func testTrainingCompletionReturnsAttributeRewardsFromMovementAP() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-complete-ap",
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
        let attribute = try XCTUnwrap(services.attribute as? MockAttributeService)
        let profile = attribute.profile(userId: "mock-user-123")

        XCTAssertGreaterThan(result.totalMovementAP, 0)
        XCTAssertEqual(result.totalMovementAP, floor(result.totalMovementAP))
        XCTAssertGreaterThanOrEqual(result.overallLevelXPGained, result.totalMovementAP)
        XCTAssertEqual(result.overallLevelXPGained, floor(result.overallLevelXPGained))
        XCTAssertGreaterThan(result.bodyMapNoveltyMultiplier, 1.0)
        XCTAssertTrue(result.bodyMapRegionRewards.contains { $0.region == .midLowerChest && $0.loadAdded > 0 })
        XCTAssertEqual(result.overallLevelReward?.xpGained ?? -1, result.overallLevelXPGained, accuracy: 0.001)
        XCTAssertGreaterThan(result.totalAttributeXPGained, 0)
        XCTAssertEqual(result.totalAttributeXPGained, floor(result.totalAttributeXPGained))
        XCTAssertTrue(result.attributeRewards.contains { $0.key == .power && $0.xpGained > 0 })
        XCTAssertFalse(result.attributeRewards.contains { $0.key == .vitality })
        XCTAssertGreaterThan(profile.value(for: .power).xp, 0)
        XCTAssertEqual(
            result.progressionReceipt.overallLevelProgressBefore,
            result.overallLevelReward?.previousProgressToNextLevel ?? -1,
            accuracy: 0.001
        )
        XCTAssertEqual(
            result.progressionReceipt.overallLevelProgressAfter,
            result.overallLevelReward?.currentProgressToNextLevel ?? -1,
            accuracy: 0.001
        )
        XCTAssertGreaterThanOrEqual(result.progressionReceipt.overallLevelProgressAfter, 0)
        XCTAssertLessThanOrEqual(result.progressionReceipt.overallLevelProgressAfter, 1)

        let overall: OverallLevelProgress = try await services.database.read(
            collection: "overall_level_progress",
            documentId: "mock-user-123"
        )
        XCTAssertEqual(overall.totalXP, result.overallLevelXPGained, accuracy: 0.001)

        let bodyMap: BodyMapProfile = try await services.database.read(
            collection: "body_map_profiles",
            documentId: "mock-user-123"
        )
        XCTAssertGreaterThan(bodyMap.load(for: .midLowerChest).lifetimeLoad, 0)
    }

    func testRecoveryCheckInAwardsVitalityWithoutMovementAP() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-recovery-vitality",
            userId: "mock-user-123",
            source: .routine,
            title: "Recovery Check-In",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    kind: .routine,
                    title: "Recovery Check-In",
                    exercises: [],
                    durationSeconds: 180,
                    notes: "vitality:recovery-check-in"
                )
            ]
        )

        let result = try await TrainingCompletionService.shared.complete(log, services: services)
        let attribute = try XCTUnwrap(services.attribute as? MockAttributeService)
        let profile = attribute.profile(userId: "mock-user-123")
        let vitalityReward = try XCTUnwrap(result.attributeRewards.first { $0.key == .vitality })

        XCTAssertEqual(result.totalMovementAP, 0)
        XCTAssertEqual(vitalityReward.xpGained, 4, accuracy: 0.001)
        XCTAssertEqual(profile.value(for: .vitality).xp, 4, accuracy: 0.001)
    }

    func testDeloadSessionAwardsVitalityOnTopOfMovementRewards() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-deload-vitality",
            userId: "mock-user-123",
            source: .program,
            title: "Push Deload",
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
                            sets: [PerformanceSet(setNumber: 1, reps: 5, weightKg: 70, rpe: 6)],
                            notes: "Deload modifier applied."
                        )
                    ]
                )
            ]
        )

        let result = try await TrainingCompletionService.shared.complete(log, services: services)
        let vitalityReward = try XCTUnwrap(result.attributeRewards.first { $0.key == .vitality })

        XCTAssertGreaterThan(result.totalMovementAP, 0)
        XCTAssertTrue(result.attributeRewards.contains { $0.key == .power && $0.xpGained > 0 })
        // Per-axis catch-up nudge: the bench-press AP put power at L1, so when the
        // 8 raw vitality XP is ingested the hex mean is 1/6 ≈ 0.16667 and vitality
        // (L0, below mean) earns the catch-up factor 1 + 2·(0.16667−0)/100 = 1.003333.
        // 8 × 1.003333 = 8.026666…
        XCTAssertEqual(vitalityReward.xpGained, 8.0266666666666666, accuracy: 0.001)
    }

    func testTrainingCompletionRecordPreventsDuplicateCompatibleWorkoutSaves() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-complete-once",
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

        let first = try await TrainingCompletionService.shared.complete(log, services: services)
        let second = try await TrainingCompletionService.shared.complete(log, services: services)
        let workoutLog = try XCTUnwrap(services.workoutLog as? MockWorkoutLogService)
        let database = try XCTUnwrap(services.database as? MockDatabaseService)
        let record: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: "perf-complete-once"
        )

        XCTAssertFalse(first.wasAlreadyCompleted)
        XCTAssertTrue(second.wasAlreadyCompleted)
        XCTAssertEqual(workoutLog.logs.count, 1)
        XCTAssertEqual(record.performanceLogId, "perf-complete-once")
        XCTAssertEqual(second.savedWorkoutLogId, first.savedWorkoutLogId)
        XCTAssertEqual(second.overallLevelXPGained, first.overallLevelXPGained, accuracy: 0.001)
        XCTAssertEqual(second.movementAPGains, first.movementAPGains)
    }

    func testConcurrentTrainingCompletionDoesNotReplayCompletionCascade() async throws {
        let database = TestProgressionDatabase(delayMissingCompletionRecordReads: true)
        let workoutLog = MockWorkoutLogService()
        let services = makeServices(database: database, workoutLog: workoutLog)
        let sessionXP = try XCTUnwrap(services.sessionXP as? MockSessionXPService)
        let service = TrainingCompletionService(
            squadMission: NoOpSquadMissionService(),
            friendChallenge: NoOpFriendChallengeService()
        )
        let log = benchPerformanceLog(id: "perf-concurrent-once")

        async let first = service.complete(log, services: services)
        async let second = service.complete(log, services: services)
        let (firstResult, secondResult) = try await (first, second)
        let completionRecord: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: "perf-concurrent-once"
        )
        let alreadyCompletedCount = [firstResult.wasAlreadyCompleted, secondResult.wasAlreadyCompleted]
            .filter { $0 }
            .count

        XCTAssertEqual(alreadyCompletedCount, 1)
        XCTAssertEqual(workoutLog.compatibleHistorySaveCallCount, 1)
        XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 1)
        XCTAssertEqual(completionRecord.performanceLogId, "perf-concurrent-once")
    }

}
