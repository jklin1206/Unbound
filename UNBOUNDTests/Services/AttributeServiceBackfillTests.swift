// UNBOUNDTests/Services/AttributeServiceBackfillTests.swift
//
// Reinstall-restore semantics of AttributeService.backfillFromExistingLogs.
//
// For a signed-in user who reinstalls, SyncEngine.restore brings the synced
// workout logs back, and RootView calls backfillFromExistingLogs AFTER that
// restore. The backfill is guarded by `store.load(userId:) == nil` and must
// return WITHOUT creating a profile when the log fetch comes back empty —
// otherwise a first post-reinstall workout would create a one-session profile
// that latches the backfill off forever.
import XCTest
@testable import UNBOUND

@MainActor
final class AttributeServiceBackfillTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// Fake exercise mapped 100% onto .power via StubAttributeCatalog
    /// (reused from AttributeServiceIngestTests).
    private static let exerciseName = "backfill_power_movement"

    // MARK: - Tests

    // (i) Empty logs → return without latching. A later call, once the
    // restored logs are visible, must still backfill.
    func testEmptyLogHistoryDoesNotLatchAndLaterCallStillBackfills() async throws {
        let suiteName = "AttributeServiceBackfillTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userId = "reinstall-empty-logs"
        let store = InMemoryAttributeProfileStore()
        let database = FakeWorkoutLogDatabase()
        let service = makeService(store: store, database: database, defaults: defaults)

        // Backfill fires before any logs are visible (e.g. restore raced it).
        await service.backfillFromExistingLogs(userId: userId)

        XCTAssertEqual(database.queryCount, 1)
        XCTAssertNil(store.load(userId: userId), "Empty history must not create (and latch) a profile")
        XCTAssertEqual(store.saveCount, 0)

        // The synced logs land; a later backfill call must still run because
        // nothing latched on the empty pass.
        database.logs = [makeLog(id: "w1", userId: userId, at: t0)]
        await service.backfillFromExistingLogs(userId: userId)

        let profile = try XCTUnwrap(store.load(userId: userId), "Backfill must run once logs are present")
        XCTAssertGreaterThan(profile.value(for: .power).xp, 0)
    }

    // (ii) Existing profile → no-op even with logs present.
    func testExistingProfileSkipsBackfillEvenWithLogsPresent() async throws {
        let suiteName = "AttributeServiceBackfillTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userId = "already-has-profile"
        let store = InMemoryAttributeProfileStore()
        var seeded = AttributeProfile.empty(userId: userId, at: t0)
        seeded.set(.power, AttributeValue(xp: 777, lastContributionAt: t0))
        store.profiles[userId] = seeded

        let database = FakeWorkoutLogDatabase()
        database.logs = [makeLog(id: "w1", userId: userId, at: t0)]
        let service = makeService(store: store, database: database, defaults: defaults)

        await service.backfillFromExistingLogs(userId: userId)

        let profile = try XCTUnwrap(store.load(userId: userId))
        XCTAssertEqual(profile.value(for: .power).xp, 777, accuracy: 0.001)
        XCTAssertEqual(store.saveCount, 0, "Backfill must not persist anything when a profile exists")
        XCTAssertEqual(database.queryCount, 0, "The profile guard runs before the log fetch")
    }

    // (iii) Happy path: N restored logs replay into a non-empty profile.
    func testBackfillReplaysFullLogHistoryIntoProfile() async throws {
        let suiteName = "AttributeServiceBackfillTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userId = "reinstall-happy-path"
        let store = InMemoryAttributeProfileStore()
        let database = FakeWorkoutLogDatabase()
        let logs = [
            makeLog(id: "w1", userId: userId, at: t0),
            makeLog(id: "w2", userId: userId, at: t0.addingTimeInterval(86_400)),
            makeLog(id: "w3", userId: userId, at: t0.addingTimeInterval(2 * 86_400))
        ]
        database.logs = logs

        let catalog = Self.catalog()
        let service = makeService(catalog: catalog, store: store, database: database, defaults: defaults)

        await service.backfillFromExistingLogs(userId: userId)

        let profile = try XCTUnwrap(store.load(userId: userId))
        XCTAssertEqual(profile.userId, userId)

        // Each identical log contributes the same session delta; the legacy
        // WorkoutLog path applies no catch-up scaling, so the total is exactly
        // 3x one session (anchored to the ingest functions, not hardcoded).
        let perLogPowerDelta = AttributeIngest.deltas(for: logs[0], catalog: catalog)[.power] ?? 0
        XCTAssertGreaterThan(perLogPowerDelta, 0)
        let expectedPowerXP = perLogPowerDelta * AttributeIngest.sessionDeltaXPScale * 3
        XCTAssertEqual(profile.value(for: .power).xp, expectedPowerXP, accuracy: 0.001)
        for key in AttributeKey.allCases where key != .power {
            XCTAssertEqual(profile.value(for: key).xp, 0, accuracy: 0.001,
                "Axis \(key) has no contribution and must stay at zero")
        }

        XCTAssertEqual(store.saveCount, 3, "One persist per replayed log")
        XCTAssertEqual(profile.computedAt, logs[2].completedAt)
    }

    // MARK: - Helpers

    private static func catalog() -> StubAttributeCatalog {
        StubAttributeCatalog(byName: [
            exerciseName: AttributeContribution(weights: [.power: 1.0])
        ])
    }

    private func makeService(
        catalog: AttributeCatalogProtocol? = nil,
        store: InMemoryAttributeProfileStore,
        database: FakeWorkoutLogDatabase,
        defaults: UserDefaults
    ) -> AttributeService {
        AttributeService(
            catalog: catalog ?? Self.catalog(),
            store: store,
            database: database,
            buildClassStore: BuildClassStore(defaults: defaults)
        )
    }

    /// One completed session of the power-mapped exercise. Kept small on
    /// purpose: the resulting levels stay well under the buildIdentity spread
    /// threshold, so ingest never escapes .balancedAthlete and never touches
    /// the BadgeService / WeeklyVowsService singletons.
    private func makeLog(id: String, userId: String, at date: Date) -> WorkoutLog {
        WorkoutLog(
            id: id, userId: userId, programId: "p1", dayNumber: 1,
            plannedWorkoutName: "Push",
            startedAt: date, completedAt: date.addingTimeInterval(45 * 60),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "\(id)-e1", exerciseName: Self.exerciseName,
                    plannedSets: 3, plannedReps: "5",
                    sets: [SetLog(id: "\(id)-s1", setNumber: 1, weightKg: 60, reps: 5, rpe: 8, isWarmup: false)],
                    skipped: false, notes: nil
                )
            ],
            overallNotes: nil, overallRPE: 8, durationMinutes: 45
        )
    }
}

// MARK: - Test doubles

/// In-memory AttributeProfileStoreProtocol so no test writes ever reach the
/// shared simulator UserDefaults (ShopInventoryStoreTests once failed from
/// exactly that pollution).
@MainActor
private final class InMemoryAttributeProfileStore: AttributeProfileStoreProtocol {
    var profiles: [String: AttributeProfile] = [:]
    var pinned: [String: [AttributeProfile]] = [:]
    private(set) var saveCount = 0

    func load(userId: String) -> AttributeProfile? {
        profiles[userId]
    }

    func save(_ profile: AttributeProfile) {
        profiles[profile.userId] = profile
        saveCount += 1
    }

    func pin(_ profile: AttributeProfile, toScan scanId: String) {
        pinned[profile.userId, default: []].append(profile)
    }

    func history(userId: String) -> [AttributeProfile] {
        pinned[userId] ?? []
    }
}

/// DatabaseServiceProtocol fake that serves WorkoutLogs for the backfill
/// query (VitalityRewardPolicyDatabase pattern: typed rows, no JSON layer).
private final class FakeWorkoutLogDatabase: DatabaseServiceProtocol, @unchecked Sendable {
    var logs: [WorkoutLog] = []
    private(set) var queryCount = 0

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {}

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        throw AppError.databaseReadFailed(underlying: NSError(domain: "FakeWorkoutLogDatabase", code: 404))
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {}

    func delete(collection: String, documentId: String) async throws {}

    func query<T: Codable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        orderBy: String?,
        descending: Bool,
        limit: Int?
    ) async throws -> [T] {
        queryCount += 1
        guard collection == "workoutLogs",
              field == "userId",
              let userId = value as? String,
              T.self == WorkoutLog.self else {
            return []
        }
        let filtered = logs.filter { $0.userId == userId }
        return filtered as? [T] ?? []
    }
}
