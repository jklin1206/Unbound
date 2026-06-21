import XCTest
import UIKit
@testable import UNBOUND

@MainActor
final class MovementProgressServiceTests: XCTestCase {
    func benchGain(sourceLogId: String, rawAP: Double) -> MovementAPGain {
        MovementAPGain(
            userId: "u1",
            sourceLogId: sourceLogId,
            sourceExerciseId: "bench-set",
            movementId: "exercise.bench-press",
            rankStandardMovementId: "exercise.bench-press",
            movementDisplayName: "Bench Press",
            standardDisplayName: "Bench Press",
            rankTemplate: .barbellStrength,
            rawAP: rawAP,
            reps: 5,
            loadKg: 100,
            estimatedOneRepMaxKg: 116.6,
            occurredAt: Date(timeIntervalSince1970: 200)
        )
    }

    func benchPerformanceLog(id: String, userId: String = "mock-user-123") -> PerformanceLog {
        PerformanceLog(
            id: id,
            userId: userId,
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
    }

    func workoutLog(
        id: String,
        exerciseName: String,
        movementId: String? = nil,
        rankStandardMovementId: String? = nil
    ) -> WorkoutLog {
        WorkoutLog(
            id: id,
            userId: "u1",
            programId: "program-catalog-regression",
            dayNumber: 1,
            plannedWorkoutName: "Pull",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "entry-\(id)",
                    exerciseName: exerciseName,
                    movementId: movementId,
                    rankStandardMovementId: rankStandardMovementId,
                    plannedSets: 1,
                    plannedReps: "10",
                    sets: [
                        SetLog(
                            id: "set-\(id)",
                            setNumber: 1,
                            weightKg: 70,
                            reps: 10,
                            rpe: 8,
                            isWarmup: false
                        )
                    ],
                    skipped: false,
                    notes: nil
                )
            ]
        )
    }

    func onePixelImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    func makeServices(
        database: any DatabaseServiceProtocol,
        workoutLog: any WorkoutLogServiceProtocol
    ) -> ServiceContainer {
        ServiceContainer(
            auth: MockAuthService(),
            database: database,
            analytics: AnalyticsService.shared,
            subscription: MockSubscriptionService(),
            paywall: MockPaywallService(),
            user: UserService.shared,
            storage: StorageService.shared,
            network: NetworkService.shared,
            bodyAnalysis: MockBodyAnalysisService(),
            programGeneration: MockProgramGenerationService(),
            imageCapture: MockImageCaptureService(),
            exercisePreference: MockExercisePreferenceService(),
            customExercise: MockCustomExerciseStore(),
            workoutLog: workoutLog,
            workingWeight: MockWorkingWeightService(),
            cardioLog: MockCardioLogService(),
            calibration: MockCalibrationService(),
            entitlement: EntitlementService.shared,
            rank: MockRankService(),
            skin: MockSkinService(),
            sessionXP: MockSessionXPService(),
            badges: MockBadgeService(),
            attribute: MockAttributeService()
        )
    }

    func assertCompletionRetriesAfterSingleCreateFailure(
        in collection: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let database = TestProgressionDatabase(failingCreateAttempts: [collection: 1])
        let services = makeServices(database: database, workoutLog: MockWorkoutLogService())
        let sessionXP = try XCTUnwrap(services.sessionXP as? MockSessionXPService, file: file, line: line)
        let service = TrainingCompletionService(
            squadMission: NoOpSquadMissionService(),
            friendChallenge: NoOpFriendChallengeService()
        )
        let log = benchPerformanceLog(id: "perf-retry-\(collection)")

        do {
            _ = try await service.complete(log, services: services)
            XCTFail("First completion should fail for \(collection)", file: file, line: line)
        } catch {
            XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 0, file: file, line: line)
        }

        let result = try await service.complete(log, services: services)
        let record: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertFalse(result.wasAlreadyCompleted, file: file, line: line)
        XCTAssertEqual(record.performanceLogId, log.id, file: file, line: line)
        XCTAssertGreaterThan(result.movementAPGains.reduce(0) { $0 + $1.rawAP }, 0, file: file, line: line)
        XCTAssertGreaterThan(result.overallLevelXPGained, 0, file: file, line: line)
        XCTAssertEqual(sessionXP.record(userId: "mock-user-123").totalSessions, 1, file: file, line: line)
    }
}
