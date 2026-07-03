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
            nodeStates: ["pp_pullup": .proven],
            provenAt: ["pp_pullup": now],
            updatedAt: now,
            bookmarkedNodeIds: ["pp_pullup"],
            activeGoalIds: [],
            weeklySchedule: [.push, nil, nil, nil, nil, nil, nil],
            currentWeekPhase: .heavy
        )

        let remote = MockMigrationRemoteStore(authenticated: true)
        // Disable the persisted completion short-circuit so this test continues
        // to exercise the per-collection idempotency guards across two runs.
        let sut = UserDataMigrationCoordinator(local: local, remote: remote, flagStore: NeverCompletedMigrationFlagStore())

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
            nodeStates: ["pp_pullup": .proven, "hs_wall": .locked],
            provenAt: ["pp_pullup": old],
            updatedAt: old,
            bookmarkedNodeIds: ["pp_pullup"],
            activeGoalIds: ["hs_wall"],
            weeklySchedule: [.push, .pull, nil, nil, nil, nil, nil],
            currentWeekPhase: .heavy
        )
        local.progress[supabaseUserId] = UserSkillProgress(
            userId: supabaseUserId,
            nodeStates: ["pp_pullup": .proven],
            provenAt: ["pp_pullup": newer],
            updatedAt: newer,
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
        XCTAssertEqual(migrated.nodeStates["pp_pullup"], .proven)
        XCTAssertEqual(migrated.nodeStates["hs_wall"], .locked)   // legacy attempting → locked
        XCTAssertEqual(migrated.provenAt["pp_pullup"], old)       // earliest first-proof wins
        XCTAssertEqual(migrated.bookmarkedNodeIds, Set(["pp_pullup"]))
        XCTAssertEqual(migrated.activeGoalIds, Set(["pp_pullup", "hs_wall"]))
        XCTAssertEqual(migrated.weeklySchedule[0], .push)
        XCTAssertEqual(migrated.weeklySchedule[1], .legs)
        XCTAssertEqual(migrated.currentWeekPhase, .deload)
    }

    // MARK: - SessionXP streak migration outcome → summary mapping (Bug #3)
    //
    // The read-merge-write itself is atomic inside the store (covered by
    // SessionXPRecord.merging unit tests + the on-sim integration test). Here we
    // only assert the coordinator maps each outcome into the summary correctly.

    private func coordinator(sessionXPOutcome: SessionXPMigrationOutcome) -> UserDataMigrationCoordinator {
        UserDataMigrationCoordinator(
            local: MockMigrationLocalStore(),
            remote: MockMigrationRemoteStore(authenticated: false),
            sessionXPStore: StubMigrationSessionXPStore(outcome: sessionXPOutcome),
            flagStore: NeverCompletedMigrationFlagStore()
        )
    }

    func test_sessionXP_rekeyed_outcome_counts_as_local_write() async {
        let summary = await coordinator(sessionXPOutcome: .rekeyed)
            .migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)
        XCTAssertEqual(summary.sessionXP.scanned, 1)
        XCTAssertEqual(summary.sessionXP.localWrites, 1)
        XCTAssertEqual(summary.sessionXP.failures, 0)
        XCTAssertTrue(summary.allCollectionsSucceeded)
    }

    func test_sessionXP_merged_outcome_counts_existing_target_and_write() async {
        let summary = await coordinator(sessionXPOutcome: .merged)
            .migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)
        XCTAssertEqual(summary.sessionXP.scanned, 1)
        XCTAssertEqual(summary.sessionXP.existingTargets, 1)
        XCTAssertEqual(summary.sessionXP.localWrites, 1)
    }

    func test_sessionXP_noLegacy_outcome_is_noop() async {
        let summary = await coordinator(sessionXPOutcome: .noLegacy)
            .migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)
        XCTAssertEqual(summary.sessionXP.scanned, 0)
        XCTAssertEqual(summary.sessionXP.localWrites, 0)
        XCTAssertEqual(summary.sessionXP.failures, 0)
    }

    func test_sessionXP_failed_outcome_blocks_migration_completion() async {
        // Bug #4: a corrupt/unwritable legacy streak must count as a failure so
        // the migration is retried instead of silently completing + losing it.
        let flagStore = NeverCompletedMigrationFlagStore()
        let sut = UserDataMigrationCoordinator(
            local: MockMigrationLocalStore(),
            remote: MockMigrationRemoteStore(authenticated: false),
            sessionXPStore: StubMigrationSessionXPStore(outcome: .failed),
            flagStore: flagStore
        )

        let summary = await sut.migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)

        XCTAssertEqual(summary.sessionXP.failures, 1)
        XCTAssertFalse(summary.allCollectionsSucceeded)
    }

    // MARK: - Rank progress migration outcome → summary mapping
    //
    // The re-key itself is covered by the integration test below; here we only
    // assert the coordinator maps each outcome into the summary correctly, and
    // that a `.failed` blocks completion the same way SessionXP does.

    private func coordinator(rankProgressOutcome: RankProgressMigrationOutcome) -> UserDataMigrationCoordinator {
        UserDataMigrationCoordinator(
            local: MockMigrationLocalStore(),
            remote: MockMigrationRemoteStore(authenticated: false),
            sessionXPStore: StubMigrationSessionXPStore(outcome: .noLegacy),
            rankProgressStore: StubMigrationRankProgressStore(outcome: rankProgressOutcome),
            flagStore: NeverCompletedMigrationFlagStore()
        )
    }

    func test_rankProgress_rekeyed_outcome_counts_as_local_write() async {
        let summary = await coordinator(rankProgressOutcome: .rekeyed)
            .migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)
        XCTAssertEqual(summary.rankProgress.scanned, 1)
        XCTAssertEqual(summary.rankProgress.localWrites, 1)
        XCTAssertEqual(summary.rankProgress.failures, 0)
        XCTAssertTrue(summary.allCollectionsSucceeded)
    }

    func test_rankProgress_merged_outcome_counts_existing_target_and_write() async {
        let summary = await coordinator(rankProgressOutcome: .merged)
            .migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)
        XCTAssertEqual(summary.rankProgress.scanned, 1)
        XCTAssertEqual(summary.rankProgress.existingTargets, 1)
        XCTAssertEqual(summary.rankProgress.localWrites, 1)
    }

    func test_rankProgress_noLegacy_outcome_is_noop() async {
        let summary = await coordinator(rankProgressOutcome: .noLegacy)
            .migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)
        XCTAssertEqual(summary.rankProgress.scanned, 0)
        XCTAssertEqual(summary.rankProgress.localWrites, 0)
        XCTAssertEqual(summary.rankProgress.failures, 0)
    }

    func test_rankProgress_failed_outcome_blocks_migration_completion() async {
        // A corrupt/unwritable legacy rank must count as a failure so the
        // migration is retried instead of silently completing + resetting the
        // displayed rank to Initiate.
        let summary = await coordinator(rankProgressOutcome: .failed)
            .migrate(legacyUserId: "legacy-user", supabaseUserId: UUID().uuidString)
        XCTAssertEqual(summary.rankProgress.failures, 1)
        XCTAssertFalse(summary.allCollectionsSucceeded)
    }

    // MARK: - Rank progress re-key (integration, real production store)

    @MainActor
    func test_rankProgress_migration_rekeys_trial_rank_and_lift_tiers_to_new_uid() async {
        let suiteName = "RankProgressMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyUserId = "legacy-user"
        let supabaseUserId = UUID().uuidString
        let trialStore = OverallRankTrialStore(defaults: defaults)
        let liftTierStore = LiftTierService(defaults: defaults)

        let legacyAttempt = OverallRankTrialAttempt(
            id: "gate-03",
            userId: legacyUserId,
            definitionId: "gate",
            targetRank: .forged,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 700),
            performanceLogId: "gate-03",
            passed: true,
            movementAPGained: 5,
            overallLevelXPGained: 10
        )
        trialStore.save(
            OverallRankTrialProgress(highestPassedRank: .forged, attempts: [legacyAttempt]),
            userId: legacyUserId
        )
        liftTierStore.save(tier: .veteran, lift: "bench press", userId: legacyUserId)

        let sut = ProductionUserDataMigrationRankProgressStore(
            trialStore: trialStore,
            liftTierStore: liftTierStore,
            backup: NoOpRankProgressBackup()
        )

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .rekeyed)
        XCTAssertEqual(trialStore.load(userId: supabaseUserId).currentRank, .forged)
        XCTAssertEqual(trialStore.load(userId: supabaseUserId).attempts.map(\.id), ["gate-03"])
        XCTAssertEqual(liftTierStore.tier(lift: "bench press", userId: supabaseUserId), .veteran)
        // Legacy entry stays on disk as a backup — the re-key writes the new uid.
        XCTAssertEqual(trialStore.load(userId: legacyUserId).currentRank, .forged)
    }
}

private final class StubMigrationSessionXPStore: UserDataMigrationSessionXPStoring, @unchecked Sendable {
    var outcome: SessionXPMigrationOutcome
    private(set) var calls: [(legacy: String, supabase: String)] = []

    init(outcome: SessionXPMigrationOutcome) {
        self.outcome = outcome
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> SessionXPMigrationOutcome {
        calls.append((legacyUserId, supabaseUserId))
        return outcome
    }
}

private final class StubMigrationRankProgressStore: UserDataMigrationRankProgressStoring, @unchecked Sendable {
    let outcome: RankProgressMigrationOutcome
    private(set) var calls: [(legacy: String, supabase: String)] = []

    init(outcome: RankProgressMigrationOutcome) {
        self.outcome = outcome
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> RankProgressMigrationOutcome {
        calls.append((legacyUserId, supabaseUserId))
        return outcome
    }
}

private struct NoOpRankProgressBackup: RankProgressBackuping {
    func backupTrials(_ progress: OverallRankTrialProgress, userId: String) {}
    func backupLiftTiers(_ tiers: [String: SkillTier], userId: String) {}
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

/// Flag store that always reports "not completed" so the coordinator runs the
/// full per-collection migration on every call. Lets the idempotency tests
/// invoke `migrate` repeatedly without the completion short-circuit kicking in.
private struct NeverCompletedMigrationFlagStore: UserDataMigrationFlagStoring {
    func isCompleted(legacyUserId: String, supabaseUserId: String) -> Bool { false }
    func markCompleted(legacyUserId: String, supabaseUserId: String) {}
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
