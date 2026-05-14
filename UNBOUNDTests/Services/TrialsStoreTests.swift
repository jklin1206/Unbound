// UNBOUNDTests/Services/TrialsStoreTests.swift
import XCTest
@testable import UNBOUND

final class TrialsStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "TrialsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMissingUserReturnsEmpty() {
        let store = TrialsStore(defaults: defaults)
        XCTAssertEqual(store.load(userId: "u-1"), .empty)
    }

    func testSaveLoadRoundtrip() {
        let store = TrialsStore(defaults: defaults)
        var state = TrialsState.empty
        state.completionsByAxis[.power] = 5
        state.unlockedTitles = [TitleID(path: .axis(.power), tier: .bronze)]
        state.skippedCurrentWeek = true

        store.save(state, userId: "u-1")
        XCTAssertEqual(store.load(userId: "u-1"), state)
    }

    func testMultipleUsersIsolated() {
        let store = TrialsStore(defaults: defaults)
        var stateA = TrialsState.empty
        stateA.completionsByAxis[.power] = 3
        var stateB = TrialsState.empty
        stateB.completionsByAxis[.power] = 10

        store.save(stateA, userId: "u-1")
        store.save(stateB, userId: "u-2")

        XCTAssertEqual(store.load(userId: "u-1"), stateA)
        XCTAssertEqual(store.load(userId: "u-2"), stateB)
    }
}
