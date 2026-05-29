import XCTest
@testable import UNBOUND

// BLOCKER 3 + 4(a/b) proof:
//   • a NEW linked_sessions row the user participates in → handleLinkedSessionDetected
//     is called once, with the documented base-XP proxy.
//   • a re-fetch of the same row → NOT called again (persisted dedup).
//   • crossing the squadStreak threshold via the real loaded Squad value →
//     unlockedSquadTitles populated + .squadTitleUnlocked posted.
//   • crossing the linkedSessions threshold via processed rows → title awarded.

@MainActor
private final class SpyActivityService: SquadActivityServiceProtocol {
    var linkedCalls: [(userId: String, baseXP: Int)] = []
    func record(kind: SquadActivityEntry.Kind, payload: SquadActivityPayload, userId: String) async {}
    func fetchRecent(userId: String) async throws -> [SquadActivityEntry] { [] }
    func handleLinkedSessionDetected(userId: String, participantDisplayNames: [String], baseSessionXP: Int) async {
        linkedCalls.append((userId, baseSessionXP))
    }
}

@MainActor
final class SquadLoopReconcilerTests: XCTestCase {

    private var store: SquadLoopStore!
    private var titleStore: SquadStore!
    private var titleService: SquadTitleService!
    private var backend: MockSquadBackend!
    private var activity: SpyActivityService!
    private var reconciler: SquadLoopReconciler!

    private let userId = "00000000-0000-0000-0000-0000000000C1"
    private var userUUID: UUID { UUID(uuidString: userId)! }
    private let squadId = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!

    override func setUp() {
        super.setUp()
        let d1 = UserDefaults(suiteName: "SquadLoopReconcilerTests.loop")!
        d1.removePersistentDomain(forName: "SquadLoopReconcilerTests.loop")
        let d2 = UserDefaults(suiteName: "SquadLoopReconcilerTests.titles")!
        d2.removePersistentDomain(forName: "SquadLoopReconcilerTests.titles")
        store = SquadLoopStore(defaults: d1)
        titleStore = SquadStore(defaults: d2)
        titleService = SquadTitleService(store: titleStore)
        backend = MockSquadBackend()
        activity = SpyActivityService()
        reconciler = SquadLoopReconciler(
            backend: backend,
            activityService: activity,
            titleService: titleService,
            store: store
        )
    }

    private func makeSquad(streakWeeks: Int) -> Squad {
        Squad(
            id: squadId,
            name: "Loop Squad",
            captainId: userUUID,
            affinityAxis: nil,
            affinitySetAt: nil,
            inviteCode: "LOOP12",
            maxSize: 8,
            squadStreakWeeks: streakWeeks,
            createdAt: Date()
        )
    }

    private func makeLinkedSession(id: UUID, at: Date, includesUser: Bool = true) -> LinkedSession {
        LinkedSession(
            id: id,
            squadId: squadId,
            userIds: includesUser ? [userUUID, UUID()] : [UUID(), UUID()],
            startedAt: at,
            endedAt: at.addingTimeInterval(1800)
        )
    }

    func testNewLinkedSessionTriggersBonusOnceAndDedupesOnRefetch() async {
        let sessionId = UUID()
        backend.linkedSessions[squadId] = [makeLinkedSession(id: sessionId, at: Date())]
        let squad = makeSquad(streakWeeks: 0)

        await reconciler.reconcile(userId: userId, userUUID: userUUID, squad: squad)
        XCTAssertEqual(activity.linkedCalls.count, 1, "New linked session should fire once")
        XCTAssertEqual(activity.linkedCalls.first?.baseXP, SquadXPBonusBaseline.baseSessionXP)
        XCTAssertEqual(store.linkedSessionsCount(userId: userId), 1)

        // Re-fetch the same row (e.g. squad re-load / relaunch).
        await reconciler.reconcile(userId: userId, userUUID: userUUID, squad: squad)
        XCTAssertEqual(activity.linkedCalls.count, 1, "Re-fetched row must not re-bonus")
        XCTAssertEqual(store.linkedSessionsCount(userId: userId), 1)
    }

    func testLinkedSessionUserNotParticipantIsIgnored() async {
        backend.linkedSessions[squadId] = [makeLinkedSession(id: UUID(), at: Date(), includesUser: false)]
        await reconciler.reconcile(userId: userId, userUUID: userUUID, squad: makeSquad(streakWeeks: 0))
        XCTAssertTrue(activity.linkedCalls.isEmpty)
        XCTAssertEqual(store.linkedSessionsCount(userId: userId), 0)
    }

    func testCrossingSquadStreakThresholdAwardsTitleAndPostsEvent() async {
        // Seed last-known streak just below the tier-1 threshold (4 weeks).
        store.setLastKnownStreakWeeks(3, userId: userId)

        var posted: [SquadTitleID] = []
        let token = NotificationCenter.default.addObserver(
            forName: .squadTitleUnlocked, object: nil, queue: nil
        ) { note in if let id = note.object as? SquadTitleID { posted.append(id) } }
        defer { NotificationCenter.default.removeObserver(token) }

        // Real loaded squad now reports 4 streak weeks (crossed by the cron).
        await reconciler.reconcile(userId: userId, userUUID: userUUID, squad: makeSquad(streakWeeks: 4))

        let expected = SquadTitleID(category: .squadStreak, axis: nil, tier: 1)
        XCTAssertEqual(titleStore.load(userId: userId).unlockedSquadTitles, [expected])
        XCTAssertEqual(posted, [expected])
    }

    func testCrossingLinkedSessionsThresholdAwardsTitle() async {
        // Already at 9 processed; one new row crosses the tier-1 threshold (10).
        store.addLinkedSessions(9, userId: userId)
        backend.linkedSessions[squadId] = [makeLinkedSession(id: UUID(), at: Date())]

        var posted: [SquadTitleID] = []
        let token = NotificationCenter.default.addObserver(
            forName: .squadTitleUnlocked, object: nil, queue: nil
        ) { note in if let id = note.object as? SquadTitleID { posted.append(id) } }
        defer { NotificationCenter.default.removeObserver(token) }

        await reconciler.reconcile(userId: userId, userUUID: userUUID, squad: makeSquad(streakWeeks: 0))

        let expected = SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)
        XCTAssertEqual(store.linkedSessionsCount(userId: userId), 10)
        XCTAssertEqual(titleStore.load(userId: userId).unlockedSquadTitles, [expected])
        XCTAssertEqual(posted, [expected])
    }
}
