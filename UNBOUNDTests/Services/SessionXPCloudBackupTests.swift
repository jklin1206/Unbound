import XCTest
@testable import UNBOUND

/// Covers the cloud mirror for the session-XP streak record: the ordered
/// users-doc patch under `streakBackup`, and the restore seam — wholesale
/// adoption when local is empty, the never-regressing merge when both sides
/// exist, and the adopt-only-when-empty rule for the bonus ledger.
@MainActor
final class SessionXPCloudBackupTests: XCTestCase {
    private var suiteName: String!
    private var defaults: WriteRecordingDefaults!
    private var service: SessionXPService!
    private let userId = "u1"

    override func setUp() {
        super.setUp()
        suiteName = "SessionXPCloudBackupTests-\(UUID().uuidString)"
        defaults = WriteRecordingDefaults(suiteName: suiteName)!
        // No backup wired: seeding must never fire a cloud write of its own.
        service = SessionXPService(defaults: defaults, backup: nil)
        defaults.recordedSetKeys.removeAll()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Fixtures

    private func record(
        userId: String = "u1",
        total: Int,
        streak: Int,
        longest: Int,
        lastSession: Date?
    ) -> SessionXPRecord {
        SessionXPRecord(
            userId: userId,
            totalSessions: total,
            currentStreak: streak,
            longestStreak: longest,
            lastSessionDate: lastSession,
            weeklyCount: 0,
            weekStartDate: Date(timeIntervalSince1970: 0)
        )
    }

    private func profile(streakBackup: SessionXPBackup?) -> UserProfile {
        var profile = UserProfile(
            id: userId,
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0
        )
        profile.streakBackup = streakBackup
        return profile
    }

    /// Decode the patched jsonb payload with the same conventions
    /// `UnboundSupabase.dbDecoder` applies to production reads, proving the
    /// backup round-trips through the remote decode path.
    nonisolated private func decodedPayload(_ update: SpyDatabase.Update) throws -> SessionXPBackup {
        let object = try XCTUnwrap(update.fields["streakBackup"])
        let data = try JSONSerialization.data(withJSONObject: object)
        return try UnboundSupabase.dbDecoder.decode(SessionXPBackup.self, from: data)
    }

    // MARK: - (a) users-doc patch shape

    func test_backup_patches_users_doc_under_streakBackup_with_id_in_payload() async throws {
        let spy = SpyDatabase()
        let backup = SessionXPCloudBackup(database: spy)
        let rec = record(total: 3, streak: 2, longest: 4, lastSession: Date(timeIntervalSince1970: 1_000))
        let bonus = SessionXPBonusEntry(amount: 20, reason: "linked", date: Date(timeIntervalSince1970: 2_000))

        backup.backup(record: rec, bonuses: [bonus], userId: userId)

        let updates = await spy.waitForUpdates(count: 1)
        let update = try XCTUnwrap(updates.first)
        XCTAssertEqual(update.collection, "users")
        XCTAssertEqual(update.documentId, userId)
        XCTAssertEqual(update.fields["id"] as? String, userId, "id must travel in the payload for the sync_merge_row ownership guard")
        XCTAssertEqual(try decodedPayload(update), SessionXPBackup(record: rec, bonuses: [bonus]))
    }

    // MARK: - (b) write ordering

    func test_rapid_backups_land_in_call_order() async throws {
        let spy = SpyDatabase()
        let backup = SessionXPCloudBackup(database: spy)

        for total in 1...5 {
            backup.backup(
                record: record(total: total, streak: total, longest: total, lastSession: Date(timeIntervalSince1970: 1_000)),
                bonuses: [],
                userId: userId
            )
        }

        let updates = await spy.waitForUpdates(count: 5)
        let totals = try updates.map { try decodedPayload($0).record.totalSessions }
        XCTAssertEqual(totals, [1, 2, 3, 4, 5], "a stale snapshot must never land after a newer one")
    }

    // MARK: - (c) adopt when local absent

    func test_seed_adopts_cloud_copy_when_local_record_absent_rekeyed_to_current_user() async {
        var cloudRecord = record(
            userId: "legacy-device-id",
            total: 12,
            streak: 4,
            longest: 9,
            lastSession: Date(timeIntervalSince1970: 86_400 * 100)
        )
        cloudRecord.markProcessed(
            sourceId: "s1",
            receipt: SessionXPSourceReceipt(streakExtended: true, streakBroken: false, streakCountAfter: 4)
        )
        let cloudBonus = SessionXPBonusEntry(amount: 20, reason: "linked", date: Date(timeIntervalSince1970: 3_000))
        let spy = SpyDatabase()

        XCTAssertNil(service.storedRecord(userId: userId))
        SessionXPCloudBackup(database: spy).seedLocalStores(
            from: profile(streakBackup: SessionXPBackup(record: cloudRecord, bonuses: [cloudBonus])),
            userId: userId,
            service: service
        )

        let restored = service.record(userId: userId)
        XCTAssertEqual(restored.userId, userId, "the adopted record must be re-keyed to the signed-in id")
        XCTAssertEqual(restored.totalSessions, 12)
        XCTAssertEqual(restored.currentStreak, 4)
        XCTAssertEqual(restored.longestStreak, 9)
        XCTAssertEqual(restored.lastSessionDate, Date(timeIntervalSince1970: 86_400 * 100))
        XCTAssertEqual(Array(restored.processedSourceReceipts.keys), ["s1"], "receipts carry over so source-idempotency survives the restore")
        XCTAssertEqual(service.storedBonusLedger(userId: userId), [cloudBonus])
        let updateCount = await spy.updates.count
        XCTAssertEqual(updateCount, 0, "seeding must never fire a cloud write of its own")
    }

    func test_seed_is_noop_when_profile_carries_no_streak_backup() {
        service.restore(record(total: 5, streak: 3, longest: 5, lastSession: Date(timeIntervalSince1970: 1_000)))

        SessionXPCloudBackup(database: SpyDatabase()).seedLocalStores(
            from: profile(streakBackup: nil),
            userId: userId,
            service: service
        )

        XCTAssertEqual(service.record(userId: userId).totalSessions, 5)
        XCTAssertEqual(service.record(userId: userId).currentStreak, 3)
    }

    // MARK: - (d) never-regressing merge

    func test_seed_merges_never_regressing_when_both_exist() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let longAgo = cal.date(byAdding: .day, value: -60, to: today)!

        // Active local run: a 3-day streak ending today.
        service.restore(record(total: 5, streak: 3, longest: 5, lastSession: today))

        // Long-lapsed cloud copy holding the all-time bests.
        let cloud = record(total: 40, streak: 12, longest: 30, lastSession: longAgo)
        SessionXPCloudBackup(database: SpyDatabase()).seedLocalStores(
            from: profile(streakBackup: SessionXPBackup(record: cloud, bonuses: [])),
            userId: userId,
            service: service
        )

        let merged = service.record(userId: userId)
        XCTAssertEqual(merged.currentStreak, 3, "a lapsed cloud streak must not resurrect over the active local run")
        XCTAssertEqual(merged.longestStreak, 30, "the all-time best survives from the cloud copy")
        XCTAssertEqual(merged.totalSessions, 40, "totals keep the better of both sides")
        XCTAssertEqual(merged.lastSessionDate, today, "the newer run's last session stands")
    }

    // MARK: - (e) no write when nothing changes

    func test_seed_does_not_write_when_merge_changes_nothing() {
        let today = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let local = record(total: 40, streak: 3, longest: 30, lastSession: today)
        service.restore(local)
        defaults.recordedSetKeys.removeAll()

        SessionXPCloudBackup(database: SpyDatabase()).seedLocalStores(
            from: profile(streakBackup: SessionXPBackup(record: local, bonuses: [])),
            userId: userId,
            service: service
        )

        XCTAssertTrue(defaults.recordedSetKeys.isEmpty, "an unchanged merge must not rewrite the local record")
        XCTAssertEqual(service.record(userId: userId), local)
    }

    // MARK: - (f) bonus ledger adoption

    func test_bonuses_adopt_only_into_an_empty_local_ledger() {
        let cloudBonus = SessionXPBonusEntry(amount: 20, reason: "linked", date: Date(timeIntervalSince1970: 3_000))
        let cloud = SessionXPBackup(
            record: record(total: 1, streak: 1, longest: 1, lastSession: Date(timeIntervalSince1970: 1_000)),
            bonuses: [cloudBonus]
        )

        // Empty local ledger — adopt the cloud copy.
        SessionXPCloudBackup(database: SpyDatabase()).seedLocalStores(
            from: profile(streakBackup: cloud),
            userId: userId,
            service: service
        )
        XCTAssertEqual(service.storedBonusLedger(userId: userId), [cloudBonus])

        // Non-empty local ledger — local wins (display history, not currency).
        let localBonus = SessionXPBonusEntry(amount: 10, reason: "affinity", date: Date(timeIntervalSince1970: 4_000))
        service.restoreBonusLedger([localBonus], userId: userId)
        SessionXPCloudBackup(database: SpyDatabase()).seedLocalStores(
            from: profile(streakBackup: cloud),
            userId: userId,
            service: service
        )
        XCTAssertEqual(service.storedBonusLedger(userId: userId), [localBonus])
    }
}

// MARK: - Test doubles

/// Records every `update` so tests can assert the patch shape and that writes
/// land in call order. All other CRUD is inert.
private actor SpyDatabase: DatabaseServiceProtocol {
    struct Update {
        let fields: [String: Any]
        let collection: String
        let documentId: String
    }

    private(set) var updates: [Update] = []

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        updates.append(Update(fields: fields, collection: collection, documentId: documentId))
    }

    /// Polls until `count` updates have drained through the backup's ordered
    /// write chain (the chain is fire-and-forget, so tests can't await it
    /// directly).
    func waitForUpdates(count: Int, timeout: TimeInterval = 5) async -> [Update] {
        let deadline = Date().addingTimeInterval(timeout)
        while updates.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return updates
    }

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {}

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        throw SpyDatabaseError.unsupported
    }

    func delete(collection: String, documentId: String) async throws {}

    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any, orderBy: String?, descending: Bool, limit: Int?) async throws -> [T] {
        []
    }
}

private enum SpyDatabaseError: Error {
    case unsupported
}

/// UserDefaults that records object-write keys, so the no-op seed test can
/// assert "nothing changed" means "nothing was written" — not merely "the
/// same bytes were rewritten".
private final class WriteRecordingDefaults: UserDefaults {
    var recordedSetKeys: [String] = []

    override func set(_ value: Any?, forKey defaultName: String) {
        recordedSetKeys.append(defaultName)
        super.set(value, forKey: defaultName)
    }
}
