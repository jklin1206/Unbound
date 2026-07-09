import XCTest
@testable import UNBOUND

// Covers the two collection-doc progress domains of the sign-in migration:
// the overall-level XP ledger and the movement/loads/families docs. Asserts
// the re-key + never-regressing merges, zero-write no-ops, resume-safe
// idempotency (no AP double-count), and that each domain's cloud mirror fires
// under the Supabase id.

/// In-memory `DatabaseServiceProtocol` shared by the migration-domain tests
/// (this file + `UserDataMigrationRewardsAchievementsTests`). Counts creates
/// so zero-write outcomes are assertable.
actor UserDataMigrationFakeDatabase: DatabaseServiceProtocol {
    enum Failure: Error { case forcedCreateFailure }

    private var store: [String: [String: Any]] = [:]
    private var createCounter = 0
    private var failCreates = false

    func setFailCreates(_ value: Bool) { failCreates = value }
    func resetCreateCount() { createCounter = 0 }
    func createCount() -> Int { createCounter }

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
        if failCreates { throw Failure.forcedCreateFailure }
        createCounter += 1
        let data = try JSONEncoder().encode(object)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        store["\(collection)/\(documentId)"] = dict
    }

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        guard let dict = store["\(collection)/\(documentId)"] else {
            throw NSError(domain: "UserDataMigrationFakeDatabase", code: 404)
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        var existing = store["\(collection)/\(documentId)"] ?? [:]
        for (field, value) in fields { existing[field] = value }
        store["\(collection)/\(documentId)"] = existing
    }

    func delete(collection: String, documentId: String) async throws {
        store.removeValue(forKey: "\(collection)/\(documentId)")
    }

    func query<T: Codable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        orderBy: String?,
        descending: Bool,
        limit: Int?
    ) async throws -> [T] {
        let matches = store
            .filter { $0.key.hasPrefix("\(collection)/") }
            .map(\.value)
            .filter { document in
                guard let stored = document[field] as? NSObject else { return false }
                return stored.isEqual(value)
            }
        return try matches.map { document in
            let data = try JSONSerialization.data(withJSONObject: document)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}

// MARK: - Spies

private final class SpyLevelBackup: OverallLevelBackuping, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(progress: OverallLevelProgress, userId: String)] = []
    var calls: [(progress: OverallLevelProgress, userId: String)] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func backup(_ progress: OverallLevelProgress, userId: String) {
        lock.lock(); defer { lock.unlock() }
        recorded.append((progress, userId))
    }
}

private final class SpyProgressSnapshotBackup: ProgressSnapshotBackuping, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    var userIds: [String] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func backup(userId: String) async {
        lock.lock(); defer { lock.unlock() }
        recorded.append(userId)
    }
}

// MARK: - Overall level

final class UserDataMigrationLevelProgressTests: XCTestCase {
    private let legacyUserId = "legacy-user"
    private let supabaseUserId = UUID().uuidString
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func progress(userId: String, xp: Double, receipts: [String]) -> OverallLevelProgress {
        OverallLevelProgress(
            userId: userId,
            totalXP: xp,
            lastGainedXP: 10,
            processedSourceLogIds: receipts,
            processedSourceRewards: [:],
            updatedAt: now
        )
    }

    func test_legacy_only_rekeys_under_supabase_id_and_leaves_legacy_doc() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await db.create(
            progress(userId: legacyUserId, xp: 300, receipts: ["log-1", "log-2"]),
            collection: "overall_level_progress",
            documentId: legacyUserId
        )
        let spy = SpyLevelBackup()
        let sut = ProductionUserDataMigrationLevelProgressStore(database: db, backup: spy)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .rekeyed)
        let migrated: OverallLevelProgress = try await db.read(
            collection: "overall_level_progress",
            documentId: supabaseUserId
        )
        XCTAssertEqual(migrated.userId, supabaseUserId)
        XCTAssertEqual(migrated.totalXP, 300)
        XCTAssertEqual(migrated.processedSourceLogIds, ["log-1", "log-2"])
        // Legacy stays on disk as a harmless orphan, matching the rank re-key.
        let legacyDoc: OverallLevelProgress = try await db.read(
            collection: "overall_level_progress",
            documentId: legacyUserId
        )
        XCTAssertEqual(legacyDoc.userId, legacyUserId)
        // Cloud mirror fired under the NEW id with the merged ledger.
        XCTAssertEqual(spy.calls.map(\.userId), [supabaseUserId])
        XCTAssertEqual(spy.calls.first?.progress.totalXP, 300)
    }

    func test_both_sides_merge_takes_max_xp_and_unions_receipts() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await db.create(
            progress(userId: legacyUserId, xp: 300, receipts: ["log-a", "log-shared"]),
            collection: "overall_level_progress",
            documentId: legacyUserId
        )
        try await db.create(
            progress(userId: supabaseUserId, xp: 120, receipts: ["log-b", "log-shared"]),
            collection: "overall_level_progress",
            documentId: supabaseUserId
        )
        let spy = SpyLevelBackup()
        let sut = ProductionUserDataMigrationLevelProgressStore(database: db, backup: spy)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .merged)
        let merged: OverallLevelProgress = try await db.read(
            collection: "overall_level_progress",
            documentId: supabaseUserId
        )
        // Max, NOT sum — the two ledgers describe the same person.
        XCTAssertEqual(merged.totalXP, 300)
        XCTAssertEqual(Set(merged.processedSourceLogIds), ["log-a", "log-b", "log-shared"])
        XCTAssertEqual(spy.calls.map(\.userId), [supabaseUserId])
    }

    func test_target_only_is_noLegacy_with_zero_writes() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await db.create(
            progress(userId: supabaseUserId, xp: 120, receipts: ["log-b"]),
            collection: "overall_level_progress",
            documentId: supabaseUserId
        )
        await db.resetCreateCount()
        let spy = SpyLevelBackup()
        let sut = ProductionUserDataMigrationLevelProgressStore(database: db, backup: spy)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .noLegacy)
        let writes = await db.createCount()
        XCTAssertEqual(writes, 0)
        XCTAssertTrue(spy.calls.isEmpty)
    }

    func test_already_carried_legacy_is_unchanged_with_zero_writes() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await db.create(
            progress(userId: legacyUserId, xp: 100, receipts: ["log-a"]),
            collection: "overall_level_progress",
            documentId: legacyUserId
        )
        // The target already holds a superset (a completed prior run).
        try await db.create(
            progress(userId: supabaseUserId, xp: 300, receipts: ["log-a", "log-b"]),
            collection: "overall_level_progress",
            documentId: supabaseUserId
        )
        await db.resetCreateCount()
        let sut = ProductionUserDataMigrationLevelProgressStore(database: db, backup: SpyLevelBackup())

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .unchanged)
        let writes = await db.createCount()
        XCTAssertEqual(writes, 0)
    }

    func test_write_failure_reports_failed() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await db.create(
            progress(userId: legacyUserId, xp: 300, receipts: ["log-a"]),
            collection: "overall_level_progress",
            documentId: legacyUserId
        )
        await db.setFailCreates(true)
        let sut = ProductionUserDataMigrationLevelProgressStore(database: db, backup: SpyLevelBackup())

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .failed)
    }
}

// MARK: - Progress docs (movement / loads / families)

final class UserDataMigrationProgressDocsStoreTests: XCTestCase {
    private let legacyUserId = "legacy-user"
    private let supabaseUserId = UUID().uuidString
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func movement(
        userId: String,
        key: String = "bench-press",
        ap: Double,
        oneRM: Double?,
        receipts: [String]
    ) -> MovementProgressState {
        MovementProgressState(
            userId: userId,
            rankStandardMovementId: key,
            displayName: "Bench Press",
            rankTemplate: .barbellStrength,
            totalAP: ap,
            provenTier: .novice,
            bestEstimatedOneRepMaxKg: oneRM,
            processedSourceLogIds: receipts,
            updatedAt: now
        )
    }

    private func seedDocs(
        _ db: UserDataMigrationFakeDatabase,
        movements: [MovementProgressState] = [],
        loads: [ProgressionState] = [],
        families: [ProgressionFamilyState] = []
    ) async throws {
        for state in movements {
            try await db.create(state, collection: "movement_progress", documentId: state.id)
        }
        for state in loads {
            try await db.create(state, collection: "progression_states", documentId: state.id)
        }
        for state in families {
            try await db.create(state, collection: "progression_families", documentId: state.id)
        }
        await db.resetCreateCount()
    }

    func test_legacy_only_rekeys_all_three_doc_kinds_under_supabase_composite_ids() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await seedDocs(
            db,
            movements: [movement(userId: legacyUserId, ap: 50, oneRM: 90, receipts: ["log-a"])],
            loads: [ProgressionState.seed(userId: legacyUserId, exercise: "Bench Press", startingWeightKg: 80)],
            families: [ProgressionFamilyState(userId: legacyUserId, family: "push", unlockedTier: 3, currentTier: 2, updatedAt: now)]
        )
        let spy = SpyProgressSnapshotBackup()
        let sut = ProductionUserDataMigrationProgressDocsStore(database: db, backup: spy)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .rekeyed)
        let migratedMovement: MovementProgressState = try await db.read(
            collection: "movement_progress",
            documentId: "\(supabaseUserId):bench-press"
        )
        XCTAssertEqual(migratedMovement.userId, supabaseUserId)
        XCTAssertEqual(migratedMovement.totalAP, 50)
        XCTAssertEqual(migratedMovement.processedSourceLogIds, ["log-a"])
        let migratedLoad: ProgressionState = try await db.read(
            collection: "progression_states",
            documentId: "\(supabaseUserId):bench press"
        )
        XCTAssertEqual(migratedLoad.userId, supabaseUserId)
        XCTAssertEqual(migratedLoad.currentWorkingWeightKg, 80)
        let migratedFamily: ProgressionFamilyState = try await db.read(
            collection: "progression_families",
            documentId: "\(supabaseUserId):push"
        )
        XCTAssertEqual(migratedFamily.unlockedTier, 3)
        // Legacy docs stay in place as harmless orphans.
        let legacyMovement: MovementProgressState = try await db.read(
            collection: "movement_progress",
            documentId: "\(legacyUserId):bench-press"
        )
        XCTAssertEqual(legacyMovement.userId, legacyUserId)
        XCTAssertEqual(spy.userIds, [supabaseUserId])
    }

    func test_movement_merge_unions_receipts_and_rerun_does_not_double_ap() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await seedDocs(
            db,
            movements: [
                movement(userId: legacyUserId, ap: 50, oneRM: 90, receipts: ["log-a"]),
                movement(userId: supabaseUserId, ap: 30, oneRM: 110, receipts: ["log-b"]),
            ]
        )
        let sut = ProductionUserDataMigrationProgressDocsStore(database: db, backup: SpyProgressSnapshotBackup())

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .merged)
        let merged: MovementProgressState = try await db.read(
            collection: "movement_progress",
            documentId: "\(supabaseUserId):bench-press"
        )
        // MovementProgressState.merge(from:) semantics: ledger sum, best-of
        // metrics, receipts union.
        XCTAssertEqual(merged.totalAP, 80)
        XCTAssertEqual(merged.bestEstimatedOneRepMaxKg, 110)
        XCTAssertEqual(Set(merged.processedSourceLogIds), ["log-a", "log-b"])

        // Resumed run (e.g. another domain failed): the receipts-subset guard
        // must keep the merge idempotent — AP is NOT summed twice.
        let rerun = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)
        XCTAssertEqual(rerun, .unchanged)
        let afterRerun: MovementProgressState = try await db.read(
            collection: "movement_progress",
            documentId: "\(supabaseUserId):bench-press"
        )
        XCTAssertEqual(afterRerun.totalAP, 80)
    }

    func test_loads_and_families_keep_the_higher_side() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await seedDocs(
            db,
            loads: [
                // Target already lifts heavier — legacy must not regress it.
                ProgressionState.seed(userId: legacyUserId, exercise: "Bench Press", startingWeightKg: 80),
                ProgressionState.seed(userId: supabaseUserId, exercise: "Bench Press", startingWeightKg: 100),
                // Legacy is heavier here — adopted wholesale.
                ProgressionState.seed(userId: legacyUserId, exercise: "Squat", startingWeightKg: 140),
                ProgressionState.seed(userId: supabaseUserId, exercise: "Squat", startingWeightKg: 120),
            ],
            families: [
                ProgressionFamilyState(userId: legacyUserId, family: "push", unlockedTier: 2, currentTier: 2, updatedAt: now),
                ProgressionFamilyState(userId: supabaseUserId, family: "push", unlockedTier: 3, currentTier: 3, updatedAt: now),
                ProgressionFamilyState(userId: legacyUserId, family: "pull", unlockedTier: 4, currentTier: 4, updatedAt: now),
                ProgressionFamilyState(userId: supabaseUserId, family: "pull", unlockedTier: 3, currentTier: 3, updatedAt: now),
            ]
        )
        let sut = ProductionUserDataMigrationProgressDocsStore(database: db, backup: SpyProgressSnapshotBackup())

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .merged)
        let bench: ProgressionState = try await db.read(
            collection: "progression_states",
            documentId: "\(supabaseUserId):bench press"
        )
        XCTAssertEqual(bench.currentWorkingWeightKg, 100)
        let squat: ProgressionState = try await db.read(
            collection: "progression_states",
            documentId: "\(supabaseUserId):squat"
        )
        XCTAssertEqual(squat.currentWorkingWeightKg, 140)
        XCTAssertEqual(squat.userId, supabaseUserId)
        let push: ProgressionFamilyState = try await db.read(
            collection: "progression_families",
            documentId: "\(supabaseUserId):push"
        )
        XCTAssertEqual(push.unlockedTier, 3)
        let pull: ProgressionFamilyState = try await db.read(
            collection: "progression_families",
            documentId: "\(supabaseUserId):pull"
        )
        XCTAssertEqual(pull.unlockedTier, 4)
    }

    func test_no_legacy_docs_is_noop_without_backup_fire() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await seedDocs(
            db,
            movements: [movement(userId: supabaseUserId, ap: 30, oneRM: 110, receipts: ["log-b"])]
        )
        let spy = SpyProgressSnapshotBackup()
        let sut = ProductionUserDataMigrationProgressDocsStore(database: db, backup: spy)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .noLegacy)
        let writes = await db.createCount()
        XCTAssertEqual(writes, 0)
        XCTAssertTrue(spy.userIds.isEmpty)
    }

    func test_write_failure_reports_failed() async throws {
        let db = UserDataMigrationFakeDatabase()
        try await seedDocs(
            db,
            movements: [movement(userId: legacyUserId, ap: 50, oneRM: 90, receipts: ["log-a"])]
        )
        await db.setFailCreates(true)
        let sut = ProductionUserDataMigrationProgressDocsStore(database: db, backup: SpyProgressSnapshotBackup())

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .failed)
    }
}
