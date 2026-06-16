import XCTest
@testable import UNBOUND

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
}
