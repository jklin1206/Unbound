import XCTest
@testable import UNBOUND

/// Covers the cloud backup + restore seam for the overall level: the ordered
/// users-doc patch fired on every persisted ingest, and the higher-totalXP-wins
/// restore into the local `overall_level_progress` doc (XP is monotone, so a
/// stale server copy must never regress a locally-earned level).
final class OverallLevelCloudBackupTests: XCTestCase {

    // MARK: - Recording database

    private enum RecordingDatabaseError: Error {
        case notFound(collection: String, documentId: String)
    }

    /// In-memory `DatabaseServiceProtocol` that records every write in arrival
    /// order. Docs round-trip through ISO-8601 JSON to match the production
    /// encoders on both sides of the seam.
    private final class RecordingDatabase: DatabaseServiceProtocol, @unchecked Sendable {
        struct Update { let collection: String; let documentId: String; let fields: [String: Any] }
        struct Create { let collection: String; let documentId: String }

        private let lock = NSLock()
        private var docs: [String: Data] = [:]
        private var recordedUpdates: [Update] = []
        private var recordedCreates: [Create] = []
        /// Consumed FIFO by `update`; slowing only the FIRST patch proves the
        /// ordered chain (not scheduling luck) enforces call order.
        private var updateDelaysNs: [UInt64] = []
        private var onWrite: (() -> Void)?

        private static let encoder: JSONEncoder = {
            let e = JSONEncoder()
            e.dateEncodingStrategy = .iso8601
            return e
        }()
        private static let decoder: JSONDecoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }()

        var updates: [Update] { lock.lock(); defer { lock.unlock() }; return recordedUpdates }
        var creates: [Create] { lock.lock(); defer { lock.unlock() }; return recordedCreates }

        func configure(updateDelaysNs: [UInt64] = [], onWrite: (() -> Void)? = nil) {
            lock.lock(); defer { lock.unlock() }
            self.updateDelaysNs = updateDelaysNs
            self.onWrite = onWrite
        }

        /// Seed a doc directly, without recording it as a write under test.
        func seedDoc<T: Codable>(_ object: T, collection: String, documentId: String) throws {
            let data = try Self.encoder.encode(object)
            lock.lock(); defer { lock.unlock() }
            docs["\(collection)/\(documentId)"] = data
        }

        func storedDoc<T: Codable>(collection: String, documentId: String) throws -> T {
            lock.lock()
            let data = docs["\(collection)/\(documentId)"]
            lock.unlock()
            guard let data else {
                throw RecordingDatabaseError.notFound(collection: collection, documentId: documentId)
            }
            return try Self.decoder.decode(T.self, from: data)
        }

        func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
            let data = try Self.encoder.encode(object)
            lock.lock()
            docs["\(collection)/\(documentId)"] = data
            recordedCreates.append(Create(collection: collection, documentId: documentId))
            let callback = onWrite
            lock.unlock()
            callback?()
        }

        func read<T: Codable>(collection: String, documentId: String) async throws -> T {
            try storedDoc(collection: collection, documentId: documentId)
        }

        func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
            lock.lock()
            let delay = updateDelaysNs.isEmpty ? nil : updateDelaysNs.removeFirst()
            lock.unlock()
            if let delay { try await Task.sleep(nanoseconds: delay) }
            lock.lock()
            recordedUpdates.append(Update(collection: collection, documentId: documentId, fields: fields))
            let callback = onWrite
            lock.unlock()
            callback?()
        }

        func delete(collection: String, documentId: String) async throws {
            lock.lock(); defer { lock.unlock() }
            docs.removeValue(forKey: "\(collection)/\(documentId)")
        }

        func query<T: Codable>(
            collection: String,
            field: String,
            isEqualTo value: Any,
            orderBy: String?,
            descending: Bool,
            limit: Int?
        ) async throws -> [T] {
            []
        }
    }

    // MARK: - Fixtures

    /// XP totals anchored to `OverallLevelCurve` (project rule: never hardcode
    /// curve values); whole-second dates so ISO-8601 round-trips exactly.
    private func progress(
        userId: String = "u1",
        level: Int,
        receipts: [String] = [],
        rewards: [String: OverallLevelReward] = [:],
        updatedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> OverallLevelProgress {
        OverallLevelProgress(
            userId: userId,
            totalXP: OverallLevelCurve.xpRequired(forLevel: level),
            lastGainedXP: 25,
            processedSourceLogIds: receipts,
            processedSourceRewards: rewards,
            updatedAt: updatedAt
        )
    }

    private func profile(overallLevelBackup: OverallLevelProgress?) -> UserProfile {
        var profile = UserProfile(
            id: "u1",
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0
        )
        profile.overallLevelBackup = overallLevelBackup
        return profile
    }

    private func decodeBackupPayload(_ fields: [String: Any]) throws -> OverallLevelProgress {
        let payload = try XCTUnwrap(fields["overallLevelBackup"])
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OverallLevelProgress.self, from: data)
    }

    // MARK: - (a) backup patches the users doc

    func test_backup_patches_users_doc_with_full_progress_payload() async throws {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)
        let reward = OverallLevelReward(
            xpGained: 30,
            noveltyMultiplier: 1.2,
            previousXP: OverallLevelCurve.xpRequired(forLevel: 11),
            currentXP: OverallLevelCurve.xpRequired(forLevel: 12),
            previousLevel: 11,
            currentLevel: 12,
            previousProgressToNextLevel: 0,
            currentProgressToNextLevel: 0
        )
        let progress = progress(level: 12, receipts: ["log-1"], rewards: ["log-1": reward])

        let landed = expectation(description: "patch landed")
        db.configure(onWrite: { landed.fulfill() })
        backup.backup(progress, userId: "u1")
        await fulfillment(of: [landed], timeout: 2)

        XCTAssertEqual(db.updates.count, 1)
        let update = try XCTUnwrap(db.updates.first)
        XCTAssertEqual(update.collection, "users")
        XCTAssertEqual(update.documentId, "u1")
        XCTAssertEqual(
            update.fields["id"] as? String, "u1",
            "id must travel in the payload for the sync_merge_row ownership guard"
        )
        let decoded = try decodeBackupPayload(update.fields)
        XCTAssertEqual(
            decoded, progress,
            "the WHOLE ledger — XP plus receipts — must round-trip, or a restore could double-ingest"
        )
    }

    // MARK: - (b) rapid backups land in call order

    func test_rapid_successive_backups_land_in_call_order() async {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)
        let first = progress(level: 10)
        let second = progress(level: 11)

        let landed = expectation(description: "both patches landed")
        landed.expectedFulfillmentCount = 2
        // Slow only the FIRST patch: without the ordered chain the second
        // (stale-overwriting) snapshot would overtake it.
        db.configure(updateDelaysNs: [80_000_000], onWrite: { landed.fulfill() })
        backup.backup(first, userId: "u1")
        backup.backup(second, userId: "u1")
        await fulfillment(of: [landed], timeout: 3)

        let totals = db.updates.compactMap {
            ($0.fields["overallLevelBackup"] as? [String: Any])?["totalXP"] as? Double
        }
        XCTAssertEqual(totals, [first.totalXP, second.totalXP])
    }

    // MARK: - (c) seed adopts server when local is absent

    func test_seed_adopts_server_copy_when_local_doc_is_absent() async throws {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)
        let server = progress(level: 12, receipts: ["log-1"])

        await backup.seedLocalStores(from: profile(overallLevelBackup: server), userId: "u1")

        XCTAssertEqual(db.creates.map(\.collection), ["overall_level_progress"])
        XCTAssertEqual(db.creates.map(\.documentId), ["u1"])
        let restored: OverallLevelProgress = try db.storedDoc(
            collection: "overall_level_progress",
            documentId: "u1"
        )
        XCTAssertEqual(restored, server)
        XCTAssertTrue(db.updates.isEmpty, "seeding must never fire a cloud write of its own")
    }

    func test_seed_is_noop_when_profile_carries_no_backup() async {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)

        await backup.seedLocalStores(from: profile(overallLevelBackup: nil), userId: "u1")

        XCTAssertTrue(db.creates.isEmpty)
        XCTAssertTrue(db.updates.isEmpty)
    }

    // MARK: - (d) local wins when higher

    func test_seed_keeps_local_when_local_totalXP_is_higher() async throws {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)
        let local = progress(level: 15, receipts: ["local-log"])
        try db.seedDoc(local, collection: "overall_level_progress", documentId: "u1")

        await backup.seedLocalStores(
            from: profile(overallLevelBackup: progress(level: 12)),
            userId: "u1"
        )

        XCTAssertTrue(db.creates.isEmpty, "a stale server copy must never regress a locally-earned level")
        XCTAssertTrue(db.updates.isEmpty)
        let kept: OverallLevelProgress = try db.storedDoc(
            collection: "overall_level_progress",
            documentId: "u1"
        )
        XCTAssertEqual(kept, local)
    }

    // MARK: - (e) server wins when higher

    func test_seed_adopts_server_when_server_totalXP_is_higher() async throws {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)
        try db.seedDoc(progress(level: 10), collection: "overall_level_progress", documentId: "u1")
        let server = progress(level: 12, receipts: ["log-1", "log-2"])

        await backup.seedLocalStores(from: profile(overallLevelBackup: server), userId: "u1")

        XCTAssertEqual(db.creates.count, 1)
        let restored: OverallLevelProgress = try db.storedDoc(
            collection: "overall_level_progress",
            documentId: "u1"
        )
        XCTAssertEqual(restored, server)
    }

    // MARK: - (f) equal totals write nothing

    func test_seed_is_noop_writing_nothing_when_totals_are_equal() async throws {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)
        try db.seedDoc(progress(level: 12), collection: "overall_level_progress", documentId: "u1")

        await backup.seedLocalStores(
            from: profile(overallLevelBackup: progress(level: 12)),
            userId: "u1"
        )

        XCTAssertTrue(db.creates.isEmpty)
        XCTAssertTrue(db.updates.isEmpty)
    }

    // MARK: - restored doc is re-keyed to the current user

    func test_seed_rekeys_a_backup_carried_from_a_migrated_identity() async throws {
        let db = RecordingDatabase()
        let backup = OverallLevelCloudBackup(database: db)
        let server = progress(userId: "anon-old", level: 12, receipts: ["log-1"])

        await backup.seedLocalStores(from: profile(overallLevelBackup: server), userId: "u1")

        let restored: OverallLevelProgress = try db.storedDoc(
            collection: "overall_level_progress",
            documentId: "u1"
        )
        XCTAssertEqual(
            restored.id, "u1",
            "restored doc id must match the current user or the next ingest forks the ledger"
        )
        XCTAssertEqual(restored.totalXP, server.totalXP)
        XCTAssertEqual(restored.processedSourceLogIds, ["log-1"])
    }
}
