import Foundation

struct ProductionUserDataMigrationLocalStore: UserDataMigrationLocalStoring {
    private let local: any DatabaseServiceProtocol
    private let synced: any DatabaseServiceProtocol

    init(
        local: any DatabaseServiceProtocol = DatabaseService.shared,
        synced: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) {
        self.local = local
        self.synced = synced
    }

    func workoutLogs(userId: String) async throws -> [WorkoutLog] {
        try await local.query(
            collection: "workoutLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "startedAt",
            descending: false,
            limit: nil
        )
    }

    func workoutLog(id: String) async throws -> WorkoutLog? {
        try? await local.read(collection: "workoutLogs", documentId: id)
    }

    func writeWorkoutLog(_ log: WorkoutLog, enqueueForSync: Bool) async throws {
        if enqueueForSync {
            try await synced.create(log, collection: "workoutLogs", documentId: log.id)
        } else {
            try await local.create(log, collection: "workoutLogs", documentId: log.id)
        }
    }

    func workingWeights(userId: String) async throws -> [WorkingWeight] {
        try await local.query(
            collection: "workingWeights",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: false,
            limit: nil
        )
    }

    func workingWeight(id: String) async throws -> WorkingWeight? {
        try? await local.read(collection: "workingWeights", documentId: id)
    }

    func writeWorkingWeight(_ weight: WorkingWeight) async throws {
        try await synced.create(weight, collection: "workingWeights", documentId: weight.id)
    }

    func skillProgress(userId: String) async throws -> UserSkillProgress? {
        try? await local.read(collection: "skillProgress", documentId: userId)
    }

    func writeSkillProgress(_ progress: UserSkillProgress) async throws {
        try await synced.create(progress, collection: "skillProgress", documentId: progress.userId)
    }
}

/// Re-keys local scan checkpoints via the filesystem-backed
/// `ScanCheckpointStore`. Re-key is an in-place overwrite: the checkpoint id is
/// stable, only the embedded `userId` changes, so no duplicate file is created.
struct ProductionUserDataMigrationScanStore: UserDataMigrationScanStoring, @unchecked Sendable {
    private let store: ScanCheckpointStore

    init(store: ScanCheckpointStore = .shared) {
        self.store = store
    }

    func scanCheckpoints(userId: String) async throws -> [ScanCheckpoint] {
        try store.history(userId: userId)
    }

    func writeScanCheckpoint(_ checkpoint: ScanCheckpoint) async throws {
        try store.save(checkpoint)
    }
}

/// Bridges the SessionXP sign-in re-key to `SessionXPService`, the @MainActor
/// owner of the streak record. Delegating (instead of poking UserDefaults
/// directly) makes the read-merge-write atomic with respect to a session being
/// recorded on the same key, and guarantees the migrated streak lands in the
/// exact slot the service reads from.
struct ProductionUserDataMigrationSessionXPStore: UserDataMigrationSessionXPStoring, @unchecked Sendable {
    func migrate(legacyUserId: String, supabaseUserId: String) async -> SessionXPMigrationOutcome {
        await SessionXPService.shared.migrateRecord(from: legacyUserId, to: supabaseUserId)
    }
}

/// Re-keys the trial-confirmed rank (`OverallRankTrialStore`) + per-lift tiers
/// (`LiftTierService`) from the anonymous UID to the authenticated UID, then
/// mirrors the merged result onto the synced `users` doc via
/// `RankProgressCloudBackup`. The merge NEVER regresses (higher rank wins, per-
/// lift max tier, union of passed attempts) so a target that already has rank
/// data on this device is only ever raised. UserDefaults writes are infallible,
/// so `.failed` is reserved for API symmetry with SessionXP and never emitted.
struct ProductionUserDataMigrationRankProgressStore: UserDataMigrationRankProgressStoring, @unchecked Sendable {
    private let trialStore: OverallRankTrialStore
    private let liftTierStore: LiftTierService?
    private let backup: any RankProgressBackuping

    init(
        trialStore: OverallRankTrialStore = .shared,
        liftTierStore: LiftTierService? = nil,
        backup: any RankProgressBackuping = RankProgressCloudBackup.shared
    ) {
        self.trialStore = trialStore
        self.liftTierStore = liftTierStore
        self.backup = backup
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> RankProgressMigrationOutcome {
        let legacyProgress = trialStore.load(userId: legacyUserId)
        let targetProgress = trialStore.load(userId: supabaseUserId)

        // Lift tiers live behind the @MainActor LiftTierService — read both users'
        // tracked-lift tiers in one hop.
        let injectedLiftStore = liftTierStore
        let (legacyTiers, targetTiers) = await MainActor.run { () -> ([String: SkillTier], [String: SkillTier]) in
            let store = injectedLiftStore ?? LiftTierService.shared
            var legacy: [String: SkillTier] = [:]
            var target: [String: SkillTier] = [:]
            for key in LiftTierService.trackedLiftKeys {
                legacy[key] = store.tier(lift: key, userId: legacyUserId)
                target[key] = store.tier(lift: key, userId: supabaseUserId)
            }
            return (legacy, target)
        }

        let legacyHasData = hasData(progress: legacyProgress, tiers: legacyTiers)
        guard legacyHasData else { return .noLegacy }
        let targetHadData = hasData(progress: targetProgress, tiers: targetTiers)

        let mergedProgress = targetProgress.mergedNeverRegressing(with: legacyProgress)
        let mergedTiers: [String: SkillTier] = LiftTierService.trackedLiftKeys.reduce(into: [:]) { tiers, key in
            tiers[key] = max(legacyTiers[key] ?? .initiate, targetTiers[key] ?? .initiate)
        }

        let progressChanged = mergedProgress != targetProgress
        if progressChanged {
            trialStore.save(mergedProgress, userId: supabaseUserId)
        }

        let raisedTiers = await MainActor.run { () -> Bool in
            let store = injectedLiftStore ?? LiftTierService.shared
            var raised = false
            for key in LiftTierService.trackedLiftKeys {
                let merged = mergedTiers[key] ?? .initiate
                if merged > (targetTiers[key] ?? .initiate) {
                    store.save(tier: merged, lift: key, userId: supabaseUserId)
                    raised = true
                }
            }
            return raised
        }

        // Mirror the merged result onto the synced `users` doc (outboxed, retried).
        backup.backupTrials(mergedProgress, userId: supabaseUserId)
        backup.backupLiftTiers(mergedTiers, userId: supabaseUserId)

        if !targetHadData {
            return .rekeyed
        }
        return (progressChanged || raisedTiers) ? .merged : .unchanged
    }

    private func hasData(progress: OverallRankTrialProgress, tiers: [String: SkillTier]) -> Bool {
        !progress.attempts.isEmpty
            || progress.highestPassedRank != .initiate
            || tiers.values.contains { $0 > .initiate }
    }
}

/// Persists the per-(legacy → supabase) migration-completed flag in
/// UserDefaults. Local-only and survives relaunches, which is exactly what the
/// resume guard needs.
struct UserDefaultsUserDataMigrationFlagStore: UserDataMigrationFlagStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(legacyUserId: String, supabaseUserId: String) -> String {
        "migrationCompleted.\(legacyUserId)->\(supabaseUserId)"
    }

    func isCompleted(legacyUserId: String, supabaseUserId: String) -> Bool {
        defaults.bool(forKey: key(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId))
    }

    func markCompleted(legacyUserId: String, supabaseUserId: String) {
        defaults.set(true, forKey: key(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId))
    }
}

struct SupabaseUserDataMigrationRemoteStore: UserDataMigrationRemoteWriting {
    private let supabase: SupabaseDatabase

    init(supabase: SupabaseDatabase = .shared) {
        self.supabase = supabase
    }

    func canWrite(as userId: String) async -> Bool {
        guard let current = await UnboundSupabase.currentUserId else { return false }
        return current.caseInsensitiveCompare(userId) == .orderedSame
    }

    func upsertWorkingWeight(_ weight: WorkingWeight) async throws {
        let row = WorkingWeightMigrationRow(weight)
        let _: WorkingWeightMigrationRow = try await supabase.upsert(
            row,
            into: "working_weights",
            onConflict: "user_id,exercise_name"
        )
    }

    func upsertSkillProgress(_ progress: UserSkillProgress) async throws {
        let _: UserSkillProgress = try await supabase.upsert(
            progress,
            into: "skill_progress",
            onConflict: "user_id"
        )
    }
}

private struct WorkingWeightMigrationRow: Codable, Sendable {
    let userId: String
    let exerciseName: String
    let weightKg: Double
    let lastReps: Int
    let lastRPE: Int?
    let updatedAt: Date
    let sourceLogId: String
    let consecutiveSessionsAtTarget: Int

    init(_ weight: WorkingWeight) {
        self.userId = weight.userId
        self.exerciseName = weight.exerciseName
        self.weightKg = weight.weightKg
        self.lastReps = weight.lastReps
        self.lastRPE = weight.lastRPE
        self.updatedAt = weight.updatedAt
        self.sourceLogId = weight.sourceLogId
        self.consecutiveSessionsAtTarget = weight.consecutiveSessionsAtTarget
    }
}
