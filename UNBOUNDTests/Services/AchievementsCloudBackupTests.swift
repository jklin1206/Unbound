// UNBOUNDTests/Services/AchievementsCloudBackupTests.swift
import XCTest
@testable import UNBOUND

/// Covers the cloud backup + restore seam for titles / kept vows / badges:
/// the durable-subset users-doc patch fired through the store's save choke
/// point, the union merges that can never drop a locally-earned unlock, and
/// ISO-8601 wire fidelity against the plain-encoder local store.
@MainActor
final class AchievementsCloudBackupTests: XCTestCase {

    // MARK: - Recording database

    /// In-memory `DatabaseServiceProtocol` that records every write in arrival
    /// order. Only `update` matters here — the backup never creates docs.
    private final class RecordingDatabase: DatabaseServiceProtocol, @unchecked Sendable {
        struct Update { let collection: String; let documentId: String; let fields: [String: Any] }

        private let lock = NSLock()
        private var recordedUpdates: [Update] = []
        private var onWrite: (() -> Void)?

        var updates: [Update] { lock.lock(); defer { lock.unlock() }; return recordedUpdates }

        func configure(onWrite: (() -> Void)?) {
            lock.lock(); defer { lock.unlock() }
            self.onWrite = onWrite
        }

        func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {}

        func read<T: Codable>(collection: String, documentId: String) async throws -> T {
            throw NSError(domain: "RecordingDatabase", code: 404)
        }

        func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
            lock.lock()
            recordedUpdates.append(Update(collection: collection, documentId: documentId, fields: fields))
            let callback = onWrite
            lock.unlock()
            callback?()
        }

        func delete(collection: String, documentId: String) async throws {}

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

    // MARK: - Setup

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var db: RecordingDatabase!
    private var backup: AchievementsCloudBackup!
    /// Production wiring under test: the store's save fires the backup seam.
    private var store: WeeklyVowsStore!

    override func setUp() {
        super.setUp()
        suiteName = "AchievementsCloudBackupTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        db = RecordingDatabase()
        backup = AchievementsCloudBackup(database: db, defaults: defaults)
        store = WeeklyVowsStore(defaults: defaults, backup: backup)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Fixtures (whole-second dates so ISO-8601 round-trips exactly)

    private let ephemeralKeys: Set<String> = [
        "currentWeekStart", "currentWeekCards", "currentTrial",
        "skippedCurrentWeek", "fuelAnchorsByVowId", "lastVowLogByVowId"
    ]

    private func card(id: String = "weekly-vow-test-engine-medium", lane: VowLane = .engine) -> WeeklyVowCard {
        WeeklyVowCard(
            id: id,
            lane: lane,
            bet: .medium,
            displayName: "Test Vow",
            blurb: "A bound vow.",
            target: VowTarget(count: 3, noun: "session")
        )
    }

    private func keptVow(vowId: String, lane: VowLane = .engine, at epoch: TimeInterval) -> KeptVow {
        KeptVow(vowId: vowId, name: "Kept \(vowId)", lane: lane, completedAt: Date(timeIntervalSince1970: epoch))
    }

    private func completionEntry(logId: String, at epoch: TimeInterval) -> WeeklyVowCompletionLedgerEntry {
        WeeklyVowCompletionLedgerEntry(
            vowId: "weekly-vow-test-engine-medium",
            performanceLogId: logId,
            completedAt: Date(timeIntervalSince1970: epoch),
            bonus: WeeklyVowCompletionBonus(
                overallLevelXP: 100,
                badgeProgress: WeeklyVowProgressDescriptor(title: "Cardio I", current: 1, target: 5)
            )
        )
    }

    private func penaltyEntry(vowId: String, weekStart: TimeInterval, missedAt: TimeInterval) -> WeeklyVowPenaltyLedgerEntry {
        WeeklyVowPenaltyLedgerEntry(
            vowId: vowId,
            lane: .engine,
            weekStart: Date(timeIntervalSince1970: weekStart),
            missedAt: Date(timeIntervalSince1970: missedAt),
            penaltyXP: 250
        )
    }

    /// A state carrying BOTH durable fields and populated weekly-ephemeral
    /// fields, so payload/restore tests can prove the ephemeral ones never travel.
    private func fullState() -> WeeklyVowsState {
        let weekCard = card()
        var state = WeeklyVowsState.empty
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [weekCard]
        state.currentTrial = WeeklyVow(
            id: weekCard.id,
            userId: "u1",
            weekStart: state.currentWeekStart!,
            chosenCard: weekCard,
            capstoneState: .pending,
            completedAt: nil
        )
        state.skippedCurrentWeek = false
        state.fuelAnchorsByVowId = [weekCard.id: 2]
        state.lastVowLogByVowId = [weekCard.id: Date(timeIntervalSince1970: 1_700_100_000)]
        state.unlockedTitles = [.rank(.novice), .badge("streak_3")]
        state.equippedTitle = .rank(.novice)
        state.keptVows = [keptVow(vowId: "vow-a", at: 1_700_200_000)]
        state.completionsByLane = [.engine: 2, .recovery: 1]
        state.weeklyVowCompletionLedger = [completionEntry(logId: "perf-1", at: 1_700_200_000)]
        state.weeklyVowPenaltyLedger = [penaltyEntry(vowId: "vow-p", weekStart: 1_699_000_000, missedAt: 1_699_500_000)]
        return state
    }

    private func serverBackup(
        unlockedTitles: [TitleID] = [],
        equippedTitle: TitleID? = nil,
        keptVows: [KeptVow] = [],
        completionsByLane: [VowLane: Int] = [:],
        completionLedger: [WeeklyVowCompletionLedgerEntry] = [],
        penaltyLedger: [WeeklyVowPenaltyLedgerEntry] = [],
        badges: [String: Date] = [:]
    ) -> AchievementsBackup {
        AchievementsBackup(
            unlockedTitles: unlockedTitles,
            equippedTitle: equippedTitle,
            keptVows: keptVows,
            completionsByLane: completionsByLane,
            weeklyVowCompletionLedger: completionLedger,
            weeklyVowPenaltyLedger: penaltyLedger,
            badges: badges
        )
    }

    private func decodePayload(_ fields: [String: Any]) throws -> AchievementsBackup {
        let payload = try XCTUnwrap(fields["achievementsBackup"])
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AchievementsBackup.self, from: data)
    }

    private func awaitWrites(_ count: Int, during body: () -> Void) async {
        let landed = expectation(description: "patches landed")
        landed.expectedFulfillmentCount = count
        db.configure(onWrite: { landed.fulfill() })
        body()
        await fulfillment(of: [landed], timeout: 3)
        db.configure(onWrite: nil)
    }

    // MARK: - (a) backup captures ONLY the durable fields + badges

    func test_backup_patches_users_doc_with_durable_fields_only() async throws {
        BadgeUnlockStore.save(
            ["streak_3": Date(timeIntervalSince1970: 1_700_300_000)],
            userId: "u1",
            defaults: defaults
        )
        let state = fullState()

        await awaitWrites(1) { store.save(state, userId: "u1") }

        XCTAssertEqual(db.updates.count, 1)
        let update = try XCTUnwrap(db.updates.first)
        XCTAssertEqual(update.collection, "users")
        XCTAssertEqual(update.documentId, "u1")
        XCTAssertEqual(
            update.fields["id"] as? String, "u1",
            "id must travel in the payload for the sync_merge_row ownership guard"
        )

        // Ephemeral week state must be absent from the wire payload entirely.
        let payloadDict = try XCTUnwrap(update.fields["achievementsBackup"] as? [String: Any])
        XCTAssertTrue(
            self.ephemeralKeys.isDisjoint(with: payloadDict.keys),
            "weekly-ephemeral fields leaked onto the wire: \(self.ephemeralKeys.intersection(payloadDict.keys))"
        )

        let decoded = try decodePayload(update.fields)
        XCTAssertEqual(decoded.unlockedTitles, state.unlockedTitles)
        XCTAssertEqual(decoded.equippedTitle, state.equippedTitle)
        XCTAssertEqual(decoded.keptVows, state.keptVows)
        XCTAssertEqual(decoded.completionsByLane, state.completionsByLane)
        XCTAssertEqual(decoded.weeklyVowCompletionLedger, state.weeklyVowCompletionLedger)
        XCTAssertEqual(decoded.weeklyVowPenaltyLedger, state.weeklyVowPenaltyLedger)
        XCTAssertEqual(decoded.badges, ["streak_3": Date(timeIntervalSince1970: 1_700_300_000)])
    }

    // MARK: - (b) title union + keptVows union-by-id + per-lane max

    func test_seed_unions_titles_and_keptVows_and_takes_per_lane_max() {
        var local = WeeklyVowsState.empty
        local.unlockedTitles = [.rank(.novice), .badge("streak_3")]
        local.keptVows = [keptVow(vowId: "vow-a", at: 1_700_200_000)]
        local.completionsByLane = [.recovery: 3]
        store.save(local, userId: "u1")

        let server = serverBackup(
            unlockedTitles: [.rank(.novice), .shop("chalkGhost")],
            // Same id as local "vow-a" (vowId + whole-second epoch) plus a
            // server-only vow that must survive.
            keptVows: [keptVow(vowId: "vow-a", at: 1_700_200_000), keptVow(vowId: "vow-b", at: 1_700_100_000)],
            completionsByLane: [.recovery: 1, .engine: 2]
        )

        backup.seedLocalStores(from: server, userId: "u1", vowsStore: store, badgeDefaults: defaults)

        let merged = store.load(userId: "u1")
        XCTAssertEqual(
            merged.unlockedTitles,
            [.rank(.novice), .badge("streak_3"), .shop("chalkGhost")],
            "union keeps local order and appends server-only titles"
        )
        XCTAssertEqual(
            merged.keptVows.map(\.vowId), ["vow-b", "vow-a"],
            "union by id, oldest-first; the shared id must not duplicate"
        )
        XCTAssertEqual(merged.completionsByLane, [.recovery: 3, .engine: 2], "per-lane max")
    }

    // MARK: - (c) badges union with earliest date; cloud-only badge survives

    func test_seed_unions_badges_keeping_earliest_date_and_restores_nonrecomputable_badge() {
        BadgeUnlockStore.save(
            ["streak_3": Date(timeIntervalSince1970: 2_000)],
            userId: "u1",
            defaults: defaults
        )
        // streak_100 unlocked at a transient streak peak — only the cloud has it.
        let server = serverBackup(badges: [
            "streak_3": Date(timeIntervalSince1970: 1_000),
            "streak_100": Date(timeIntervalSince1970: 1_500)
        ])

        backup.seedLocalStores(from: server, userId: "u1", vowsStore: store, badgeDefaults: defaults)

        let merged = BadgeUnlockStore.load(userId: "u1", defaults: defaults)
        XCTAssertEqual(
            merged,
            [
                "streak_3": Date(timeIntervalSince1970: 1_000),
                "streak_100": Date(timeIntervalSince1970: 1_500)
            ],
            "earliest unlockedAt wins per badge; the non-recomputable badge survives restore"
        )
    }

    // MARK: - (d) equippedTitle adopts only when local nil and owned

    func test_seed_adopts_server_equipped_title_only_when_local_nil_and_owned() {
        // Local nil + server-equipped title owned after union: adopt.
        var local = WeeklyVowsState.empty
        store.save(local, userId: "u1")
        backup.seedLocalStores(
            from: serverBackup(unlockedTitles: [.shop("chalkGhost")], equippedTitle: .shop("chalkGhost")),
            userId: "u1", vowsStore: store, badgeDefaults: defaults
        )
        XCTAssertEqual(store.load(userId: "u1").equippedTitle, .shop("chalkGhost"))

        // Local nil + server pick NOT owned after union: stay nil (equip guard parity).
        store.save(.empty, userId: "u2")
        backup.seedLocalStores(
            from: serverBackup(equippedTitle: .shop("goldSignal")),
            userId: "u2", vowsStore: store, badgeDefaults: defaults
        )
        XCTAssertNil(store.load(userId: "u2").equippedTitle)

        // Local pick set: local always wins.
        local = WeeklyVowsState.empty
        local.unlockedTitles = [.rank(.novice)]
        local.equippedTitle = .rank(.novice)
        store.save(local, userId: "u3")
        backup.seedLocalStores(
            from: serverBackup(unlockedTitles: [.shop("chalkGhost")], equippedTitle: .shop("chalkGhost")),
            userId: "u3", vowsStore: store, badgeDefaults: defaults
        )
        XCTAssertEqual(store.load(userId: "u3").equippedTitle, .rank(.novice))
    }

    // MARK: - (e) restore leaves current-week fields untouched

    func test_seed_never_touches_weekly_ephemeral_fields() {
        let local = fullState()
        store.save(local, userId: "u1")

        backup.seedLocalStores(
            from: serverBackup(unlockedTitles: [.shop("nightShift")]),
            userId: "u1", vowsStore: store, badgeDefaults: defaults
        )

        let merged = store.load(userId: "u1")
        XCTAssertEqual(merged.currentWeekStart, local.currentWeekStart)
        XCTAssertEqual(merged.currentWeekCards, local.currentWeekCards)
        XCTAssertEqual(merged.currentTrial, local.currentTrial)
        XCTAssertEqual(merged.skippedCurrentWeek, local.skippedCurrentWeek)
        XCTAssertEqual(merged.fuelAnchorsByVowId, local.fuelAnchorsByVowId)
        XCTAssertEqual(merged.lastVowLogByVowId, local.lastVowLogByVowId)
        XCTAssertTrue(merged.unlockedTitles.contains(.shop("nightShift")), "durable merge still applied")
    }

    // MARK: - (f) ledger unions keep their idempotency bite

    func test_seed_unions_ledgers_so_restored_receipts_cannot_recredit() {
        var local = WeeklyVowsState.empty
        local.weeklyVowCompletionLedger = [completionEntry(logId: "perf-1", at: 1_700_200_000)]
        store.save(local, userId: "u1")

        let vowCard = card(id: "weekly-vow-test-broken")
        let weekStart: TimeInterval = 1_699_000_000
        let server = serverBackup(
            // "perf-1" collides with local (must not duplicate); "perf-0" is a
            // cloud-only receipt that must be restored.
            completionLedger: [
                completionEntry(logId: "perf-1", at: 1_700_200_000),
                completionEntry(logId: "perf-0", at: 1_700_000_000)
            ],
            penaltyLedger: [penaltyEntry(vowId: vowCard.id, weekStart: weekStart, missedAt: weekStart + 86_400)]
        )

        backup.seedLocalStores(from: server, userId: "u1", vowsStore: store, badgeDefaults: defaults)

        var merged = store.load(userId: "u1")
        XCTAssertEqual(
            merged.weeklyVowCompletionLedger.map(\.performanceLogId), ["perf-0", "perf-1"],
            "union by id, oldest-first, no duplicate for the shared receipt"
        )

        // The restored penalty entry must stop the same vow+week from being
        // charged again after reinstall.
        let vow = WeeklyVow(
            id: vowCard.id,
            userId: "u1",
            weekStart: Date(timeIntervalSince1970: weekStart),
            chosenCard: vowCard,
            capstoneState: .pending,
            completedAt: nil
        )
        let owed = WeeklyVowPenaltyCatalog.recordBreakIfNeeded(
            for: vow,
            missedAt: Date(timeIntervalSince1970: weekStart + 172_800),
            state: &merged
        )
        XCTAssertEqual(owed, 0, "a restored break receipt must not re-dock the stake")
        XCTAssertEqual(merged.weeklyVowPenaltyLedger.count, 1)
    }

    // MARK: - (g) redundant identical backup skips the patch

    func test_identical_and_ephemeral_only_saves_skip_the_patch() async throws {
        var state = WeeklyVowsState.empty
        state.unlockedTitles = [.rank(.novice)]

        await awaitWrites(1) { store.save(state, userId: "u1") }

        // Identical durable snapshot + an ephemeral-only change: both must be
        // skipped. The chain is FIFO, so if either had patched it would land
        // before the third write below.
        store.save(state, userId: "u1")
        var rolled = state
        rolled.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        rolled.skippedCurrentWeek = true
        store.save(rolled, userId: "u1")

        var advanced = rolled
        advanced.unlockedTitles.append(.badge("streak_7"))
        await awaitWrites(1) { store.save(advanced, userId: "u1") }

        XCTAssertEqual(db.updates.count, 2, "identical/ephemeral-only snapshots must not patch")
        let titles = try db.updates.map { try decodePayload($0.fields).unlockedTitles }
        XCTAssertEqual(titles, [[.rank(.novice)], [.rank(.novice), .badge("streak_7")]])
    }

    // MARK: - (h) wire round-trip date fidelity

    func test_dates_do_not_shift_between_plain_encoder_store_and_iso8601_wire() async throws {
        BadgeUnlockStore.save(
            ["first_muscle_up": Date(timeIntervalSince1970: 1_700_400_000)],
            userId: "u1",
            defaults: defaults
        )
        let state = fullState()
        await awaitWrites(1) { store.save(state, userId: "u1") }

        // Decode the wire payload exactly as the server round-trip would.
        let wire = try decodePayload(try XCTUnwrap(db.updates.first).fields)

        // Restore onto a fresh install (empty defaults, plain-encoder store).
        let freshSuite = "AchievementsCloudBackupTests-fresh-\(UUID().uuidString)"
        let freshDefaults = UserDefaults(suiteName: freshSuite)!
        defer { freshDefaults.removePersistentDomain(forName: freshSuite) }
        let freshStore = WeeklyVowsStore(defaults: freshDefaults)

        backup.seedLocalStores(from: wire, userId: "u1", vowsStore: freshStore, badgeDefaults: freshDefaults)

        let restored = freshStore.load(userId: "u1")
        XCTAssertEqual(restored.keptVows, state.keptVows, "kept-vow dates (and their derived ids) must not shift")
        XCTAssertEqual(restored.keptVows.map(\.id), state.keptVows.map(\.id))
        XCTAssertEqual(restored.weeklyVowCompletionLedger, state.weeklyVowCompletionLedger)
        XCTAssertEqual(restored.weeklyVowPenaltyLedger, state.weeklyVowPenaltyLedger)
        XCTAssertEqual(restored.completionsByLane, state.completionsByLane)
        XCTAssertEqual(
            BadgeUnlockStore.load(userId: "u1", defaults: freshDefaults),
            ["first_muscle_up": Date(timeIntervalSince1970: 1_700_400_000)]
        )
    }
}
