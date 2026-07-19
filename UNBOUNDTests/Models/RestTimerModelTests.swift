import XCTest
@testable import UNBOUND

final class SpyRestNotifier: RestNotifying, @unchecked Sendable {
    var authRequested = 0
    var scheduled: [TimeInterval] = []
    var scheduledCopy: [(title: String, body: String)] = []
    var cancels = 0
    func requestAuthIfNeeded() async { authRequested += 1 }
    func schedule(after seconds: TimeInterval, title: String, body: String) {
        scheduled.append(seconds)
        scheduledCopy.append((title, body))
    }
    func cancelPending() { cancels += 1 }
}

@MainActor
final class RestTimerModelTests: XCTestCase {
    func test_start_schedulesNotifier_andCountsDown() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        let start = Date(timeIntervalSince1970: 1_000)
        m.start(seconds: 90, nextLabel: "Bench", now: start)
        XCTAssertEqual(m.remaining, 90)
        XCTAssertTrue(m.isActive)
        XCTAssertEqual(spy.scheduled, [90])
        XCTAssertEqual(spy.scheduledCopy.first?.title, "[ SYSTEM ] RECOVERY COMPLETE")
        XCTAssertEqual(spy.scheduledCopy.first?.body, "Next set: Bench.")
        m.tick(now: start.addingTimeInterval(2))
        XCTAssertEqual(m.remaining, 88)
    }

    func test_tick_usesElapsedWallClockTime() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        let start = Date(timeIntervalSince1970: 2_000)
        m.start(seconds: 90, nextLabel: "Bench", now: start)
        m.tick(now: start.addingTimeInterval(75))
        XCTAssertEqual(m.remaining, 15)
    }

    func test_addThirty_extendsAndReschedules() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        let start = Date(timeIntervalSince1970: 3_000)
        m.start(seconds: 60, nextLabel: "Row", now: start)
        m.addThirty(now: start)
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
        let start = Date(timeIntervalSince1970: 4_000)
        m.start(seconds: 2, nextLabel: "X", now: start)
        m.tick(now: start.addingTimeInterval(2))
        XCTAssertTrue(fired)
        XCTAssertFalse(m.isActive)
        XCTAssertFalse(m.isVisible)
        XCTAssertEqual(spy.cancels, 1)
    }

    func test_startingNewRest_cancelsPreviousPending() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        let start = Date(timeIntervalSince1970: 5_000)
        m.start(seconds: 90, nextLabel: "A", now: start)
        m.start(seconds: 60, nextLabel: "B", now: start)
        XCTAssertEqual(spy.cancels, 1)
        XCTAssertEqual(spy.scheduled, [90, 60])
        XCTAssertEqual(m.remaining, 60)
    }

    func test_persistence_restoresActiveTimer() {
        let key = "RestTimerModelTests.persistence"
        UserDefaults.standard.removeObject(forKey: key)
        let spy = SpyRestNotifier()
        let start = Date()
        let original = RestTimerModel(notifier: spy, persistenceKey: key)
        original.start(seconds: 90, nextLabel: "Pullup", now: start)
        original.dismiss()

        let restored = RestTimerModel(notifier: spy, persistenceKey: key)
        restored.tick(now: start.addingTimeInterval(30))
        XCTAssertTrue(restored.isActive)
        XCTAssertFalse(restored.isVisible)
        XCTAssertEqual(restored.remaining, 60)
        UserDefaults.standard.removeObject(forKey: key)
    }
}
