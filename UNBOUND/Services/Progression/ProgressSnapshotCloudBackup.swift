import Foundation

/// Cloud mirror for the local-only progression collections.
///
/// `movement_progress`, `progression_states`, and `progression_families` are
/// deliberately excluded from generic sync (`SyncCollectionMap.localOnlyCollections`),
/// so a reinstall silently resets the rank library's lift tiers, the
/// `movementsAtRank` gate-key pool, and every generated workout's working
/// loads. This service patches a compact, versioned snapshot of just the
/// load-bearing fields onto the synced `users` doc through the SAME
/// offline-safe choke point every other users-doc write takes
/// (`SyncedDatabase` -> outbox -> `sync_merge_row` field-level merge). Local
/// state stays the source of truth; this is a best-effort mirror whose
/// failures are logged, never silenced.
///
/// The exactly-once ingest machinery (`movement_progress_prior_states`,
/// `movement_progress_source_receipts`, `movement_ap_gains`) is NOT backed up:
/// it exists to dedupe re-ingest of the same log on one install, which a fresh
/// install cannot replay anyway.

// MARK: - Snapshot payload

/// The users-doc `progressSnapshot` field. Versioned so a future shape change
/// can migrate old payloads instead of dropping them. Entry arrays are sorted
/// by key so equality (the redundant-patch skip) is order-independent.
struct ProgressSnapshot: Codable, Equatable, Sendable {
    var v: Int
    var movements: [MovementSnapshotEntry]
    var loads: [LoadSnapshotEntry]
    var families: [FamilySnapshotEntry]

    init(
        movements: [MovementProgressState],
        loads: [ProgressionState],
        families: [ProgressionFamilyState]
    ) {
        self.v = 1
        self.movements = movements.map(MovementSnapshotEntry.init).sorted { $0.key < $1.key }
        self.loads = loads.map(LoadSnapshotEntry.init).sorted { $0.key < $1.key }
        self.families = families.map(FamilySnapshotEntry.init).sorted { $0.family < $1.family }
    }

    var isEmpty: Bool { movements.isEmpty && loads.isEmpty && families.isEmpty }
}

/// One `movement_progress` row, reduced to what `MovementProgressTierResolver`
/// needs to reproduce the resolved tier: the proven floor plus ONLY the metric
/// fields the row's `rankTemplate` derives from. Ledger and dedupe fields
/// (`totalAP`, `processedSourceLogIds`, ...) intentionally never travel.
struct MovementSnapshotEntry: Codable, Equatable, Sendable {
    /// `rankStandardMovementId` — the doc id is reconstructed as
    /// "{userId}:{key}" on restore.
    var key: String
    var displayName: String
    var rankTemplate: MovementRankTemplate
    var provenTier: SkillTier
    var oneRepMaxKg: Double?
    var loadKg: Double?
    var reps: Int?
    var holdSeconds: Int?
    var durationSeconds: Int?

    init(state: MovementProgressState) {
        key = state.rankStandardMovementId
        displayName = state.displayName
        rankTemplate = state.rankTemplate
        provenTier = state.provenTier
        // Mirror MovementProgressTierResolver.metricValue: carry only the
        // metrics this template's derived tier reads, so cross-template noise
        // on the row never inflates the payload.
        switch state.rankTemplate {
        case .barbellStrength, .machineStrength, .weightedBodyweight:
            oneRepMaxKg = state.bestEstimatedOneRepMaxKg
            loadKg = state.bestLoadKg
        case .bodyweightReps:
            reps = state.bestReps
        case .holdControl:
            holdSeconds = state.bestHoldSeconds
            durationSeconds = state.bestDurationSeconds
        case .carrySled, .cardioPerformance, .mobilityDuration, .routineCompletion, .unranked:
            break
        }
    }

    func restoredState(userId: String, at date: Date) -> MovementProgressState {
        MovementProgressState(
            userId: userId,
            rankStandardMovementId: key,
            displayName: displayName,
            rankTemplate: rankTemplate,
            provenTier: provenTier,
            bestEstimatedOneRepMaxKg: oneRepMaxKg,
            bestLoadKg: loadKg,
            bestReps: reps,
            bestHoldSeconds: holdSeconds,
            bestDurationSeconds: durationSeconds,
            updatedAt: date
        )
    }
}

/// One `progression_states` row, reduced to what generation reads
/// (`DeterministicProgramGenerator+Progression.suggestedWeightKg`,
/// `TrainingPrescriptionResolver`): working weight, rep rails, block position,
/// and the prescription bias when one is set.
struct LoadSnapshotEntry: Codable, Equatable, Sendable {
    /// `exerciseKey` (lowercase-trimmed exercise name) — the doc id is
    /// reconstructed as "{userId}:{key}" on restore.
    var key: String
    var displayName: String
    var weightKg: Double
    var repMin: Int
    var repMax: Int
    var block: BlockType
    var week: Int
    var bias: ProgressionPrescriptionBias?

    init(state: ProgressionState) {
        key = state.exerciseKey
        displayName = state.displayName
        weightKg = state.currentWorkingWeightKg
        repMin = state.targetRepMin
        repMax = state.targetRepMax
        block = state.blockType
        week = state.weekInBlock
        bias = state.prescriptionBias
    }

    func restoredState(userId: String, at date: Date) -> ProgressionState {
        // Session-signal fields keep their declaration defaults (nil): the
        // engine rebuilds them from the first post-restore session.
        var state = ProgressionState(
            userId: userId,
            exerciseKey: key,
            displayName: displayName,
            currentWorkingWeightKg: weightKg,
            targetRepMin: repMin,
            targetRepMax: repMax,
            targetRPE: block.targetRPE,
            consecutiveSessionsAtTarget: 0,
            lastBumpDate: nil,
            blockType: block,
            weekInBlock: week,
            updatedAt: date
        )
        state.prescriptionBias = bias
        return state
    }
}

/// One `progression_families` row — already minimal, carried whole.
struct FamilySnapshotEntry: Codable, Equatable, Sendable {
    var family: String
    var unlockedTier: Int
    var currentTier: Int

    init(state: ProgressionFamilyState) {
        family = state.family
        unlockedTier = state.unlockedTier
        currentTier = state.currentTier
    }

    func restoredState(userId: String, at date: Date) -> ProgressionFamilyState {
        ProgressionFamilyState(
            userId: userId,
            family: family,
            unlockedTier: unlockedTier,
            currentTier: currentTier,
            updatedAt: date
        )
    }
}

// MARK: - Backup / restore service

final class ProgressSnapshotCloudBackup: @unchecked Sendable {
    static let shared = ProgressSnapshotCloudBackup()

    private let database: any DatabaseServiceProtocol
    private let logger: LoggingService

    /// Serializes the patch writes: each backup call chains behind the
    /// previous one, so two rapid completions can never land out of order and
    /// let a stale snapshot overwrite a newer one (locally or via the FIFO
    /// outbox). The chained task also RE-QUERIES at run time, so each patch
    /// carries the freshest local state. `lastPatched` is only touched from
    /// inside the chain, but stays lock-guarded for Sendable soundness.
    private let stateLock = NSLock()
    private var tail: Task<Void, Never>?
    private var lastPatched: [String: ProgressSnapshot] = [:]

    /// ISO-8601 dates to match both `DatabaseService` (local decode) and
    /// `UnboundSupabase.dbDecoder` (remote decode). The snapshot carries no
    /// dates today, but the strategy is pinned so adding one later cannot
    /// silently fork the local and remote representations.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(
        database: any DatabaseServiceProtocol = SyncedDatabase.shared,
        logger: LoggingService = .shared
    ) {
        self.database = database
        self.logger = logger
    }

    // MARK: - Write path

    /// Snapshot the three local collections for this user and patch the
    /// result onto the users doc under `progressSnapshot`. Skips the patch
    /// when the snapshot equals the last one sent this launch, so replayed or
    /// no-op completions add no outbox traffic.
    func backup(userId: String) async {
        await enqueuePatch(userId: userId).value
    }

    /// Chain-append happens in a synchronous helper: NSLock is not async-safe
    /// to hold across awaits, and Swift 6 rejects lock()/unlock() in async code.
    private func enqueuePatch(userId: String) -> Task<Void, Never> {
        stateLock.lock()
        defer { stateLock.unlock() }
        let previous = tail
        let task = Task { [weak self] in
            await previous?.value
            await self?.queryAndPatch(userId: userId)
        }
        tail = task
        return task
    }

    private func queryAndPatch(userId: String) async {
        let snapshot: ProgressSnapshot
        do {
            snapshot = try await currentSnapshot(userId: userId)
        } catch {
            logger.log(
                "Progress snapshot cloud backup: local query failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
            return
        }
        // An empty snapshot is never uploaded: a fresh install (or a local
        // reset) must not wipe the cloud copy a later restore depends on.
        guard !snapshot.isEmpty else { return }
        guard snapshot != cachedLastPatched(userId: userId) else { return }
        guard let encoded = Self.jsonObject(snapshot) else {
            logger.log(
                "Progress snapshot cloud backup: failed to encode snapshot",
                level: .error,
                context: ["userId": userId]
            )
            return
        }
        // `id` travels in the payload (the `sync_merge_row` ownership guard
        // reads `p_full->>'id'`) so the patch is valid even if this device has
        // no local `users` doc yet.
        do {
            try await database.update(
                ["id": userId, "progressSnapshot": encoded],
                collection: "users",
                documentId: userId
            )
            setCachedLastPatched(snapshot, userId: userId)
        } catch {
            logger.log(
                "Progress snapshot cloud backup failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    private func currentSnapshot(userId: String) async throws -> ProgressSnapshot {
        let movements: [MovementProgressState] = try await database.query(
            collection: "movement_progress",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: false,
            limit: nil
        )
        let loads: [ProgressionState] = try await database.query(
            collection: "progression_states",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: false,
            limit: nil
        )
        let families: [ProgressionFamilyState] = try await database.query(
            collection: "progression_families",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: false,
            limit: nil
        )
        return ProgressSnapshot(movements: movements, loads: loads, families: families)
    }

    // MARK: - Restore path

    /// Seed the local collections from a fetched server profile. Reconstructed
    /// docs use the same composite ids the live writers use, and the write is
    /// conservative so a stale server copy can NEVER regress local state:
    ///   - movements: written only when the local doc is absent or its
    ///     resolved tier (`MovementProgressTierResolver`) is lower; an existing
    ///     lower doc is raised via `merge(from:)`, which keeps its ledger and
    ///     `processedSourceLogIds` dedupe set intact.
    ///   - loads: written only when absent or the local working weight is lower.
    ///   - families: written only when absent or the local unlocked tier is lower.
    /// Safe to run every launch. (The launch-time call site is wired in
    /// RootView alongside `RankProgressCloudBackup.seedLocalStores`.)
    func seedLocalStores(from profile: UserProfile, userId: String) async {
        guard let snapshot = profile.progressSnapshot else { return }
        let restoredAt = Date()
        let bodyweightKg = profile.weightKg
        let sex = profile.biologicalSex

        for entry in snapshot.movements {
            let restored = entry.restoredState(userId: userId, at: restoredAt)
            if let local: MovementProgressState = try? await database.read(
                collection: "movement_progress",
                documentId: restored.id
            ) {
                let localTier = MovementProgressTierResolver.provenTier(
                    for: local, bodyweightKg: bodyweightKg, sex: sex
                )
                let restoredTier = MovementProgressTierResolver.provenTier(
                    for: restored, bodyweightKg: bodyweightKg, sex: sex
                )
                guard restoredTier > localTier else { continue }
                var merged = local
                merged.merge(from: restored)
                await write(merged, collection: "movement_progress", documentId: merged.id, userId: userId)
            } else {
                await write(restored, collection: "movement_progress", documentId: restored.id, userId: userId)
            }
        }

        for entry in snapshot.loads {
            let restored = entry.restoredState(userId: userId, at: restoredAt)
            if let local: ProgressionState = try? await database.read(
                collection: "progression_states",
                documentId: restored.id
            ), local.currentWorkingWeightKg >= restored.currentWorkingWeightKg {
                continue
            }
            await write(restored, collection: "progression_states", documentId: restored.id, userId: userId)
        }

        for entry in snapshot.families {
            let restored = entry.restoredState(userId: userId, at: restoredAt)
            if let local: ProgressionFamilyState = try? await database.read(
                collection: "progression_families",
                documentId: restored.id
            ), local.unlockedTier >= restored.unlockedTier {
                continue
            }
            await write(restored, collection: "progression_families", documentId: restored.id, userId: userId)
        }
    }

    // MARK: - Helpers

    /// Local-only collections skip the outbox inside `SyncedDatabase.create`,
    /// so restore writes never echo back into sync traffic.
    private func write<T: Codable>(
        _ value: T,
        collection: String,
        documentId: String,
        userId: String
    ) async {
        do {
            try await database.create(value, collection: collection, documentId: documentId)
        } catch {
            logger.log(
                "Progress snapshot restore write failed for \(collection)/\(documentId): \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    private func cachedLastPatched(userId: String) -> ProgressSnapshot? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return lastPatched[userId]
    }

    private func setCachedLastPatched(_ snapshot: ProgressSnapshot, userId: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        lastPatched[userId] = snapshot
    }

    /// Encode a Codable value to a Foundation JSON object (`[String: Any]`) so
    /// it can ride inside the `[String: Any]` field dict
    /// `DatabaseService.update` serializes with `JSONSerialization`.
    private static func jsonObject<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? encoder.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
