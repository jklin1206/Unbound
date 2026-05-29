// UNBOUNDTests/Services/SquadActivityServiceTests.swift
import XCTest
@testable import UNBOUND

// MARK: - Minimal MockSquadService for these tests

@MainActor
private final class MockSquadService: SquadServiceProtocol {
    var stubbedState: SquadState = .empty

    func loadCurrentSquad(userId: String) async {}
    func createSquad(name: String, userId: String) async throws -> Squad {
        throw SquadError.backendUnavailable
    }
    func joinSquad(inviteCode: String, userId: String) async throws -> Squad {
        throw SquadError.backendUnavailable
    }
    func leaveSquad(userId: String) async throws {}
    func setAffinity(_ axis: AttributeKey?, userId: String) async throws {}
    func state(userId: String) -> SquadState { stubbedState }
    func aggregateBuildHexValues(userId: String) -> [AttributeKey: Double] { [:] }
}

// MARK: - SquadActivityServiceTests

@MainActor
final class SquadActivityServiceTests: XCTestCase {

    private var mockBackend: MockSquadActivityBackend!
    private var mockAuth: MockAuthService!
    private var mockSquadService: MockSquadService!
    private var service: SquadActivityService!

    private let userId = "00000000-0000-0000-0000-000000000001"
    private let squadId = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!

    override func setUp() {
        super.setUp()
        mockBackend = MockSquadActivityBackend()
        mockAuth = MockAuthService()
        mockSquadService = MockSquadService()
        service = SquadActivityService(
            backend: mockBackend,
            auth: mockAuth,
            squadService: mockSquadService
        )
    }

    // Helper: seed a squad into the mock service state.
    private func seedSquad() {
        let squad = Squad(
            id: squadId,
            name: "Test Squad",
            captainId: UUID(uuidString: userId)!,
            affinityAxis: nil,
            affinitySetAt: nil,
            inviteCode: "ABCD12",
            maxSize: 8,
            squadStreakWeeks: 0,
            createdAt: Date()
        )
        mockSquadService.stubbedState = SquadState(
            currentSquad: squad,
            roster: [],
            activeRosterPresence: [],
            recentActivity: [],
            unlockedSquadTitles: []
        )
    }

    // Helper: build a minimal WeeklyVowCard for testing.
    private func makeWeeklyVowCard() -> WeeklyVowCard {
        WeeklyVowCard(
            id: "weekly-vow-test-W01",
            kind: .overdrive,
            theme: .axis(.power),
            displayName: "Power Finish",
            blurb: "A controlled finisher after training.",
            capstone: WeeklyVowProof(
                displayName: "Hit a new PR",
                description: "Hit a new one-rep max this week.",
                evaluation: .manualClaim
            )
        )
    }

    // MARK: - Test 1: record skips when user has no squad

    func testRecordSkipsWhenNoSquad() async {
        // mockSquadService returns .empty by default (no currentSquad)
        await service.record(
            kind: .trialCompleted,
            payload: .trialCompleted(trialName: "Power Focus", theme: .axis(.power)),
            userId: userId
        )
        XCTAssertTrue(mockBackend.insertedEntries.isEmpty, "Should not insert when user has no squad")
    }

    // MARK: - Test 2: record inserts row and posts notification

    func testRecordInsertsRowAndPostsNotification() async throws {
        seedSquad()

        var receivedEntry: SquadActivityEntry? = nil
        let expectation = XCTestExpectation(description: ".squadActivityRecorded posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .squadActivityRecorded, object: nil, queue: .main
        ) { note in
            receivedEntry = note.object as? SquadActivityEntry
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await service.record(
            kind: .trialCompleted,
            payload: .trialCompleted(trialName: "Power Focus", theme: .axis(.power)),
            userId: userId
        )

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(mockBackend.insertedEntries.count, 1)
        XCTAssertEqual(mockBackend.insertedEntries.first?.kind, .trialCompleted)
        XCTAssertEqual(mockBackend.insertedEntries.first?.squadId, squadId)
        XCTAssertNotNil(receivedEntry)
        XCTAssertEqual(receivedEntry?.kind, .trialCompleted)
    }

    // MARK: - Test 3: fetchRecent returns [] when no squad

    func testFetchRecentReturnsEmptyWhenNoSquad() async throws {
        mockBackend.stubbedFetchResult = [
            SquadActivityEntry(
                id: UUID(), squadId: squadId,
                userId: UUID(uuidString: userId)!,
                kind: .trialCompleted,
                payload: .trialCompleted(trialName: "Test", theme: .wildcard),
                createdAt: .now
            )
        ]
        let result = try await service.fetchRecent(userId: userId)
        XCTAssertTrue(result.isEmpty, "Should return [] when user has no squad")
    }

    // MARK: - Test 4: fetchRecent returns rows from backend when in squad

    func testFetchRecentReturnRowsFromBackend() async throws {
        seedSquad()
        let expected = SquadActivityEntry(
            id: UUID(), squadId: squadId,
            userId: UUID(uuidString: userId)!,
            kind: .titleUnlocked,
            payload: .titleUnlocked(titleId: TitleID(path: .axis(.power), tier: .bronze)),
            createdAt: .now
        )
        mockBackend.stubbedFetchResult = [expected]

        let result = try await service.fetchRecent(userId: userId)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, expected.id)
    }

    // MARK: - Test 5: .weeklyVowCompleted notification triggers record

    func testWeeklyVowCompletedNotificationTriggersRecord() async throws {
        seedSquad()
        // Set auth userId to match our test userId.
        // MockAuthService.currentUserId is "mock-user-123" by default — we re-create
        // the service with a matching userId for this test.
        let customAuth = MockAuthService()
        // MockAuthService has a hardcoded currentUserId = "mock-user-123"
        // so we need to reset squadService to use the same userId.
        // We instead re-create with the custom userId in the squad state.
        let customSquadService = MockSquadService()
        let squad = Squad(
            id: squadId, name: "T5 Squad",
            captainId: UUID(),
            affinityAxis: nil, affinitySetAt: nil,
            inviteCode: "T5T5T5", maxSize: 8,
            squadStreakWeeks: 0, createdAt: Date()
        )
        customSquadService.stubbedState = SquadState(
            currentSquad: squad, roster: [],
            activeRosterPresence: [], recentActivity: [],
            unlockedSquadTitles: []
        )

        let backend = MockSquadActivityBackend()
        let svc = SquadActivityService(
            backend: backend, auth: customAuth, squadService: customSquadService
        )
        _ = svc // keep alive

        let card = makeWeeklyVowCard()
        let vow = WeeklyVow(
            id: card.id,
            userId: customAuth.currentUserId ?? "mock-user-123",
            weekStart: Date(),
            chosenCard: card,
            capstoneState: .completed,
            completedAt: Date()
        )

        NotificationCenter.default.post(name: .weeklyVowCompleted, object: vow)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(backend.insertedEntries.count, 1)
        XCTAssertEqual(backend.insertedEntries.first?.kind, .trialCompleted)
    }

    func testLegacyTrialCompletedNotificationStillTriggersRecord() async throws {
        let customAuth = MockAuthService()
        let customSquadService = MockSquadService()
        let squad = Squad(
            id: squadId, name: "Legacy Squad",
            captainId: UUID(),
            affinityAxis: nil, affinitySetAt: nil,
            inviteCode: "LEGACY", maxSize: 8,
            squadStreakWeeks: 0, createdAt: Date()
        )
        customSquadService.stubbedState = SquadState(
            currentSquad: squad, roster: [],
            activeRosterPresence: [], recentActivity: [],
            unlockedSquadTitles: []
        )

        let backend = MockSquadActivityBackend()
        let svc = SquadActivityService(
            backend: backend, auth: customAuth, squadService: customSquadService
        )
        _ = svc

        let card = makeWeeklyVowCard()
        let vow = WeeklyVow(
            id: card.id,
            userId: customAuth.currentUserId ?? "mock-user-123",
            weekStart: Date(),
            chosenCard: card,
            capstoneState: .completed,
            completedAt: Date()
        )

        NotificationCenter.default.post(name: .trialCompleted, object: vow)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(backend.insertedEntries.count, 1)
        XCTAssertEqual(backend.insertedEntries.first?.kind, .trialCompleted)
    }

    // MARK: - Test 6: .titleUnlocked notification triggers record

    // MARK: - Test 7: handleLinkedSessionDetected applies +20% bonus and posts event

    func testLinkedSessionAppliesTwentyPercentBonusAndPostsEvent() async throws {
        seedSquad()
        let mockXP = MockSessionXPService()
        let svc = SquadActivityService(
            backend: mockBackend,
            auth: mockAuth,
            squadService: mockSquadService,
            sessionXP: mockXP
        )

        var posted = false
        var postedXP: Int? = nil
        let expectation = XCTestExpectation(description: ".linkedSessionDetected posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .linkedSessionDetected, object: nil, queue: .main
        ) { note in
            posted = true
            postedXP = note.userInfo?["xpBonus"] as? Int
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await svc.handleLinkedSessionDetected(
            userId: mockAuth.currentUserId ?? "mock-user-123",
            participantDisplayNames: ["Alex", "Maya"],
            baseSessionXP: 100
        )

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(posted, ".linkedSessionDetected should post for the toast")
        // 20% of 100 = 20, no prior affinity → net 20.
        XCTAssertEqual(mockXP.bonusCalls.count, 1)
        XCTAssertEqual(mockXP.bonusCalls.first?.amount, 20)
        XCTAssertEqual(mockXP.bonusCalls.first?.reason, "linkedSession")
        XCTAssertEqual(postedXP, 20)
    }

    func testTitleUnlockedNotificationTriggersRecord() async throws {
        let customAuth = MockAuthService()
        let customSquadService = MockSquadService()
        let squad = Squad(
            id: squadId, name: "T6 Squad",
            captainId: UUID(),
            affinityAxis: nil, affinitySetAt: nil,
            inviteCode: "T6T6T6", maxSize: 8,
            squadStreakWeeks: 0, createdAt: Date()
        )
        customSquadService.stubbedState = SquadState(
            currentSquad: squad, roster: [],
            activeRosterPresence: [], recentActivity: [],
            unlockedSquadTitles: []
        )

        let backend = MockSquadActivityBackend()
        let svc = SquadActivityService(
            backend: backend, auth: customAuth, squadService: customSquadService
        )
        _ = svc // keep alive

        let titleId = TitleID(path: .axis(.power), tier: .bronze)
        NotificationCenter.default.post(name: .titleUnlocked, object: titleId)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(backend.insertedEntries.count, 1)
        XCTAssertEqual(backend.insertedEntries.first?.kind, .titleUnlocked)
    }
}
