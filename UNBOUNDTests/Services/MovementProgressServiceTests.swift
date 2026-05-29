import XCTest
import UIKit
@testable import UNBOUND

@MainActor
final class MovementProgressServiceTests: XCTestCase {
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
        XCTAssertTrue(result.bodyMapRegionRewards.contains { $0.region == .chest && $0.loadAdded > 0 })
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
        XCTAssertGreaterThan(bodyMap.load(for: .chest).lifetimeLoad, 0)
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
        XCTAssertEqual(vitalityReward.xpGained, 8, accuracy: 0.001)
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
    }

    func testTrainingCompletionQuarantinesCompatibleWorkoutLogWhenWriterIsMissing() async throws {
        let database = MockDatabaseService()
        let workoutLog = SaveLogOnlyWorkoutLogService()
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

        XCTAssertEqual(workoutLog.saveCount, 0)
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
        XCTAssertEqual(sessionLogKeys, ["sessionLogs/perf-skill-once:skill-block:session"])
        XCTAssertEqual(second.savedSessionLogIds, first.savedSessionLogIds)
        XCTAssertEqual(second.skillXPGained, 0)
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

    func testBodyMapNoveltyDropsAsSameRegionsSaturate() async throws {
        let database = MockDatabaseService()
        let service = BodyMapProgressService.shared
        let firstGain = benchGain(sourceLogId: "perf-body-1", rawAP: 100)
        let secondGain = benchGain(sourceLogId: "perf-body-2", rawAP: 100)

        let first = await service.ingest(
            movementAPGains: [firstGain],
            userId: "u1",
            sourceLogId: "perf-body-1",
            at: Date(timeIntervalSince1970: 200),
            database: database
        )
        let second = await service.ingest(
            movementAPGains: [secondGain],
            userId: "u1",
            sourceLogId: "perf-body-2",
            at: Date(timeIntervalSince1970: 200),
            database: database
        )
        let duplicate = await service.ingest(
            movementAPGains: [secondGain],
            userId: "u1",
            sourceLogId: "perf-body-2",
            at: Date(timeIntervalSince1970: 250),
            database: database
        )
        let profile: BodyMapProfile = try await database.read(
            collection: "body_map_profiles",
            documentId: "u1"
        )

        XCTAssertEqual(first.noveltyMultiplier, 1.5, accuracy: 0.001)
        XCTAssertLessThan(second.noveltyMultiplier, first.noveltyMultiplier)
        XCTAssertEqual(duplicate.noveltyMultiplier, 1.0, accuracy: 0.001)
        XCTAssertTrue(duplicate.wasDuplicate)
        XCTAssertGreaterThan(profile.load(for: .chest).lifetimeLoad, 0)
        XCTAssertEqual(profile.processedSourceLogIds, ["perf-body-1", "perf-body-2"])
    }

    func testBodyRegionTrainingLedgerSeparatesDirectSecondaryAndSkillPractice() {
        let loads = BodyRegionTrainingLedger.loads(for: [
            Exercise(
                id: "ledger-bench",
                name: "Bench Press",
                muscleGroups: [.chest, .shoulders, .arms],
                sets: 4,
                reps: "6-8",
                restSeconds: 120,
                rpe: 8,
                notes: nil,
                substitution: nil
            ),
            Exercise(
                id: "ledger-pullup",
                name: "Pullup",
                muscleGroups: [.back, .lats, .arms],
                sets: 3,
                reps: "6-10",
                restSeconds: 120,
                rpe: 8,
                notes: nil,
                substitution: nil
            ),
            Exercise(
                id: "ledger-handstand",
                name: "Freestanding Handstand",
                muscleGroups: [.shoulders, .core],
                sets: 5,
                reps: "20s",
                restSeconds: 90,
                rpe: 7,
                notes: nil,
                substitution: nil
            )
        ])
        let byRegion = Dictionary(uniqueKeysWithValues: loads.map { ($0.region, $0) })

        XCTAssertEqual(byRegion[.chest]?.directHardSets, 4)
        XCTAssertEqual(byRegion[.triceps]?.secondaryExposureSets, 4)
        XCTAssertEqual(byRegion[.lats]?.directHardSets, 3)
        XCTAssertEqual(byRegion[.biceps]?.secondaryExposureSets, 3)
        XCTAssertEqual(byRegion[.shoulders]?.secondaryExposureSets, 4)
        XCTAssertEqual(byRegion[.shoulders]?.skillPracticeSets, 5)
        XCTAssertEqual(byRegion[.shoulders]?.jointTendonStressSets, 5)
        XCTAssertEqual(byRegion[.forearms]?.skillPracticeSets, 5)
        XCTAssertEqual(byRegion[.forearms]?.jointTendonStressSets, 5)
    }

    func testBodyRegionTrainingLedgerSeparatesMobilityAndCarryStressFromHardSets() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .routine,
            title: "Mobility + Carry",
            estimatedMinutes: 24,
            blocks: [
                TrainingBlock(
                    kind: .routine,
                    title: "Mobility",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Deep Squat Hold",
                            sets: 2,
                            target: .holdSeconds(45),
                            restSeconds: 20
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .carry,
                    title: "Loaded Carry",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Farmer Carry",
                            sets: 4,
                            target: .distanceMeters(40),
                            restSeconds: 90,
                            muscleGroups: [.back, .arms, .shoulders]
                        )
                    ]
                )
            ]
        )

        let byRegion = Dictionary(uniqueKeysWithValues: BodyRegionTrainingLedger.loads(for: draft).map { ($0.region, $0) })

        XCTAssertEqual(byRegion[.quads]?.mobilityControlSets, 2)
        XCTAssertEqual(byRegion[.glutes]?.mobilityControlSets, 2)
        XCTAssertEqual(byRegion[.forearms]?.jointTendonStressSets, 4)
        XCTAssertEqual(byRegion[.traps]?.jointTendonStressSets, 4)
        XCTAssertEqual(byRegion[.lowerBack]?.jointTendonStressSets, 4)
        XCTAssertEqual(byRegion[.shoulders]?.jointTendonStressSets, 4)
    }

    func testBodyRegionTrainingLedgerTreatsPlanksAsTrunkBracingNotDirectLowBack() {
        let loads = BodyRegionTrainingLedger.loads(for: [
            Exercise(
                id: "ledger-plank",
                name: "Plank",
                muscleGroups: [.core],
                sets: 3,
                reps: "30s",
                restSeconds: 45,
                rpe: 7,
                notes: nil,
                substitution: nil
            )
        ])
        let byRegion = Dictionary(uniqueKeysWithValues: loads.map { ($0.region, $0) })

        XCTAssertEqual(byRegion[.abs]?.directHardSets, 3)
        XCTAssertEqual(byRegion[.obliques]?.directHardSets, 3)
        XCTAssertEqual(byRegion[.lowerBack]?.directHardSets ?? 0, 0)
        XCTAssertEqual(byRegion[.lowerBack]?.secondaryExposureSets, 3)
    }

    func testTrainingCompletionBodyMapUsesRoleWeightedLoadsForProfile() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-body-role-weighted",
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

        _ = try await TrainingCompletionService.shared.complete(log, services: services)
        let bodyMap: BodyMapProfile = try await services.database.read(
            collection: "body_map_profiles",
            documentId: "mock-user-123"
        )

        XCTAssertGreaterThan(bodyMap.load(for: .chest).lifetimeLoad, bodyMap.load(for: .shoulders).lifetimeLoad)
        XCTAssertGreaterThan(bodyMap.load(for: .chest).lifetimeLoad, bodyMap.load(for: .triceps).lifetimeLoad)
        XCTAssertEqual(bodyMap.load(for: .chest).recentDirectHardSets, 1)
        XCTAssertEqual(bodyMap.load(for: .shoulders).recentSecondaryExposureSets, 1)
        XCTAssertEqual(bodyMap.load(for: .triceps).recentSecondaryExposureSets, 1)
    }

    func testBodyMapRoleOnlyTrainingLoadUpdatesProfileWithoutMovementAP() async throws {
        let database = MockDatabaseService()
        var tendonLoad = BodyRegionTrainingLoad(region: .forearms)
        tendonLoad.add(4, as: .jointTendonStress)

        let result = await BodyMapProgressService.shared.ingest(
            movementAPGains: [],
            userId: "role-only-user",
            sourceLogId: "role-only-carry",
            at: Date(timeIntervalSince1970: 200),
            trainingLoads: [tendonLoad],
            database: database
        )
        let profile: BodyMapProfile = try await database.read(
            collection: "body_map_profiles",
            documentId: "role-only-user"
        )

        XCTAssertFalse(result.wasDuplicate)
        XCTAssertEqual(result.regionRewards.first?.region, .forearms)
        XCTAssertGreaterThan(result.regionRewards.first?.loadAdded ?? 0, 0)
        XCTAssertEqual(profile.load(for: .forearms).recentJointTendonStressSets, 4)
        XCTAssertGreaterThan(profile.load(for: .forearms).recentLoad, 0)
    }

    func testScanContextBuilderUsesCatalogIdsAndLegacyNamesForVolume() async throws {
        let workoutLog = MockWorkoutLogService()
        let builder = ScanContextBuilder(
            user: ScanContextUserService(),
            workoutLog: workoutLog,
            database: MockDatabaseService()
        )
        let log = WorkoutLog(
            id: "scan-catalog-volume",
            userId: "u1",
            programId: "program-catalog-regression",
            dayNumber: 1,
            plannedWorkoutName: "Push",
            startedAt: Date(),
            completedAt: Date(),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "scan-id-backed",
                    exerciseName: "Saved Press Machine Label",
                    movementId: "exercise.plate-loaded-chest-press",
                    rankStandardMovementId: "exercise.plate-loaded-chest-press",
                    plannedSets: 1,
                    plannedReps: "8",
                    sets: [SetLog(id: "scan-set-1", setNumber: 1, weightKg: 60, reps: 8, rpe: 8, isWarmup: false)],
                    skipped: false,
                    notes: nil
                ),
                ExerciseLogEntry(
                    id: "scan-legacy-name",
                    exerciseName: "bench_press",
                    plannedSets: 1,
                    plannedReps: "8",
                    sets: [SetLog(id: "scan-set-2", setNumber: 1, weightKg: 80, reps: 8, rpe: 8, isWarmup: false)],
                    skipped: false,
                    notes: nil
                )
            ]
        )
        try await workoutLog.saveLog(log)

        let maybeContext = await builder.build(userId: "u1", currentImage: onePixelImage())
        let context = try XCTUnwrap(maybeContext)

        XCTAssertEqual(context.sessionCount, 1)
        XCTAssertEqual(context.setsByMuscleGroup[MuscleHeatGroup.chest.rawValue], 2)
    }

    private func benchGain(sourceLogId: String, rawAP: Double) -> MovementAPGain {
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

    private func workoutLog(
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

    private func onePixelImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private func makeServices(
        database: MockDatabaseService,
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
            programPhase: MockProgramPhaseEngine(),
            attribute: MockAttributeService()
        )
    }
}

private final class ScanContextUserService: UserServiceProtocol, @unchecked Sendable {
    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
        profile(userId: userId)
    }

    func fetchProfile(userId: String) async throws -> UserProfile {
        profile(userId: userId)
    }

    func updateProfile(userId: String, fields: [String: Any]) async throws {}

    func deleteUserData(userId: String) async throws {}

    private func profile(userId: String) -> UserProfile {
        UserProfile(
            id: userId,
            email: nil,
            displayName: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0
        )
    }
}

private final class SaveLogOnlyWorkoutLogService: WorkoutLogServiceProtocol, @unchecked Sendable {
    var saveCount = 0
    var logs: [WorkoutLog] = []

    func saveLog(_ log: WorkoutLog) async throws {
        saveCount += 1
        logs.append(log)
    }

    func updateLog(_ log: WorkoutLog) async throws {
        logs.removeAll { $0.id == log.id }
        logs.append(log)
    }

    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        if let programId { return logs.filter { $0.programId == programId } }
        return logs
    }

    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        Array(logs.prefix(limit))
    }

    func deleteLog(id: String) async throws {
        logs.removeAll { $0.id == id }
    }
}
