import XCTest
@testable import UNBOUND

/// Regression: an `OverallLevelReward` persisted before the vow-debt garnish
/// feature (no `xpWithheldToVowDebt` key) must still decode — otherwise existing
/// users' progress reads throw and reset them to fresh progress.
final class OverallLevelRewardDecodeTests: XCTestCase {
    func testDecodesRewardMissingVowDebtFieldAsZero() throws {
        let legacyJSON = """
        {
          "xpGained": 42.0, "noveltyMultiplier": 1.0,
          "previousXP": 100.0, "currentXP": 142.0,
          "previousLevel": 2, "currentLevel": 2,
          "previousProgressToNextLevel": 0.1, "currentProgressToNextLevel": 0.5
        }
        """.data(using: .utf8)!
        let reward = try JSONDecoder().decode(OverallLevelReward.self, from: legacyJSON)
        XCTAssertEqual(reward.xpGained, 42.0)
        XCTAssertEqual(reward.xpWithheldToVowDebt, 0)
    }

    func testRoundTripsVowDebtField() throws {
        var reward = OverallLevelReward(
            xpGained: 10, noveltyMultiplier: 1, previousXP: 0, currentXP: 10,
            previousLevel: 1, currentLevel: 1,
            previousProgressToNextLevel: 0, currentProgressToNextLevel: 0.2
        )
        reward.xpWithheldToVowDebt = 7
        let data = try JSONEncoder().encode(reward)
        let decoded = try JSONDecoder().decode(OverallLevelReward.self, from: data)
        XCTAssertEqual(decoded.xpWithheldToVowDebt, 7)
    }
}

@MainActor
final class OverallLevelServiceGarnishTests: XCTestCase {

    /// Stub ledger so the test doesn't depend on real vow state.
    final class StubLedger: VowDebtLedger {
        var outstanding: Int
        private(set) var consumedCalls: [Int] = []

        init(outstanding: Int) { self.outstanding = outstanding }

        func outstandingDebtXP(userId: String) -> Int { outstanding }

        func consumeDebt(upTo amount: Int, userId: String) -> Int {
            let c = min(outstanding, max(0, amount))
            outstanding -= c
            consumedCalls.append(c)
            return c
        }
    }

    func testEarnedTrainingXPIsWithheldAgainstDebt() async {
        let service = OverallLevelService.makeForTesting()
        let ledger = StubLedger(outstanding: 1_000_000) // swallow everything
        service.vowDebtLedger = ledger

        let reward = await service.ingest(
            rawAP: 500,
            noveltyMultiplier: 1.0,
            sourceLogId: "log-garnish-1",
            userId: "u-garnish",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            consumesVowDebt: true,
            database: MockDatabaseService()
        )

        XCTAssertEqual(reward.xpGained, 0, "bar must not move while debt swallows the earnings")
        XCTAssertEqual(reward.currentXP, reward.previousXP, "total XP never decreases")
        XCTAssertGreaterThan(reward.xpWithheldToVowDebt, 0)
        XCTAssertEqual(ledger.consumedCalls.count, 1)
    }

    func testNoDebtMeansFullCredit() async {
        let service = OverallLevelService.makeForTesting()
        service.vowDebtLedger = StubLedger(outstanding: 0)

        let reward = await service.ingest(
            rawAP: 500,
            noveltyMultiplier: 1.0,
            sourceLogId: "log-garnish-2",
            userId: "u-garnish-2",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            database: MockDatabaseService()
        )

        XCTAssertGreaterThan(reward.xpGained, 0)
        XCTAssertEqual(reward.xpWithheldToVowDebt, 0)
    }

    /// Database stub that fails every write — simulates a transient
    /// `overall_level_progress` persist failure.
    struct ThrowingOnCreateDatabase: DatabaseServiceProtocol, @unchecked Sendable {
        struct PersistFailure: Error {}
        func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
            throw PersistFailure()
        }
        func read<T: Codable>(collection: String, documentId: String) async throws -> T {
            throw PersistFailure()
        }
        func update(_ fields: [String: Any], collection: String, documentId: String) async throws {}
        func delete(collection: String, documentId: String) async throws {}
        func query<T: Codable>(collection: String, field: String, isEqualTo value: Any, orderBy: String?, descending: Bool, limit: Int?) async throws -> [T] { [] }
    }

    /// Regression: a failed XP persist must leave vow debt untouched. Consuming
    /// debt before the `overall_level_progress` write is durable means a
    /// transient write failure forgives the debt for free — the XP event is
    /// never banked, and on retry less/no debt is seen.
    func testDebtIsNotConsumedWhenPersistFails() async {
        let service = OverallLevelService.makeForTesting()
        let ledger = StubLedger(outstanding: 5_000)
        service.vowDebtLedger = ledger

        do {
            _ = try await service.ingestStrict(
                rawAP: 500,
                noveltyMultiplier: 1.0,
                sourceLogId: "log-persist-fail",
                userId: "u-persist-fail",
                at: Date(timeIntervalSince1970: 1_700_000_000),
                consumesVowDebt: true,
                database: ThrowingOnCreateDatabase()
            )
            XCTFail("ingestStrict must rethrow the persist failure")
        } catch {
            // expected
        }

        XCTAssertEqual(ledger.outstanding, 5_000, "a failed XP write must leave vow debt untouched")
        XCTAssertTrue(ledger.consumedCalls.isEmpty, "debt must not be consumed before the XP write is durable")
    }

    func testNonTrainingXPDoesNotConsumeDebt() async {
        let service = OverallLevelService.makeForTesting()
        let ledger = StubLedger(outstanding: 1_000_000)
        service.vowDebtLedger = ledger

        // Default consumesVowDebt:false (e.g. daily photo/scan XP) must NOT pay
        // down vow debt — that's reserved for training XP (spec §5).
        let reward = await service.ingest(
            rawAP: 500,
            noveltyMultiplier: 1.0,
            sourceLogId: "log-photo-1",
            userId: "u-photo",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            database: MockDatabaseService()
        )

        XCTAssertGreaterThan(reward.xpGained, 0, "non-training XP credits in full")
        XCTAssertEqual(reward.xpWithheldToVowDebt, 0)
        XCTAssertEqual(ledger.consumedCalls.count, 0, "debt ledger untouched by non-training XP")
    }
}
