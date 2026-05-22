import XCTest
@testable import UNBOUND

final class TrainingSessionDraftStoreTests: XCTestCase {
    func testRecentDraftStoreSavesMostRecentFirstAndDedupes() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("recent-training-drafts.json")
        let store = TrainingSessionDraftStore(fileURL: fileURL)

        var first = TrainingSessionDraft(
            id: "draft-1",
            userId: "u1",
            source: .custom,
            title: "Mixed Pull",
            estimatedMinutes: 30,
            blocks: [
                TrainingBlock(
                    kind: .custom,
                    title: "Pull-up",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Pull-up",
                            sets: 3,
                            target: .repsRange(5, 8),
                            restSeconds: 120
                        )
                    ]
                )
            ]
        )
        let second = TrainingSessionDraft(
            id: "draft-2",
            userId: "u1",
            source: .custom,
            title: "Cardio Carry",
            estimatedMinutes: 20,
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
                        )
                    ]
                )
            ]
        )

        store.saveRecent(first)
        store.saveRecent(second)
        first.title = "Mixed Pull Edited"
        store.saveRecent(first)

        let recent = store.loadRecent()
        XCTAssertEqual(recent.map(\.id), ["draft-1", "draft-2"])
        XCTAssertEqual(recent.first?.title, "Mixed Pull Edited")
        XCTAssertEqual(recent.first?.blocks.first?.prescriptions.first?.target, .repsRange(5, 8))
        XCTAssertEqual(recent.last?.blocks.first?.cardioType, .row)
    }

    func testRecentDraftStorePersistsProgramMetadataAndHonorsLimit() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("recent-training-drafts.json")
        let store = TrainingSessionDraftStore(fileURL: fileURL)

        let first = TrainingSessionDraft(
            id: "draft-program-1",
            userId: "u1",
            source: .program,
            title: "Day 1",
            estimatedMinutes: 30,
            programId: "program-42",
            dayNumber: 1,
            blocks: []
        )
        let second = TrainingSessionDraft(
            id: "draft-program-2",
            userId: "u1",
            source: .program,
            title: "Day 2",
            estimatedMinutes: 35,
            programId: "program-42",
            dayNumber: 2,
            blocks: []
        )

        store.saveRecent(first, limit: 1)
        store.saveRecent(second, limit: 1)

        let recent = store.loadRecent()
        XCTAssertEqual(recent.map(\.id), ["draft-program-2"])
        XCTAssertEqual(recent.first?.programId, "program-42")
        XCTAssertEqual(recent.first?.dayNumber, 2)
        XCTAssertEqual(recent.first?.source, .program)
    }

    func testRecentDraftStoreTreatsNegativeLimitAsZero() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("recent-training-drafts.json")
        let store = TrainingSessionDraftStore(fileURL: fileURL)

        let draft = TrainingSessionDraft(
            id: "draft-zero-limit",
            userId: "u1",
            source: .custom,
            title: "No Recent",
            estimatedMinutes: 20,
            blocks: []
        )

        store.saveRecent(draft, limit: -1)

        XCTAssertTrue(store.loadRecent().isEmpty)
    }
}

@MainActor
final class TrainingCompletionIntegrationGuardrailTests: XCTestCase {
    func testLegacyProgressionWritesCompletionReceiptAndDedupes() async throws {
        let services = ServiceContainer.mock
        let log = completedBenchLog(id: "perf-legacy-receipt")

        let first = await TrainingCompletionService.shared.recordProgressionForLegacyWorkout(
            log,
            services: services
        )
        let second = await TrainingCompletionService.shared.recordProgressionForLegacyWorkout(
            log,
            services: services
        )

        let database = try XCTUnwrap(services.database as? MockDatabaseService)
        let record: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )
        let progress: OverallLevelProgress = try await database.read(
            collection: "overall_level_progress",
            documentId: "mock-user-123"
        )

        XCTAssertFalse(first.wasAlreadyCompleted)
        XCTAssertGreaterThan(first.totalMovementAP, 0)
        XCTAssertEqual(record.performanceLogId, log.id)
        XCTAssertEqual(record.userId, "mock-user-123")
        XCTAssertTrue(second.wasAlreadyCompleted)
        XCTAssertEqual(second.savedPerformanceLogId, log.id)
        XCTAssertEqual(second.totalMovementAP, 0)
        XCTAssertEqual(progress.processedSourceLogIds, [log.id])
    }

    func testCompletionWithNoCompletedSetsWritesNoRewardBridgesButRecordsReceipt() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-empty-completion",
            userId: "mock-user-123",
            source: .program,
            title: "Empty Completion",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            programId: "program-empty",
            dayNumber: 3,
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Empty Completion",
                    exercises: [
                        PerformanceExercise(
                            name: "Bench Press",
                            plannedSets: 3,
                            plannedTarget: "5 reps",
                            sets: []
                        )
                    ]
                )
            ]
        )

        let first = try await TrainingCompletionService.shared.complete(log, services: services)
        let second = try await TrainingCompletionService.shared.complete(log, services: services)
        let database = try XCTUnwrap(services.database as? MockDatabaseService)
        let workoutLog = try XCTUnwrap(services.workoutLog as? MockWorkoutLogService)
        let record: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertFalse(first.wasAlreadyCompleted)
        XCTAssertEqual(first.savedPerformanceLogId, log.id)
        XCTAssertNil(first.savedWorkoutLogId)
        XCTAssertTrue(first.savedSessionLogIds.isEmpty)
        XCTAssertEqual(first.totalMovementAP, 0)
        XCTAssertEqual(first.totalAttributeXPGained, 0)
        XCTAssertEqual(first.overallLevelXPGained, 0)
        XCTAssertTrue(workoutLog.logs.isEmpty)
        XCTAssertFalse(database.store.keys.contains { $0.hasPrefix("sessionLogs/") })
        XCTAssertEqual(record.performanceLogId, log.id)
        XCTAssertTrue(second.wasAlreadyCompleted)
        XCTAssertEqual(second.savedPerformanceLogId, log.id)
    }

    private func completedBenchLog(id: String) -> PerformanceLog {
        PerformanceLog(
            id: id,
            userId: "mock-user-123",
            source: .program,
            title: "Bench",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            programId: "program-42",
            dayNumber: 1,
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Bench",
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
    }
}
