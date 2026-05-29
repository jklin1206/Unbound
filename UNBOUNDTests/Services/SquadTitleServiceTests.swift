import XCTest
@testable import UNBOUND

@MainActor
final class SquadTitleServiceTests: XCTestCase {
    typealias Counters = SquadTitleThresholdEvaluator.Counters

    private var store: SquadStore!
    private var service: SquadTitleService!
    private let userId = "00000000-0000-0000-0000-0000000000B1"

    override func setUp() {
        super.setUp()
        // Isolated UserDefaults suite so we never touch the shared store.
        let defaults = UserDefaults(suiteName: "SquadTitleServiceTests")!
        defaults.removePersistentDomain(forName: "SquadTitleServiceTests")
        store = SquadStore(defaults: defaults)
        service = SquadTitleService(store: store)
    }

    func testCrossingPopulatesUnlockedTitlesAndPostsEvent() async {
        var prior = Counters(); prior.linkedSessionsCount = 9
        var current = Counters(); current.linkedSessionsCount = 10

        var postedIds: [SquadTitleID] = []
        let token = NotificationCenter.default.addObserver(
            forName: .squadTitleUnlocked, object: nil, queue: nil
        ) { note in
            if let id = note.object as? SquadTitleID { postedIds.append(id) }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await service.applyCounterUpdate(prior: prior, current: current, userId: userId)

        let expected = SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)
        XCTAssertEqual(store.load(userId: userId).unlockedSquadTitles, [expected])
        XCTAssertEqual(postedIds, [expected])
    }

    func testNoCrossingLeavesTitlesUntouchedAndPostsNothing() async {
        var prior = Counters(); prior.linkedSessionsCount = 5
        var current = Counters(); current.linkedSessionsCount = 9

        var posted = false
        let token = NotificationCenter.default.addObserver(
            forName: .squadTitleUnlocked, object: nil, queue: nil
        ) { _ in posted = true }
        defer { NotificationCenter.default.removeObserver(token) }

        await service.applyCounterUpdate(prior: prior, current: current, userId: userId)

        XCTAssertTrue(store.load(userId: userId).unlockedSquadTitles.isEmpty)
        XCTAssertFalse(posted)
    }

    func testDoesNotDuplicateAlreadyUnlockedTitle() async {
        let id = SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)
        var seeded = store.load(userId: userId)
        seeded.unlockedSquadTitles = [id]
        store.save(seeded, userId: userId)

        // Re-cross the same threshold (e.g. recomputed snapshot): should not append a dupe.
        var prior = Counters(); prior.linkedSessionsCount = 9
        var current = Counters(); current.linkedSessionsCount = 11
        await service.applyCounterUpdate(prior: prior, current: current, userId: userId)

        XCTAssertEqual(store.load(userId: userId).unlockedSquadTitles, [id])
    }
}
