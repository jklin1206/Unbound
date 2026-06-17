import XCTest
@testable import UNBOUND

@MainActor
final class OverallLevelServiceDockTests: XCTestCase {

    private func seededService(userId: String, db: MockDatabaseService) async -> OverallLevelService {
        let service = OverallLevelService.makeForTesting()
        _ = await service.ingest(
            rawAP: 5000,
            noveltyMultiplier: 1.0,
            sourceLogId: "seed",
            userId: userId,
            at: Date(timeIntervalSince1970: 1_700_000_000),
            database: db
        )
        return service
    }

    /// Breaking a vow docks the stake straight off the bar.
    func testDockReducesXP() async {
        let db = MockDatabaseService()
        let userId = "u-dock"
        let service = await seededService(userId: userId, db: db)
        let before = service.cachedTotalXP(userId: userId) ?? 0
        XCTAssertGreaterThan(before, 100)

        let reward = await service.dockXP(
            amount: 100,
            sourceId: "miss-1",
            userId: userId,
            at: Date(timeIntervalSince1970: 1_700_000_100),
            database: db
        )
        XCTAssertEqual(reward.currentXP, before - 100, accuracy: 0.001)
        XCTAssertEqual(reward.xpGained, -100, accuracy: 0.001)
    }

    /// The dock is idempotent: the same sourceId never docks twice.
    func testDockIsIdempotent() async {
        let db = MockDatabaseService()
        let userId = "u-dock-idem"
        let service = await seededService(userId: userId, db: db)

        _ = await service.dockXP(amount: 100, sourceId: "miss-1", userId: userId, at: Date(timeIntervalSince1970: 1_700_000_100), database: db)
        let afterFirst = service.cachedTotalXP(userId: userId) ?? 0
        _ = await service.dockXP(amount: 100, sourceId: "miss-1", userId: userId, at: Date(timeIntervalSince1970: 1_700_000_200), database: db)
        let afterSecond = service.cachedTotalXP(userId: userId) ?? 0

        XCTAssertEqual(afterFirst, afterSecond, "same sourceId must not dock twice")
    }

    /// A dock never drops the user below their current level floor (never de-levels).
    func testDockNeverDeLevels() async {
        let db = MockDatabaseService()
        let userId = "u-dock-floor"
        let service = await seededService(userId: userId, db: db)
        let level = OverallLevelCurve.level(forXP: service.cachedTotalXP(userId: userId) ?? 0)

        let reward = await service.dockXP(
            amount: 1_000_000,
            sourceId: "miss-floor",
            userId: userId,
            at: Date(timeIntervalSince1970: 1_700_000_100),
            database: db
        )
        XCTAssertEqual(reward.currentLevel, level, "a dock must not de-level")
        XCTAssertGreaterThanOrEqual(reward.currentXP, OverallLevelCurve.xpRequired(forLevel: level))
    }
}
