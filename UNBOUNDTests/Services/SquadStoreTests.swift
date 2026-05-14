// UNBOUNDTests/Services/SquadStoreTests.swift
import XCTest
@testable import UNBOUND

final class SquadStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SquadStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeFullState() -> SquadState {
        let squadId = UUID()
        let captainId = UUID()
        let userId1 = UUID()
        let userId2 = UUID()
        let now = Date(timeIntervalSince1970: 1_000_000)

        let squad = Squad(
            id: squadId,
            name: "Test Squad",
            captainId: captainId,
            affinityAxis: .power,
            affinitySetAt: now,
            inviteCode: "TESTCODE",
            maxSize: 8,
            squadStreakWeeks: 3,
            createdAt: now
        )

        let member1 = SquadMember(
            id: UUID(),
            squadId: squadId,
            userId: userId1,
            joinedAt: now,
            displayName: "Alice",
            equippedTitle: nil,
            buildIdentity: nil
        )
        let member2 = SquadMember(
            id: UUID(),
            squadId: squadId,
            userId: userId2,
            joinedAt: now,
            displayName: "Bob",
            equippedTitle: nil,
            buildIdentity: nil
        )

        let presence = SquadPresence(
            userId: userId1,
            squadId: squadId,
            workoutStartedAt: now,
            expiresAt: now.addingTimeInterval(3600)
        )

        let activity = SquadActivityEntry(
            id: UUID(),
            squadId: squadId,
            userId: userId1,
            kind: .memberJoined,
            payload: .memberJoined(memberDisplayName: "Alice"),
            createdAt: now
        )

        let title = SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)

        return SquadState(
            currentSquad: squad,
            roster: [member1, member2],
            activeRosterPresence: [presence],
            recentActivity: [activity],
            unlockedSquadTitles: [title]
        )
    }

    // MARK: - Tests

    func testMissingUserReturnsEmpty() {
        let store = SquadStore(defaults: defaults)
        XCTAssertEqual(store.load(userId: UUID().uuidString), .empty)
    }

    func testSaveLoadRoundtrip() {
        let store = SquadStore(defaults: defaults)
        let userId = UUID().uuidString
        let state = makeFullState()

        store.save(state, userId: userId)
        XCTAssertEqual(store.load(userId: userId), state)
    }

    func testMultipleUsersIsolated() {
        let store = SquadStore(defaults: defaults)
        let userA = UUID().uuidString
        let userB = UUID().uuidString

        var stateA = SquadState.empty
        stateA.unlockedSquadTitles = [SquadTitleID(category: .squadStreak, axis: nil, tier: 1)]

        var stateB = SquadState.empty
        stateB.unlockedSquadTitles = [SquadTitleID(category: .collectiveAxis, axis: .power, tier: 2)]

        store.save(stateA, userId: userA)
        store.save(stateB, userId: userB)

        XCTAssertEqual(store.load(userId: userA), stateA)
        XCTAssertEqual(store.load(userId: userB), stateB)
    }
}
