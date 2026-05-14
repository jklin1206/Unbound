// UNBOUNDTests/Services/UserSkillTierStoreTests.swift
import XCTest
@testable import UNBOUND

final class UserSkillTierStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "UserSkillTierStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMissingUserReturnsEmpty() {
        let store = UserSkillTierStore(defaults: defaults)
        XCTAssertEqual(store.load(userId: "u-1"), .empty)
    }

    func testSaveLoadRoundtrip() {
        let store = UserSkillTierStore(defaults: defaults)
        var state = UserSkillTierState.empty
        state.perSkill["pp.pullup"] = .vessel
        state.rankUpsEarned = 7
        state.ascendantSkills = ["co.dead-hang-45"]

        store.save(state, userId: "u-1")
        XCTAssertEqual(store.load(userId: "u-1"), state)
    }

    func testMultipleUsersIsolated() {
        let store = UserSkillTierStore(defaults: defaults)
        var stateA = UserSkillTierState.empty
        stateA.perSkill["pp.pullup"] = .forged

        var stateB = UserSkillTierState.empty
        stateB.perSkill["pp.pullup"] = .ascendant

        store.save(stateA, userId: "u-1")
        store.save(stateB, userId: "u-2")

        XCTAssertEqual(store.load(userId: "u-1"), stateA)
        XCTAssertEqual(store.load(userId: "u-2"), stateB)
    }
}
