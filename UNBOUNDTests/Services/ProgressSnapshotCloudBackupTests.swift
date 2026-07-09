import XCTest
@testable import UNBOUND

/// Covers the cloud backup + restore seam for the local-only progression
/// collections (movement_progress / progression_states / progression_families):
/// the compact users-doc snapshot carries exactly the load-bearing fields, the
/// redundant-patch skip, and the never-regressing seed back into local stores.
final class ProgressSnapshotCloudBackupTests: XCTestCase {
    private let userId = "u1"

    /// The users-doc shape this feature patches; mirrors the coordinator's
    /// `UserProfile.progressSnapshot` contract.
    private struct UsersDocStub: Codable {
        var id: String
        var progressSnapshot: ProgressSnapshot
    }

    // MARK: - Fixtures

    private func benchState(
        userId: String = "u1",
        provenTier: SkillTier = .novice,
        totalAP: Double = 42,
        oneRepMaxKg: Double? = 116.6,
        loadKg: Double? = 100,
        processedSourceLogIds: [String] = ["log-1"]
    ) -> MovementProgressState {
        MovementProgressState(
            userId: userId,
            rankStandardMovementId: "exercise.bench-press",
            displayName: "Bench Press",
            rankTemplate: .barbellStrength,
            totalAP: totalAP,
            provenTier: provenTier,
            bestEstimatedOneRepMaxKg: oneRepMaxKg,
            bestLoadKg: loadKg,
            lastGainedAP: 5,
            lastLoggedAt: Date(timeIntervalSince1970: 900),
            contributingMovementIds: ["exercise.bench-press"],
            processedSourceLogIds: processedSourceLogIds,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    /// A bodyweight-reps standard deliberately polluted with cross-template
    /// metrics, to prove the snapshot only carries what its template derives.
    private func pushupState(userId: String = "u1") -> MovementProgressState {
        MovementProgressState(
            userId: userId,
            rankStandardMovementId: "exercise.push-up",
            displayName: "Push-Up",
            rankTemplate: .bodyweightReps,
            totalAP: 10,
            provenTier: .apprentice,
            bestEstimatedOneRepMaxKg: 50,
            bestLoadKg: 20,
            bestReps: 30,
            bestHoldSeconds: 60,
            processedSourceLogIds: ["log-x"],
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func benchLoadState(
        userId: String = "u1",
        weightKg: Double = 80
    ) -> ProgressionState {
        var state = ProgressionState(
            userId: userId,
            exerciseKey: "bench press",
            displayName: "Bench Press",
            currentWorkingWeightKg: weightKg,
            targetRepMin: 6,
            targetRepMax: 8,
            targetRPE: 8,
            consecutiveSessionsAtTarget: 1,
            lastBumpDate: Date(timeIntervalSince1970: 500),
            blockType: .intensification,
            weekInBlock: 2,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        state.prescriptionBias = .harder
        state.lastSessionReps = 7
        state.lastSessionRPE = 8
        return state
    }

    private func pushFamilyState(
        userId: String = "u1",
        unlockedTier: Int = 3,
        currentTier: Int = 2
    ) -> ProgressionFamilyState {
        ProgressionFamilyState(
            userId: userId,
            family: "push",
            unlockedTier: unlockedTier,
            currentTier: currentTier,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func seed(
        _ database: TestProgressionDatabase,
        movements: [MovementProgressState] = [],
        loads: [ProgressionState] = [],
        families: [ProgressionFamilyState] = []
    ) async throws {
        for state in movements {
            try await database.create(state, collection: "movement_progress", documentId: state.id)
        }
        for state in loads {
            try await database.create(state, collection: "progression_states", documentId: state.id)
        }
        for state in families {
            try await database.create(state, collection: "progression_families", documentId: state.id)
        }
    }

    private func profile(snapshot: ProgressSnapshot?) -> UserProfile {
        var profile = UserProfile(
            id: userId,
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0,
            weightKg: 80,
            biologicalSex: .male
        )
        profile.progressSnapshot = snapshot
        return profile
    }

    // MARK: - (a) backup patches the users doc with the load-bearing snapshot

    func test_backup_patchesUsersDocWithLoadBearingSnapshot() async throws {
        let database = TestProgressionDatabase()
        try await seed(
            database,
            movements: [benchState(), pushupState()],
            loads: [benchLoadState()],
            families: [pushFamilyState()]
        )
        // Another user's rows must never leak into u1's snapshot.
        try await seed(
            database,
            movements: [benchState(userId: "u2")],
            loads: [benchLoadState(userId: "u2", weightKg: 200)]
        )
        let backup = ProgressSnapshotCloudBackup(database: database)

        await backup.backup(userId: userId)

        let doc: UsersDocStub = try await database.read(collection: "users", documentId: userId)
        let snapshot = doc.progressSnapshot
        XCTAssertEqual(doc.id, userId)
        XCTAssertEqual(snapshot.v, 1)

        XCTAssertEqual(snapshot.movements.map(\.key), ["exercise.bench-press", "exercise.push-up"])
        let bench = try XCTUnwrap(snapshot.movements.first { $0.key == "exercise.bench-press" })
        XCTAssertEqual(bench.displayName, "Bench Press")
        XCTAssertEqual(bench.rankTemplate, .barbellStrength)
        XCTAssertEqual(bench.provenTier, .novice)
        XCTAssertEqual(bench.oneRepMaxKg, 116.6)
        XCTAssertEqual(bench.loadKg, 100)

        XCTAssertEqual(snapshot.loads.map(\.key), ["bench press"])
        let load = try XCTUnwrap(snapshot.loads.first)
        XCTAssertEqual(load.displayName, "Bench Press")
        XCTAssertEqual(load.weightKg, 80)
        XCTAssertEqual(load.repMin, 6)
        XCTAssertEqual(load.repMax, 8)
        XCTAssertEqual(load.block, .intensification)
        XCTAssertEqual(load.week, 2)
        XCTAssertEqual(load.bias, .harder)

        XCTAssertEqual(snapshot.families.map(\.family), ["push"])
        let family = try XCTUnwrap(snapshot.families.first)
        XCTAssertEqual(family.unlockedTier, 3)
        XCTAssertEqual(family.currentTier, 2)
    }

    // MARK: - (b) snapshot omits ledger fields and non-template metrics

    func test_backup_omitsLedgerFieldsAndNonTemplateMetrics() async throws {
        let database = TestProgressionDatabase()
        try await seed(database, movements: [pushupState()])
        let backup = ProgressSnapshotCloudBackup(database: database)

        await backup.backup(userId: userId)

        let rawDocument = await database.rawDocument(collection: "users", documentId: userId)
        let raw = try XCTUnwrap(rawDocument)
        let snapshotJSON = try XCTUnwrap(raw["progressSnapshot"] as? [String: Any])
        let movementsJSON = try XCTUnwrap(snapshotJSON["movements"] as? [[String: Any]])
        let pushup = try XCTUnwrap(movementsJSON.first { ($0["key"] as? String) == "exercise.push-up" })

        // Template metric only: bodyweightReps carries reps, nothing else.
        XCTAssertEqual(pushup["reps"] as? Int, 30)
        XCTAssertNil(pushup["oneRepMaxKg"])
        XCTAssertNil(pushup["loadKg"])
        XCTAssertNil(pushup["holdSeconds"])
        XCTAssertNil(pushup["durationSeconds"])

        // Ledger / exactly-once machinery never travels.
        XCTAssertNil(pushup["totalAP"])
        XCTAssertNil(pushup["processedSourceLogIds"])
        XCTAssertNil(pushup["contributingMovementIds"])
        XCTAssertNil(pushup["lastGainedAP"])
        XCTAssertNil(pushup["lastLoggedAt"])
    }

    // MARK: - (c) round trip: original -> snapshot -> restore -> same resolved tier

    func test_roundTrip_restoresResolvedTierAndWorkingWeight() async throws {
        let sourceDatabase = TestProgressionDatabase()
        let originalBench = benchState()
        let originalPushup = pushupState()
        try await seed(
            sourceDatabase,
            movements: [originalBench, originalPushup],
            loads: [benchLoadState(weightKg: 80)],
            families: [pushFamilyState()]
        )
        await ProgressSnapshotCloudBackup(database: sourceDatabase).backup(userId: userId)
        let doc: UsersDocStub = try await sourceDatabase.read(collection: "users", documentId: userId)

        // Fresh install: empty local DB seeded from the server profile.
        let restoreDatabase = TestProgressionDatabase()
        let restoreBackup = ProgressSnapshotCloudBackup(database: restoreDatabase)
        await restoreBackup.seedLocalStores(from: profile(snapshot: doc.progressSnapshot), userId: userId)

        for original in [originalBench, originalPushup] {
            let restored: MovementProgressState = try await restoreDatabase.read(
                collection: "movement_progress",
                documentId: original.id
            )
            XCTAssertEqual(
                MovementProgressTierResolver.provenTier(for: restored, bodyweightKg: 80, sex: .male),
                MovementProgressTierResolver.provenTier(for: original, bodyweightKg: 80, sex: .male),
                "resolved tier must survive the snapshot round trip for \(original.displayName)"
            )
            // Non-snapshot fields land on their defaults.
            XCTAssertEqual(restored.totalAP, 0)
            XCTAssertTrue(restored.processedSourceLogIds.isEmpty)
        }

        let restoredLoad: ProgressionState = try await restoreDatabase.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        XCTAssertEqual(restoredLoad.currentWorkingWeightKg, 80)
        XCTAssertEqual(restoredLoad.targetRepMin, 6)
        XCTAssertEqual(restoredLoad.targetRepMax, 8)
        XCTAssertEqual(restoredLoad.blockType, .intensification)
        XCTAssertEqual(restoredLoad.weekInBlock, 2)
        XCTAssertEqual(restoredLoad.prescriptionBias, .harder)
        // Session-signal fields restart on their defaults.
        XCTAssertEqual(restoredLoad.consecutiveSessionsAtTarget, 0)
        XCTAssertNil(restoredLoad.lastSessionReps)

        let restoredFamily: ProgressionFamilyState = try await restoreDatabase.read(
            collection: "progression_families",
            documentId: "\(userId):push"
        )
        XCTAssertEqual(restoredFamily.unlockedTier, 3)
        XCTAssertEqual(restoredFamily.currentTier, 2)
    }

    // MARK: - (d) seed never regresses local state

    func test_seed_neverClobbersHigherLocalState() async throws {
        let database = TestProgressionDatabase()
        let localBench = benchState(provenTier: .master, totalAP: 99, processedSourceLogIds: ["local-log"])
        try await seed(
            database,
            movements: [localBench],
            loads: [benchLoadState(weightKg: 100)],
            families: [pushFamilyState(unlockedTier: 5, currentTier: 4)]
        )
        // Stale server copy: lower tier, lighter working weight, lower unlock.
        let staleSnapshot = ProgressSnapshot(
            movements: [benchState(provenTier: .novice, oneRepMaxKg: 60, loadKg: 55)],
            loads: [benchLoadState(weightKg: 80)],
            families: [pushFamilyState(unlockedTier: 3, currentTier: 2)]
        )
        let backup = ProgressSnapshotCloudBackup(database: database)

        await backup.seedLocalStores(from: profile(snapshot: staleSnapshot), userId: userId)

        let bench: MovementProgressState = try await database.read(
            collection: "movement_progress",
            documentId: localBench.id
        )
        XCTAssertEqual(bench.provenTier, .master, "server copy must never lower a movement tier")
        XCTAssertEqual(bench.totalAP, 99)
        XCTAssertEqual(bench.processedSourceLogIds, ["local-log"])

        let load: ProgressionState = try await database.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        XCTAssertEqual(load.currentWorkingWeightKg, 100, "server copy must never lower a working weight")

        let family: ProgressionFamilyState = try await database.read(
            collection: "progression_families",
            documentId: "\(userId):push"
        )
        XCTAssertEqual(family.unlockedTier, 5, "server copy must never lower a family unlock")
        XCTAssertEqual(family.currentTier, 4)
    }

    func test_seed_raisesLowerLocalMovementWithoutLosingItsLedger() async throws {
        let database = TestProgressionDatabase()
        let weakLocal = benchState(
            provenTier: .initiate,
            totalAP: 7,
            oneRepMaxKg: nil,
            loadKg: nil,
            processedSourceLogIds: ["seen-1"]
        )
        try await seed(database, movements: [weakLocal])
        let serverSnapshot = ProgressSnapshot(
            movements: [benchState(provenTier: .veteran)],
            loads: [],
            families: []
        )
        let backup = ProgressSnapshotCloudBackup(database: database)

        await backup.seedLocalStores(from: profile(snapshot: serverSnapshot), userId: userId)

        let merged: MovementProgressState = try await database.read(
            collection: "movement_progress",
            documentId: weakLocal.id
        )
        XCTAssertEqual(merged.provenTier, .veteran, "a higher server tier raises the local doc")
        XCTAssertEqual(merged.bestEstimatedOneRepMaxKg, 116.6)
        XCTAssertEqual(merged.totalAP, 7, "the local ledger survives the raise")
        XCTAssertEqual(merged.processedSourceLogIds, ["seen-1"], "the exactly-once dedupe set survives the raise")
    }

    // MARK: - (e) seed is a no-op without a snapshot

    func test_seed_isNoOpWhenProfileCarriesNoSnapshot() async throws {
        let database = TestProgressionDatabase()
        let backup = ProgressSnapshotCloudBackup(database: database)

        await backup.seedLocalStores(from: profile(snapshot: nil), userId: userId)

        let movementCount = await database.countKeys(prefix: "movement_progress/")
        let loadCount = await database.countKeys(prefix: "progression_states/")
        let familyCount = await database.countKeys(prefix: "progression_families/")
        XCTAssertEqual(movementCount, 0)
        XCTAssertEqual(loadCount, 0)
        XCTAssertEqual(familyCount, 0)
    }

    // MARK: - (f) unchanged snapshot skips the redundant patch

    func test_backup_skipsRedundantPatchForUnchangedSnapshot() async throws {
        let database = TestProgressionDatabase()
        let backup = ProgressSnapshotCloudBackup(database: database)

        // Nothing local yet: an empty snapshot is never uploaded.
        await backup.backup(userId: userId)
        var patchCount = await database.updateCount(collection: "users", documentId: userId)
        XCTAssertEqual(patchCount, 0)

        try await seed(database, movements: [benchState()], loads: [benchLoadState()])
        await backup.backup(userId: userId)
        await backup.backup(userId: userId)
        patchCount = await database.updateCount(collection: "users", documentId: userId)
        XCTAssertEqual(patchCount, 1, "an unchanged snapshot must not re-patch the users doc")

        // New local progress invalidates the cache and patches again.
        try await seed(database, movements: [pushupState()])
        await backup.backup(userId: userId)
        patchCount = await database.updateCount(collection: "users", documentId: userId)
        XCTAssertEqual(patchCount, 2)
    }
}
