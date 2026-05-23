// UNBOUNDTests/Services/TrialsStoreTests.swift
import XCTest
@testable import UNBOUND

final class WeeklyVowsStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "WeeklyVowsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMissingUserReturnsEmpty() {
        let store = WeeklyVowsStore(defaults: defaults)
        XCTAssertEqual(store.load(userId: "u-1"), .empty)
    }

    func testSaveLoadRoundtrip() {
        let store = WeeklyVowsStore(defaults: defaults)
        var state = WeeklyVowsState.empty
        state.completionsByAxis[.power] = 5
        state.unlockedTitles = [TitleID(path: .axis(.power), tier: .bronze)]
        state.skippedCurrentWeek = true
        state.weeklyVowCompletionLedger = [
            WeeklyVowCompletionLedgerEntry(
                vowId: "weekly-vow-W5-overdrive",
                performanceLogId: "perf-1",
                completedAt: Date(timeIntervalSince1970: 1_700_000_000),
                bonus: WeeklyVowCompletionBonus(
                    overallLevelXP: 120,
                    badgeProgress: WeeklyVowProgressDescriptor(title: "Limit Binding I", current: 1, target: 3),
                    cosmeticProgress: WeeklyVowProgressDescriptor(title: "Limit Binding Seal", current: 1, target: 5),
                    shareCard: nil
                )
            )
        ]

        store.save(state, userId: "u-1")
        XCTAssertEqual(store.load(userId: "u-1"), state)
    }

    func testMultipleUsersIsolated() {
        let store = WeeklyVowsStore(defaults: defaults)
        var stateA = WeeklyVowsState.empty
        stateA.completionsByAxis[.power] = 3
        var stateB = WeeklyVowsState.empty
        stateB.completionsByAxis[.power] = 10

        store.save(stateA, userId: "u-1")
        store.save(stateB, userId: "u-2")

        XCTAssertEqual(store.load(userId: "u-1"), stateA)
        XCTAssertEqual(store.load(userId: "u-2"), stateB)
    }

    func testLegacyTrialsStateMigratesToWeeklyVowsKey() throws {
        let userId = "u-legacy"
        let store = WeeklyVowsStore(defaults: defaults)
        var state = WeeklyVowsState.empty
        let card = WeeklyVowCard(
            id: "trial-W20-aligned",
            kind: .ember,
            theme: .axis(.power),
            displayName: "Power Focus",
            blurb: "Legacy saved card",
            capstone: WeeklyVowProof(displayName: "Top Set", description: "Legacy proof", evaluation: .manualClaim)
        )
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        state.currentVow = WeeklyVow(
            id: card.id,
            userId: userId,
            weekStart: state.currentWeekStart!,
            chosenCard: card,
            capstoneState: .pending,
            completedAt: nil
        )
        state.completionsByCardKind[.ember] = 2

        let encoded = try JSONEncoder().encode(state)
        let legacyJSON = String(decoding: encoded, as: UTF8.self)
            .replacingOccurrences(of: "\"ember\"", with: "\"aligned\"")
        defaults.set(Data(legacyJSON.utf8), forKey: "unbound.trialsState.\(userId)")

        let loaded = store.load(userId: userId)

        XCTAssertEqual(loaded.currentWeekCards.first?.kind, .ember)
        XCTAssertEqual(loaded.currentVow?.chosenCard.kind, .ember)
        XCTAssertEqual(loaded.completionsByCardKind[.ember], 2)
        XCTAssertNotNil(defaults.data(forKey: "unbound.weeklyVowsState.\(userId)"))
    }
}
