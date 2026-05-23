import XCTest
@testable import UNBOUND

final class SpyRestNotifier: RestNotifying, @unchecked Sendable {
    var authRequested = 0
    var scheduled: [TimeInterval] = []
    var cancels = 0
    func requestAuthIfNeeded() async { authRequested += 1 }
    func schedule(after seconds: TimeInterval, title: String, body: String) { scheduled.append(seconds) }
    func cancelPending() { cancels += 1 }
}

@MainActor
final class RestTimerModelTests: XCTestCase {
    func test_start_schedulesNotification_andCountsDown() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 90, nextLabel: "Bench")
        XCTAssertEqual(m.remaining, 90)
        XCTAssertTrue(m.isActive)
        XCTAssertEqual(spy.scheduled, [90])
        m.tick(); m.tick()
        XCTAssertEqual(m.remaining, 88)
    }
    func test_addThirty_extendsAndReschedules() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 60, nextLabel: "Row")
        m.addThirty()
        XCTAssertEqual(m.remaining, 90)
        XCTAssertEqual(spy.scheduled.last, 90)
    }
    func test_dismiss_hidesUIButKeepsRunning() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 30, nextLabel: "X")
        m.dismiss()
        XCTAssertFalse(m.isVisible)
        XCTAssertTrue(m.isActive)
        XCTAssertEqual(spy.cancels, 0)
    }
    func test_reachingZero_fires_andClears_andCancelsPending() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        var fired = false
        m.onElapsed = { fired = true }
        m.start(seconds: 2, nextLabel: "X")
        m.tick(); m.tick()
        XCTAssertTrue(fired)
        XCTAssertFalse(m.isActive)
        XCTAssertFalse(m.isVisible)
        XCTAssertEqual(spy.cancels, 1)
    }
    func test_startingNewRest_cancelsPreviousPending() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 90, nextLabel: "A")
        m.start(seconds: 60, nextLabel: "B")
        XCTAssertEqual(spy.cancels, 1)
        XCTAssertEqual(spy.scheduled, [90, 60])
        XCTAssertEqual(m.remaining, 60)
    }
}
