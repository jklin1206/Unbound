// UNBOUNDTests/Services/Auth/AuthDeferralStoreTests.swift
import XCTest
@testable import UNBOUND

final class AuthDeferralStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: AuthDeferralStore!

    // A fixed wall-clock anchor so re-prompt math is deterministic (no Date() drift).
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "AuthDeferralStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = AuthDeferralStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Persist + route

    func testNotActiveWhenNothingDeferred() {
        XCTAssertFalse(store.isActive(now: t0))
    }

    func testDeferralIsActiveImmediately() {
        store.markDeferred(now: t0)
        XCTAssertTrue(store.isActive(now: t0))
    }

    func testDeferralStillActiveInsideWindow() {
        store.markDeferred(now: t0)
        let almostDue = t0.addingTimeInterval(AuthDeferralStore.repromptInterval - 1)
        XCTAssertTrue(store.isActive(now: almostDue))
    }

    // MARK: - Re-prompt cadence

    func testDeferralNotActiveAtWindowBoundary() {
        store.markDeferred(now: t0)
        // Exactly at the re-prompt interval the wall is due again (strictly-less).
        let atBoundary = t0.addingTimeInterval(AuthDeferralStore.repromptInterval)
        XCTAssertFalse(store.isActive(now: atBoundary))
    }

    func testDeferralNotActivePastWindow() {
        store.markDeferred(now: t0)
        let pastWindow = t0.addingTimeInterval(AuthDeferralStore.repromptInterval + 1)
        XCTAssertFalse(store.isActive(now: pastWindow))
    }

    func testReDeferringRestartsWindow() {
        store.markDeferred(now: t0)
        // The window elapses and the wall re-prompts; the user taps "continue for
        // now" again, which must grant another full window from the newer tap.
        let reDeferAt = t0.addingTimeInterval(AuthDeferralStore.repromptInterval + 10)
        store.markDeferred(now: reDeferAt)
        XCTAssertTrue(store.isActive(now: reDeferAt))
        let insideSecondWindow = reDeferAt.addingTimeInterval(AuthDeferralStore.repromptInterval - 1)
        XCTAssertTrue(store.isActive(now: insideSecondWindow))
    }

    // MARK: - Cleared when linked

    func testClearMakesDeferralInactive() {
        store.markDeferred(now: t0)
        // Simulates the once-cloud-linked cleanup (RootView clears on sign-in).
        store.clear()
        XCTAssertFalse(store.isActive(now: t0))
    }

    // MARK: - Pure helper (used by routing straight off the @AppStorage value)

    func testPureIsActiveTreatsZeroAsNeverDeferred() {
        XCTAssertFalse(AuthDeferralStore.isActive(deferredAt: 0, now: t0))
    }

    func testPureIsActiveMatchesInstanceWithinWindow() {
        let deferredAt = t0.timeIntervalSince1970
        XCTAssertTrue(AuthDeferralStore.isActive(deferredAt: deferredAt, now: t0))
        let due = t0.addingTimeInterval(AuthDeferralStore.repromptInterval)
        XCTAssertFalse(AuthDeferralStore.isActive(deferredAt: deferredAt, now: due))
    }

    // MARK: - Persistence across instances (survives relaunch)

    func testDeferralSurvivesANewStoreInstanceOnTheSameDefaults() {
        store.markDeferred(now: t0)
        // A fresh instance on the same backing store models a relaunch: the
        // deferral must still suppress the wall.
        let relaunched = AuthDeferralStore(defaults: defaults)
        XCTAssertTrue(relaunched.isActive(now: t0))
    }
}
