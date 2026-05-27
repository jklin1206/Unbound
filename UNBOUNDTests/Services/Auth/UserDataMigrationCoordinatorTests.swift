import XCTest
@testable import UNBOUND

final class UserDataMigrationCoordinatorTests: XCTestCase {
    func test_migration_rekeys_local_data_without_creating_duplicate_documents() async {
        let legacyUserId = "legacy-user"
        let supabaseUserId = UUID().uuidString
        let programId = UUID().uuidString
        let logId = UUID().uuidString
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let local = MockMigrationLocalStore()
        local.logs[logId] = WorkoutLog(
            id: logId,
            userId: legacyUserId,
            programId: programId,
            dayNumber: 1,
            plannedWorkoutName: "Push",
            startedAt: now,
            completedAt: now,
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: 42
        )
        local.weights["bench_press"] = WorkingWeight(
            id: "bench_press",
            userId: legacyUserId,
            exerciseName: "bench_press",
            weightKg: 80,
            lastReps: 5,
            lastRPE: 8,
            updatedAt: now,
            sourceLogId: logId,
            consecutiveSessionsAtTarget: 1
        )
        local.progress[legacyUserId] = UserSkillProgress(
            userId: legacyUserId,
            nodeStates: ["pp_pullup": .achieved],
            achievedAt: ["pp_pullup": now],
            masteredAt: [:],
            updatedAt: now,
            skillProgress: ["pp_pullup": SkillProgress(currentLevel: 2, xpInLevel: 10, xpToNextLevel: 125)],
            lastTrainedAt: [:],
            bookmarkedNodeIds: ["pp_pullup"],
            activeGoalIds: [],
            weeklySchedule: [.push, nil, nil, nil, nil, nil, nil],
            currentWeekPhase: .heavy
        )

        let remote = MockMigrationRemoteStore(authenticated: true)
        let sut = UserDataMigrationCoordinator(local: local, remote: remote)

        let first = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)
        let second = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(first.workoutLogs.localWrites, 1)
        XCTAssertEqual(first.workoutLogs.queuedForSync, 1)
        XCTAssertEqual(first.workingWeights.localWrites, 1)
        XCTAssertEqual(first.skillProgress.localWrites, 1)
        XCTAssertEqual(second.workoutLogs.scanned, 0)
        XCTAssertEqual(second.workingWeights.scanned, 0)
        XCTAssertEqual(second.skillProgress.localWrites, 0)

        XCTAssertEqual(local.logs.count, 1)
        XCTAssertEqual(local.weights.count, 1)
        XCTAssertEqual(local.progress.count, 2)
        XCTAssertEqual(local.logs[logId]?.userId, supabaseUserId)
        XCTAssertEqual(local.weights["bench_press"]?.userId, supabaseUserId)
        XCTAssertEqual(local.progress[supabaseUserId]?.userId, supabaseUserId)
        XCTAssertEqual(local.progress[supabaseUserId]?.currentWeekPhase, .heavy)
        XCTAssertEqual(remote.workingWeightUpserts.map(\.userId), [supabaseUserId])
        XCTAssertEqual(remote.skillProgressUpserts.map(\.userId), [supabaseUserId, supabaseUserId])
    }

    func test_migration_defers_direct_remote_writes_when_supabase_is_not_authenticated() async {
        let legacyUserId = "legacy-user"
        let supabaseUserId = UUID().uuidString
        let now = Date(timeIntervalSince1970: 1_800_000_100)

        let local = MockMigrationLocalStore()
        local.weights["squat"] = WorkingWeight(
            id: "squat",
            userId: legacyUserId,
            exerciseName: "squat",
            weightKg: 120,
            lastReps: 3,
            lastRPE: nil,
            updatedAt: now,
            sourceLogId: "local-log",
            consecutiveSessionsAtTarget: 0
        )
        local.progress[legacyUserId] = .empty(userId: legacyUserId)

        let remote = MockMigrationRemoteStore(authenticated: false)
        let sut = UserDataMigrationCoordinator(local: local, remote: remote)

        let summary = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(summary.workingWeights.remoteDeferred, 1)
        XCTAssertEqual(summary.skillProgress.remoteDeferred, 1)
        XCTAssertTrue(remote.workingWeightUpserts.isEmpty)
        XCTAssertTrue(remote.skillProgressUpserts.isEmpty)
        XCTAssertEqual(local.weights["squat"]?.userId, supabaseUserId)
        XCTAssertEqual(local.progress[supabaseUserId]?.userId, supabaseUserId)
    }

    func test_skill_progress_merge_preserves_existing_target_and_adds_legacy_only_fields() async throws {
        let legacyUserId = "legacy-user"
        let supabaseUserId = UUID().uuidString
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_000)

        let local = MockMigrationLocalStore()
        local.progress[legacyUserId] = UserSkillProgress(
            userId: legacyUserId,
            nodeStates: ["pp_pullup": .achieved, "hs_wall": .attempting],
            achievedAt: ["pp_pullup": old],
            masteredAt: [:],
            updatedAt: old,
            skillProgress: ["pp_pullup": SkillProgress(currentLevel: 2, xpInLevel: 50, xpToNextLevel: 125)],
            lastTrainedAt: ["pp_pullup": old],
            bookmarkedNodeIds: ["pp_pullup"],
            activeGoalIds: ["hs_wall"],
            weeklySchedule: [.push, .pull, nil, nil, nil, nil, nil],
            currentWeekPhase: .heavy
        )
        local.progress[supabaseUserId] = UserSkillProgress(
            userId: supabaseUserId,
            nodeStates: ["pp_pullup": .mastered],
            achievedAt: ["pp_pullup": newer],
            masteredAt: ["pp_pullup": newer],
            updatedAt: newer,
            skillProgress: [:],
            lastTrainedAt: [:],
            bookmarkedNodeIds: [],
            activeGoalIds: ["pp_pullup"],
            weeklySchedule: [nil, .legs, nil, nil, nil, nil, nil],
            currentWeekPhase: .deload
        )

        let sut = UserDataMigrationCoordinator(
            local: local,
            remote: MockMigrationRemoteStore(authenticated: false)
        )

        _ = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        let migrated = try XCTUnwrap(local.progress[supabaseUserId])
        XCTAssertEqual(migrated.nodeStates["pp_pullup"], .mastered)
        XCTAssertEqual(migrated.nodeStates["hs_wall"], .attempting)
        XCTAssertEqual(migrated.achievedAt["pp_pullup"], old)
        XCTAssertEqual(migrated.masteredAt["pp_pullup"], newer)
        XCTAssertEqual(migrated.bookmarkedNodeIds, Set(["pp_pullup"]))
        XCTAssertEqual(migrated.activeGoalIds, Set(["pp_pullup", "hs_wall"]))
        XCTAssertEqual(migrated.weeklySchedule[0], .push)
        XCTAssertEqual(migrated.weeklySchedule[1], .legs)
        XCTAssertEqual(migrated.currentWeekPhase, .deload)
    }
}

private final class MockMigrationLocalStore: UserDataMigrationLocalStoring, @unchecked Sendable {
    var logs: [String: WorkoutLog] = [:]
    var weights: [String: WorkingWeight] = [:]
    var progress: [String: UserSkillProgress] = [:]
    var workoutSyncFlags: [Bool] = []

    func workoutLogs(userId: String) async throws -> [WorkoutLog] {
        logs.values.filter { $0.userId == userId }
    }

    func workoutLog(id: String) async throws -> WorkoutLog? {
        logs[id]
    }

    func writeWorkoutLog(_ log: WorkoutLog, enqueueForSync: Bool) async throws {
        logs[log.id] = log
        workoutSyncFlags.append(enqueueForSync)
    }

    func workingWeights(userId: String) async throws -> [WorkingWeight] {
        weights.values.filter { $0.userId == userId }
    }

    func workingWeight(id: String) async throws -> WorkingWeight? {
        weights[id]
    }

    func writeWorkingWeight(_ weight: WorkingWeight) async throws {
        weights[weight.id] = weight
    }

    func skillProgress(userId: String) async throws -> UserSkillProgress? {
        progress[userId]
    }

    func writeSkillProgress(_ value: UserSkillProgress) async throws {
        progress[value.userId] = value
    }
}

private final class MockMigrationRemoteStore: UserDataMigrationRemoteWriting, @unchecked Sendable {
    let authenticated: Bool
    var workingWeightUpserts: [WorkingWeight] = []
    var skillProgressUpserts: [UserSkillProgress] = []

    init(authenticated: Bool) {
        self.authenticated = authenticated
    }

    func canWrite(as userId: String) async -> Bool {
        authenticated
    }

    func upsertWorkingWeight(_ weight: WorkingWeight) async throws {
        workingWeightUpserts.append(weight)
    }

    func upsertSkillProgress(_ progress: UserSkillProgress) async throws {
        skillProgressUpserts.append(progress)
    }
}
