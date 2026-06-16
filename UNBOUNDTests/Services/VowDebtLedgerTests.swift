import XCTest
@testable import UNBOUND

@MainActor
final class VowDebtLedgerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: WeeklyVowsStore!
    private var ledger: LiveVowDebtLedger!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "vow-debt-\(UUID().uuidString)")
        store = WeeklyVowsStore(defaults: defaults)
        ledger = LiveVowDebtLedger(store: store)
    }

    func testOutstandingDebtReadsState() {
        var state = store.load(userId: "u")
        state.pendingVowDebtXP = 300
        store.save(state, userId: "u")
        XCTAssertEqual(ledger.outstandingDebtXP(userId: "u"), 300)
    }

    func testConsumePartialLeavesRemainder() {
        var state = store.load(userId: "u")
        state.pendingVowDebtXP = 300
        store.save(state, userId: "u")
        let consumed = ledger.consumeDebt(upTo: 120, userId: "u")
        XCTAssertEqual(consumed, 120)
        XCTAssertEqual(store.load(userId: "u").pendingVowDebtXP, 180)
    }

    func testConsumeNeverExceedsOutstanding() {
        var state = store.load(userId: "u")
        state.pendingVowDebtXP = 80
        store.save(state, userId: "u")
        let consumed = ledger.consumeDebt(upTo: 500, userId: "u")
        XCTAssertEqual(consumed, 80)
        XCTAssertEqual(store.load(userId: "u").pendingVowDebtXP, 0)
    }

    func testConsumeZeroWhenNoDebt() {
        XCTAssertEqual(ledger.consumeDebt(upTo: 200, userId: "u"), 0)
    }
}
