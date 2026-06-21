import XCTest
@testable import UNBOUND

/// Live, end-to-end proof that a streak survives the anonymous → signed-in
/// identity transition through the REAL wiring: the production
/// `SessionXPService` writes the streak, and the real
/// `UserDataMigrationCoordinator` (default production stores, real
/// `UserDefaults`) carries it onto the signed-in id.
///
/// Mocked unit tests cannot catch a key or codec mismatch between the service
/// (the writer) and the migration store (the re-keyer) — this integration test
/// is what locks that contract, which is exactly where the streak was getting
/// orphaned on sign-in.
@MainActor
final class SessionXPMigrationIntegrationTests: XCTestCase {
    private let anonId = "anon-" + UUID().uuidString
    private let supabaseId = UUID().uuidString
    private let service = SessionXPService.shared
    private let defaults = UserDefaults.standard

    override func tearDown() {
        defaults.removeObject(forKey: SessionXPService.storageKey(for: anonId))
        defaults.removeObject(forKey: SessionXPService.storageKey(for: supabaseId))
        defaults.removeObject(forKey: "migrationCompleted.\(anonId)->\(supabaseId)")
        super.tearDown()
    }

    func test_streak_survives_signin_migration_end_to_end() async {
        let cal = Calendar.current
        let day0 = cal.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let day1 = cal.date(byAdding: .day, value: 1, to: day0)!
        let day2 = cal.date(byAdding: .day, value: 2, to: day0)!

        // Train three consecutive days as an anonymous (pre-auth) user.
        _ = await service.recordSession(userId: anonId, at: day0, sourceId: "s0")
        _ = await service.recordSession(userId: anonId, at: day1, sourceId: "s1")
        let preDelta = await service.recordSession(userId: anonId, at: day2, sourceId: "s2")
        XCTAssertEqual(preDelta.updated.currentStreak, 3, "Three consecutive days should build a 3-day streak")
        XCTAssertEqual(service.record(userId: anonId).currentStreak, 3)

        // A freshly signed-in identity starts empty — this is the "lost place"
        // the user was hitting before the migration carried the streak across.
        XCTAssertEqual(service.record(userId: supabaseId).currentStreak, 0)

        // Run the REAL migration (default production stores, real UserDefaults).
        let summary = await UserDataMigrationCoordinator().migrate(
            legacyUserId: anonId,
            supabaseUserId: supabaseId
        )
        XCTAssertEqual(summary.sessionXP.scanned, 1)
        XCTAssertEqual(summary.sessionXP.localWrites, 1)
        XCTAssertEqual(summary.sessionXP.failures, 0)

        // The signed-in identity now reads back the carried-over streak.
        let migrated = service.record(userId: supabaseId)
        XCTAssertEqual(migrated.currentStreak, 3, "Streak must survive sign-in")
        XCTAssertEqual(migrated.longestStreak, 3)
        XCTAssertEqual(migrated.totalSessions, 3)
    }

    func test_streak_continues_after_signin_without_breaking() async {
        let cal = Calendar.current
        let day0 = cal.startOfDay(for: Date(timeIntervalSince1970: 1_810_000_000))
        let day1 = cal.date(byAdding: .day, value: 1, to: day0)!
        let day2 = cal.date(byAdding: .day, value: 2, to: day0)!

        // Two days anonymous, then migrate, then train the next day signed-in.
        _ = await service.recordSession(userId: anonId, at: day0, sourceId: "s0")
        _ = await service.recordSession(userId: anonId, at: day1, sourceId: "s1")

        _ = await UserDataMigrationCoordinator().migrate(
            legacyUserId: anonId,
            supabaseUserId: supabaseId
        )
        XCTAssertEqual(service.record(userId: supabaseId).currentStreak, 2)

        // The next signed-in session extends rather than restarts the streak —
        // proving lastSessionDate carried over, not just the count.
        let post = await service.recordSession(userId: supabaseId, at: day2, sourceId: "s2")
        XCTAssertEqual(post.updated.currentStreak, 3, "Signed-in session should extend the migrated streak")
        XCTAssertTrue(post.streakExtended)
        XCTAssertFalse(post.streakBroken)
    }
}
