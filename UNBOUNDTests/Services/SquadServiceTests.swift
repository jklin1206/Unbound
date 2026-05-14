// UNBOUNDTests/Services/SquadServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class SquadServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: SquadStore!
    private var mockBackend: MockSquadBackend!
    private var auth: MockAuthService!
    private var service: SquadService!

    /// Stable userId for the test captain — valid UUID string.
    private let userId = "00000000-0000-0000-0000-000000000001"

    override func setUp() {
        super.setUp()
        suiteName = "SquadServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = SquadStore(defaults: defaults)
        mockBackend = MockSquadBackend()
        auth = MockAuthService()
        service = SquadService(store: store, backend: mockBackend, auth: auth)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Seed a squad into the mock backend and pre-populate local state
    /// so the service sees the user already in a squad.
    private func seedSquad(
        captainUserId: String? = nil,
        memberUserIds: [String] = [],
        inviteCode: String = "SEED01"
    ) -> Squad {
        let captainId = UUID(uuidString: captainUserId ?? userId)!
        let squadId = UUID()
        let squad = Squad(
            id: squadId,
            name: "Test Squad",
            captainId: captainId,
            affinityAxis: nil,
            affinitySetAt: nil,
            inviteCode: inviteCode,
            maxSize: 8,
            squadStreakWeeks: 0,
            createdAt: Date()
        )
        mockBackend.squads[squadId] = squad
        var roster: [SquadMember] = [
            SquadMember(
                id: UUID(),
                squadId: squadId,
                userId: captainId,
                joinedAt: Date().addingTimeInterval(-3600),
                displayName: captainId.uuidString,
                equippedTitle: nil,
                buildIdentity: nil
            )
        ]
        for extra in memberUserIds {
            let uid = UUID(uuidString: extra) ?? UUID()
            roster.append(SquadMember(
                id: UUID(),
                squadId: squadId,
                userId: uid,
                joinedAt: Date(),
                displayName: uid.uuidString,
                equippedTitle: nil,
                buildIdentity: nil
            ))
        }
        mockBackend.members[squadId] = roster

        var state = store.load(userId: captainUserId ?? userId)
        state.currentSquad = squad
        state.roster = roster
        store.save(state, userId: captainUserId ?? userId)
        return squad
    }

    // MARK: - Task 5.2: createSquad

    func testCreateSquadHappyPath() async throws {
        let squad = try await service.createSquad(name: "Iron Crew", userId: userId)

        XCTAssertEqual(squad.name, "Iron Crew")
        XCTAssertEqual(squad.captainId, UUID(uuidString: userId)!)
        XCTAssertEqual(squad.inviteCode.count, 6)
        XCTAssertTrue(squad.inviteCode.allSatisfy { $0.isLetter || $0.isNumber })
        XCTAssertTrue(squad.inviteCode == squad.inviteCode.uppercased())

        let state = service.state(userId: userId)
        XCTAssertEqual(state.currentSquad?.id, squad.id)
        XCTAssertEqual(state.currentSquad?.captainId, UUID(uuidString: userId)!)
    }

    func testCreateSquadInvalidName() async {
        // Empty name
        await XCTAssertThrowsErrorAsync(
            try await service.createSquad(name: "", userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .invalidName)
        }
        // Whitespace-only
        await XCTAssertThrowsErrorAsync(
            try await service.createSquad(name: "   ", userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .invalidName)
        }
        // Over 30 chars
        await XCTAssertThrowsErrorAsync(
            try await service.createSquad(name: String(repeating: "a", count: 31), userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .invalidName)
        }
    }

    func testCreateSquadAlreadyInSquad() async {
        _ = seedSquad()
        await XCTAssertThrowsErrorAsync(
            try await service.createSquad(name: "Another", userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .alreadyInSquad)
        }
    }

    func testCreateSquadFiresNotification() async throws {
        let exp = expectation(forNotification: .squadStateChanged, object: nil)
        _ = try await service.createSquad(name: "Notify Test", userId: userId)
        await fulfillment(of: [exp], timeout: 2.0)
    }

    // MARK: - Task 5.3: joinSquad

    func testJoinSquadHappyPath() async throws {
        // Seed a squad in the backend (different captain).
        let otherCaptainId = "00000000-0000-0000-0000-000000000099"
        let existing = seedSquad(captainUserId: otherCaptainId)
        // Clear state for our user (they haven't joined yet).
        var cleanState = store.load(userId: userId)
        cleanState.currentSquad = nil
        cleanState.roster = []
        store.save(cleanState, userId: userId)

        let joined = try await service.joinSquad(inviteCode: existing.inviteCode, userId: userId)
        XCTAssertEqual(joined.id, existing.id)

        // After loadCurrentSquad runs, state reflects membership.
        let state = service.state(userId: userId)
        XCTAssertEqual(state.currentSquad?.id, existing.id)
    }

    func testJoinSquadInvalidCode() async {
        // "BADCOD" mapped to invalidInviteCode in mock.
        mockBackend.throwOnInviteCode["BADCOD"] = .invalidInviteCode
        await XCTAssertThrowsErrorAsync(
            try await service.joinSquad(inviteCode: "BADCOD", userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .invalidInviteCode)
        }
    }

    func testJoinSquadFull() async {
        // Seed squad at capacity (maxSize = 8 members already present).
        let otherCaptainId = "00000000-0000-0000-0000-000000000099"
        let existing = seedSquad(captainUserId: otherCaptainId)
        // Fill to max_size using the mock's throw-on-code injection.
        mockBackend.throwOnInviteCode[existing.inviteCode] = .squadFull

        // Ensure our user has no squad.
        var cleanState = store.load(userId: userId)
        cleanState.currentSquad = nil
        store.save(cleanState, userId: userId)

        await XCTAssertThrowsErrorAsync(
            try await service.joinSquad(inviteCode: existing.inviteCode, userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .squadFull)
        }
    }

    func testJoinSquadAlreadyInAnotherSquad() async {
        // User already in a squad — service should short-circuit before calling backend.
        _ = seedSquad()
        let otherCaptainId = "00000000-0000-0000-0000-000000000099"
        let other = seedSquad(captainUserId: otherCaptainId, inviteCode: "OTHER1")

        await XCTAssertThrowsErrorAsync(
            try await service.joinSquad(inviteCode: other.inviteCode, userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .alreadyInSquad)
        }
    }

    // MARK: - Task 5.4: leaveSquad

    func testNonCaptainLeaves() async throws {
        let captainId = "00000000-0000-0000-0000-000000000099"
        let squad = seedSquad(captainUserId: captainId)

        // Add our user as a regular member to local state and backend.
        guard let userUUID = UUID(uuidString: userId) else { XCTFail(); return }
        let memberEntry = SquadMember(
            id: UUID(),
            squadId: squad.id,
            userId: userUUID,
            joinedAt: Date(),
            displayName: userId,
            equippedTitle: nil,
            buildIdentity: nil
        )
        mockBackend.members[squad.id, default: []].append(memberEntry)
        var s = store.load(userId: userId)
        s.currentSquad = squad
        s.roster = (mockBackend.members[squad.id] ?? [])
        store.save(s, userId: userId)

        try await service.leaveSquad(userId: userId)

        let state = service.state(userId: userId)
        XCTAssertNil(state.currentSquad)
        XCTAssertTrue(
            mockBackend.deletedMembers.contains { $0.userId == userUUID },
            "Expected deleteMember to be called for non-captain"
        )
    }

    func testCaptainLeavesWith2PlusRemaining() async throws {
        let memberId2 = "00000000-0000-0000-0000-000000000002"
        let squad = seedSquad(memberUserIds: [memberId2])
        // userId is the captain (seedSquad default), memberId2 is the other member.
        guard let userUUID = UUID(uuidString: userId) else { XCTFail(); return }
        guard let m2UUID = UUID(uuidString: memberId2) else { XCTFail(); return }

        // Ensure backend members list has captain first (joined_at earliest).
        var roster = mockBackend.members[squad.id] ?? []
        // Make sure captain joined before member2 (seedSquad already does this).
        roster.sort { $0.joinedAt < $1.joinedAt }
        mockBackend.members[squad.id] = roster

        try await service.leaveSquad(userId: userId)

        XCTAssertEqual(mockBackend.captainUpdates.count, 1)
        XCTAssertEqual(mockBackend.captainUpdates.first?.squadId, squad.id)
        XCTAssertEqual(mockBackend.captainUpdates.first?.newCaptainId, m2UUID)
        XCTAssertTrue(
            mockBackend.deletedMembers.contains { $0.userId == userUUID },
            "Captain's own member row should be deleted"
        )
        XCTAssertNil(service.state(userId: userId).currentSquad)
    }

    func testCaptainLeavesAsLastMember() async throws {
        // Seed squad with only the captain.
        let squad = seedSquad()
        guard let userUUID = UUID(uuidString: userId) else { XCTFail(); return }
        _ = userUUID  // silence unused warning

        try await service.leaveSquad(userId: userId)

        XCTAssertTrue(
            mockBackend.deletedSquads.contains(squad.id),
            "Squad should be deleted when last member leaves"
        )
        XCTAssertNil(service.state(userId: userId).currentSquad)
    }

    // MARK: - Task 5.5: setAffinity + aggregateBuildHexValues + loadCurrentSquad

    func testSetAffinityHappyPath() async throws {
        let squad = seedSquad()

        try await service.setAffinity(.power, userId: userId)

        let state = service.state(userId: userId)
        XCTAssertEqual(state.currentSquad?.affinityAxis, .power)
        XCTAssertEqual(mockBackend.affinityUpdates.count, 1)
        XCTAssertEqual(mockBackend.affinityUpdates.first?.axis, .power)
        XCTAssertEqual(mockBackend.affinityUpdates.first?.squadId, squad.id)
    }

    func testSetAffinityThrowsNotCaptain() async {
        let captainId = "00000000-0000-0000-0000-000000000099"
        _ = seedSquad(captainUserId: captainId)
        // Our userId is a non-captain member — set up state for userId.
        let existingSquad = mockBackend.squads.values.first!
        var s = store.load(userId: userId)
        s.currentSquad = existingSquad
        store.save(s, userId: userId)

        await XCTAssertThrowsErrorAsync(
            try await service.setAffinity(.endurance, userId: userId)
        ) { error in
            XCTAssertEqual(error as? SquadError, .notCaptain)
        }
    }

    func testSetAffinityNilClears() async throws {
        let squad = seedSquad()
        // First set a non-nil affinity.
        try await service.setAffinity(.agility, userId: userId)
        XCTAssertEqual(service.state(userId: userId).currentSquad?.affinityAxis, .agility)

        // Now clear it.
        try await service.setAffinity(nil, userId: userId)
        let state = service.state(userId: userId)
        XCTAssertNil(state.currentSquad?.affinityAxis)
        XCTAssertEqual(mockBackend.affinityUpdates.last?.squadId, squad.id)
        XCTAssertNil(mockBackend.affinityUpdates.last?.axis)
    }

    func testAggregateBuildHexValuesAcross3Members() {
        // Seed 3 members with different BuildIdentities.
        let squad = seedSquad()
        var s = store.load(userId: userId)
        let power    = BuildIdentity(primary: .power,      secondary: nil, shape: .lean)
        let agility  = BuildIdentity(primary: .agility,    secondary: nil, shape: .lean)
        let power2   = BuildIdentity(primary: .power,      secondary: nil, shape: .lean)
        s.roster = [
            SquadMember(id: UUID(), squadId: squad.id, userId: UUID(), joinedAt: Date(),
                        displayName: "A", equippedTitle: nil, buildIdentity: power),
            SquadMember(id: UUID(), squadId: squad.id, userId: UUID(), joinedAt: Date(),
                        displayName: "B", equippedTitle: nil, buildIdentity: agility),
            SquadMember(id: UUID(), squadId: squad.id, userId: UUID(), joinedAt: Date(),
                        displayName: "C", equippedTitle: nil, buildIdentity: power2),
        ]
        store.save(s, userId: userId)

        let agg = service.aggregateBuildHexValues(userId: userId)

        // 3 members: 2 power, 1 agility, 0 others.
        // power:    30 + (2/3)*50 ≈ 63.3
        // agility:  30 + (1/3)*50 ≈ 46.6
        // others:   30 + 0        = 30
        let powerVal   = agg[.power]    ?? 0
        let agilityVal = agg[.agility]  ?? 0
        let controlVal = agg[.control]  ?? 0

        XCTAssertGreaterThan(powerVal, agilityVal, "power axis should dominate (2 members)")
        XCTAssertGreaterThan(agilityVal, controlVal, "agility (1 member) > control (0 members)")
        XCTAssertEqual(controlVal, 30.0, accuracy: 0.01)
        XCTAssertEqual(powerVal,   30 + (2.0/3.0) * 50, accuracy: 0.01)
        XCTAssertEqual(agilityVal, 30 + (1.0/3.0) * 50, accuracy: 0.01)
    }

    func testLoadCurrentSquadPopulatesState() async {
        // Seed a squad in the mock backend for our user.
        let otherCaptainId = "00000000-0000-0000-0000-000000000099"
        let squad = seedSquad(captainUserId: otherCaptainId)
        let userUUID = UUID(uuidString: userId)!

        // Add our user as a member in the mock backend.
        let memberEntry = SquadMember(
            id: UUID(),
            squadId: squad.id,
            userId: userUUID,
            joinedAt: Date(),
            displayName: userId,
            equippedTitle: nil,
            buildIdentity: nil
        )
        mockBackend.members[squad.id, default: []].append(memberEntry)

        // Clear local state to simulate a fresh app launch.
        store.save(.empty, userId: userId)

        await service.loadCurrentSquad(userId: userId)

        let state = service.state(userId: userId)
        XCTAssertEqual(state.currentSquad?.id, squad.id)
        XCTAssertFalse(state.roster.isEmpty, "Roster should be populated after loadCurrentSquad")
    }
}

// MARK: - Async throw helpers

/// XCTest doesn't ship an async-aware assertThrowsError. This helper fills the gap.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error but none was thrown. \(message())", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
