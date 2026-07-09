import Foundation

// Production stores for the two collection-doc progress domains the sign-in
// migration carries: the overall-level XP ledger and the local-only
// progression docs (movement tiers / working loads / family unlocks). Both
// follow the rank store's shape: read both sides, merge never-regressing,
// write under the Supabase id, leave the legacy docs in place as harmless
// orphans, then mirror the merged result to the users doc so the cloud backup
// is immediately fresh under the new id.

// MARK: - Overall level (`overall_level_progress`)

/// Re-keys the overall-level XP ledger (documentId = userId). The merge never
/// regresses: `totalXP` is the max of both sides — the same monotone rule
/// `OverallLevelCloudBackup.seedLocalStores` applies on restore — and the
/// processed-source receipts union so a log counted under either id can never
/// re-ingest after the merge.
struct ProductionUserDataMigrationLevelProgressStore: UserDataMigrationLevelProgressStoring {
    private let database: any DatabaseServiceProtocol
    private let backup: any OverallLevelBackuping
    private let logger: LoggingService

    init(
        database: any DatabaseServiceProtocol = SyncedDatabase.shared,
        backup: any OverallLevelBackuping = OverallLevelCloudBackup.shared,
        logger: LoggingService = .shared
    ) {
        self.database = database
        self.backup = backup
        self.logger = logger
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> LevelProgressMigrationOutcome {
        let legacy: OverallLevelProgress? = try? await database.read(
            collection: "overall_level_progress",
            documentId: legacyUserId
        )
        guard let legacy, legacy.totalXP > 0 || !legacy.processedSourceLogIds.isEmpty else {
            return .noLegacy
        }

        let target: OverallLevelProgress? = try? await database.read(
            collection: "overall_level_progress",
            documentId: supabaseUserId
        )
        let merged = Self.merged(legacy: legacy, target: target, targetUserId: supabaseUserId)

        // A merge that equals the existing target (a resumed run re-carrying
        // the same ledger) writes nothing — zero-write idempotency.
        if merged != target {
            do {
                try await database.create(
                    merged,
                    collection: "overall_level_progress",
                    documentId: supabaseUserId
                )
            } catch {
                logger.log(
                    "Overall level migration write failed: \(error)",
                    level: .error,
                    context: ["to": supabaseUserId]
                )
                return .failed
            }
        }

        // Mirror onto the synced users doc (outboxed, retried) so the cloud
        // copy is fresh under the new id, matching the rank store's backup.
        backup.backup(merged, userId: supabaseUserId)

        guard let target else { return .rekeyed }
        return merged == target ? .unchanged : .merged
    }

    /// Max-XP base plus receipts union. Internal (not private) so the tests
    /// can pin the merge rule directly.
    static func merged(
        legacy: OverallLevelProgress,
        target: OverallLevelProgress?,
        targetUserId: String
    ) -> OverallLevelProgress {
        guard let target else {
            return OverallLevelProgress(
                userId: targetUserId,
                totalXP: legacy.totalXP,
                lastGainedXP: legacy.lastGainedXP,
                processedSourceLogIds: legacy.processedSourceLogIds,
                processedSourceRewards: legacy.processedSourceRewards,
                updatedAt: legacy.updatedAt
            )
        }
        // XP is NOT summed: the two ledgers describe the same person, so the
        // higher side already contains the demonstrated total (seed rule).
        let base = target.totalXP >= legacy.totalXP ? target : legacy
        let seen = Set(target.processedSourceLogIds)
        return OverallLevelProgress(
            userId: targetUserId,
            totalXP: base.totalXP,
            lastGainedXP: base.lastGainedXP,
            processedSourceLogIds: target.processedSourceLogIds
                + legacy.processedSourceLogIds.filter { !seen.contains($0) },
            processedSourceRewards: legacy.processedSourceRewards
                .merging(target.processedSourceRewards) { _, target in target },
            updatedAt: max(legacy.updatedAt, target.updatedAt)
        )
    }
}

// MARK: - Progress docs (`movement_progress` / `progression_states` / `progression_families`)

/// Seam over `ProgressSnapshotCloudBackup` so the migration can mirror the
/// merged docs to the users doc through a spy-able protocol, mirroring
/// `RankProgressBackuping` / `OverallLevelBackuping`.
protocol ProgressSnapshotBackuping: Sendable {
    func backup(userId: String) async
}

extension ProgressSnapshotCloudBackup: ProgressSnapshotBackuping {}

/// Re-keys the three local-only progression collections, whose documents are
/// keyed "{userId}:{key}" with a `userId` field — both are rebuilt under the
/// Supabase id. Merge rules per collection (all monotone, never regressing):
///   - movements: `MovementProgressState.merge(from:)` — the model's own
///     consolidation merge (ledger sum, best-of metrics, receipts union).
///   - loads: the higher working weight stands, whole-doc adopt otherwise —
///     the same rule `ProgressSnapshotCloudBackup.seedLocalStores` applies.
///   - families: the higher unlocked tier stands, whole-doc adopt otherwise.
struct ProductionUserDataMigrationProgressDocsStore: UserDataMigrationProgressDocsStoring {
    private let database: any DatabaseServiceProtocol
    private let backup: any ProgressSnapshotBackuping
    private let logger: LoggingService

    init(
        database: any DatabaseServiceProtocol = SyncedDatabase.shared,
        backup: any ProgressSnapshotBackuping = ProgressSnapshotCloudBackup.shared,
        logger: LoggingService = .shared
    ) {
        self.database = database
        self.backup = backup
        self.logger = logger
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> ProgressDocsMigrationOutcome {
        let legacyMovements: [MovementProgressState]
        let legacyLoads: [ProgressionState]
        let legacyFamilies: [ProgressionFamilyState]
        do {
            legacyMovements = try await query("movement_progress", userId: legacyUserId)
            legacyLoads = try await query("progression_states", userId: legacyUserId)
            legacyFamilies = try await query("progression_families", userId: legacyUserId)
        } catch {
            logger.log("Progress docs migration failed reading legacy docs: \(error)", level: .error)
            return .failed
        }
        guard !(legacyMovements.isEmpty && legacyLoads.isEmpty && legacyFamilies.isEmpty) else {
            return .noLegacy
        }

        // Captured BEFORE any write so rekeyed-vs-merged reflects what the
        // Supabase id actually held when the migration started.
        let targetHadData = await targetHasDocs(userId: supabaseUserId)

        var wroteAny = false
        var failedAny = false
        // One bad doc must not strand the rest: writes are per-doc idempotent
        // (subset receipts / monotone compares skip already-carried docs), so
        // the domain reports `.failed` and the next launch re-runs safely.
        for legacy in legacyMovements {
            do {
                if try await migrateMovement(legacy, supabaseUserId: supabaseUserId) { wroteAny = true }
            } catch {
                failedAny = logDocFailure(error, collection: "movement_progress", id: legacy.id)
            }
        }
        for legacy in legacyLoads {
            do {
                if try await migrateLoad(legacy, supabaseUserId: supabaseUserId) { wroteAny = true }
            } catch {
                failedAny = logDocFailure(error, collection: "progression_states", id: legacy.id)
            }
        }
        for legacy in legacyFamilies {
            do {
                if try await migrateFamily(legacy, supabaseUserId: supabaseUserId) { wroteAny = true }
            } catch {
                failedAny = logDocFailure(error, collection: "progression_families", id: legacy.id)
            }
        }

        // Mirror to the users doc whenever legacy had data (even a no-op
        // merge), matching the rank store — the mirror is best-effort and
        // logs its own failures.
        await backup.backup(userId: supabaseUserId)

        if failedAny { return .failed }
        if !targetHadData { return wroteAny ? .rekeyed : .unchanged }
        return wroteAny ? .merged : .unchanged
    }

    // MARK: - Per-collection carries (true = wrote)

    private func migrateMovement(
        _ legacy: MovementProgressState,
        supabaseUserId: String
    ) async throws -> Bool {
        let rekeyed = legacy.rekeyed(to: supabaseUserId)
        guard let existing: MovementProgressState = try? await database.read(
            collection: "movement_progress",
            documentId: rekeyed.id
        ) else {
            try await database.create(rekeyed, collection: "movement_progress", documentId: rekeyed.id)
            return true
        }
        // Resume guard: `merge(from:)` SUMS the AP ledger, so a resumed run
        // must not re-merge a legacy row it already carried. Receipts are
        // append-only, so legacy-receipts-subset == already merged.
        if !legacy.processedSourceLogIds.isEmpty,
           Set(legacy.processedSourceLogIds).isSubset(of: Set(existing.processedSourceLogIds)) {
            return false
        }
        var merged = existing
        merged.merge(from: legacy)
        // `merge(from:)` always bumps `updatedAt`; compare modulo that field
        // so a no-op merge (receipt-less legacy row adding nothing) skips.
        var comparable = merged
        comparable.updatedAt = existing.updatedAt
        guard comparable != existing else { return false }
        try await database.create(merged, collection: "movement_progress", documentId: merged.id)
        return true
    }

    private func migrateLoad(
        _ legacy: ProgressionState,
        supabaseUserId: String
    ) async throws -> Bool {
        let rekeyed = legacy.rekeyed(to: supabaseUserId)
        if let existing: ProgressionState = try? await database.read(
            collection: "progression_states",
            documentId: rekeyed.id
        ), existing.currentWorkingWeightKg >= legacy.currentWorkingWeightKg {
            return false
        }
        try await database.create(rekeyed, collection: "progression_states", documentId: rekeyed.id)
        return true
    }

    private func migrateFamily(
        _ legacy: ProgressionFamilyState,
        supabaseUserId: String
    ) async throws -> Bool {
        let rekeyed = legacy.rekeyed(to: supabaseUserId)
        if let existing: ProgressionFamilyState = try? await database.read(
            collection: "progression_families",
            documentId: rekeyed.id
        ), existing.unlockedTier >= legacy.unlockedTier {
            return false
        }
        try await database.create(rekeyed, collection: "progression_families", documentId: rekeyed.id)
        return true
    }

    // MARK: - Helpers

    private func query<T: Codable>(_ collection: String, userId: String) async throws -> [T] {
        try await database.query(
            collection: collection,
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: false,
            limit: nil
        )
    }

    private func targetHasDocs(userId: String) async -> Bool {
        let movements: [MovementProgressState] = (try? await query("movement_progress", userId: userId)) ?? []
        if !movements.isEmpty { return true }
        let loads: [ProgressionState] = (try? await query("progression_states", userId: userId)) ?? []
        if !loads.isEmpty { return true }
        let families: [ProgressionFamilyState] = (try? await query("progression_families", userId: userId)) ?? []
        return !families.isEmpty
    }

    /// Always returns true so the catch sites read as one line.
    private func logDocFailure(_ error: Error, collection: String, id: String) -> Bool {
        logger.log(
            "Progress docs migration failed for \(collection)/\(id): \(error)",
            level: .error
        )
        return true
    }
}

// MARK: - Re-key copies

private extension MovementProgressState {
    func rekeyed(to userId: String) -> MovementProgressState {
        MovementProgressState(
            userId: userId,
            rankStandardMovementId: rankStandardMovementId,
            displayName: displayName,
            rankTemplate: rankTemplate,
            totalAP: totalAP,
            provenTier: provenTier,
            bestEstimatedOneRepMaxKg: bestEstimatedOneRepMaxKg,
            bestLoadKg: bestLoadKg,
            bestReps: bestReps,
            bestHoldSeconds: bestHoldSeconds,
            bestDurationSeconds: bestDurationSeconds,
            bestDistanceMeters: bestDistanceMeters,
            bestCalories: bestCalories,
            lastGainedAP: lastGainedAP,
            lastLoggedAt: lastLoggedAt,
            contributingMovementIds: contributingMovementIds,
            processedSourceLogIds: processedSourceLogIds,
            updatedAt: updatedAt
        )
    }
}

private extension ProgressionState {
    func rekeyed(to userId: String) -> ProgressionState {
        var state = ProgressionState(
            userId: userId,
            exerciseKey: exerciseKey,
            displayName: displayName,
            currentWorkingWeightKg: currentWorkingWeightKg,
            targetRepMin: targetRepMin,
            targetRepMax: targetRepMax,
            targetRPE: targetRPE,
            consecutiveSessionsAtTarget: consecutiveSessionsAtTarget,
            lastBumpDate: lastBumpDate,
            blockType: blockType,
            weekInBlock: weekInBlock,
            updatedAt: updatedAt
        )
        state.lastSessionReps = lastSessionReps
        state.lastSessionRPE = lastSessionRPE
        state.lastSessionHitTarget = lastSessionHitTarget
        state.lastSessionWasGrindy = lastSessionWasGrindy
        state.underTargetSessionCount = underTargetSessionCount
        state.prescriptionBias = prescriptionBias
        return state
    }
}

private extension ProgressionFamilyState {
    func rekeyed(to userId: String) -> ProgressionFamilyState {
        ProgressionFamilyState(
            userId: userId,
            family: family,
            unlockedTier: unlockedTier,
            currentTier: currentTier,
            updatedAt: updatedAt
        )
    }
}
