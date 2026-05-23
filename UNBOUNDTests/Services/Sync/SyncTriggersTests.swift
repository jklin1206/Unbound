import XCTest
@testable import UNBOUND

@MainActor
final class SyncTriggersTests: XCTestCase {
    func test_debounced_enqueue_notification_calls_flush_once() async {
        let exp = expectation(description: "flush")
        var calls = 0
        let t = SyncTriggers(debounce: 0.1) { calls += 1; exp.fulfill() }
        t.start()
        NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
        NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
        await fulfillment(of: [exp], timeout: 2)
        XCTAssertEqual(calls, 1)
        t.stop()
    }
}
