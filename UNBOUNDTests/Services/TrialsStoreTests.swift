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
        state.completionsByLane[.recovery] = 5
        state.unlockedTitles = [TitleID(path: .axis(.power), tier: .bronze)]
        state.skippedCurrentWeek = true
        state.weeklyVowCompletionLedger = [
            WeeklyVowCompletionLedgerEntry(
                vowId: "weekly-vow-W5-overdrive",
                performanceLogId: "perf-1",
                completedAt: Date(timeIntervalSince1970: 1_700_000_000),
                bonus: WeeklyVowCompletionBonus(
                    overallLevelXP: 120,
                    badgeProgress: WeeklyVowProgressDescriptor(title: "Finisher Vow I", current: 1, target: 3),
                    cosmeticProgress: WeeklyVowProgressDescriptor(title: "Finisher Vow Mark", current: 1, target: 5),
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
        stateA.completionsByLane[.recovery] = 3
        var stateB = WeeklyVowsState.empty
        stateB.completionsByLane[.recovery] = 10

        store.save(stateA, userId: "u-1")
        store.save(stateB, userId: "u-2")

        XCTAssertEqual(store.load(userId: "u-1"), stateA)
        XCTAssertEqual(store.load(userId: "u-2"), stateB)
    }

    /// Spec §9: a pre-v2 persisted blob carries an in-flight vow plus the legacy
    /// `completionsByCardKind` marker. v2 must discard the broken in-flight vow
    /// (empty cards + skipped) while preserving the durable unlocked title.
    ///
    /// We build the blob from a real encoded v2 state (so all nested TitleID/card
    /// encodings are exact) and inject the legacy marker key that triggers the
    /// migration discard.
    func testLegacyPreV2BlobDiscardsInFlightVowButKeepsTitle() throws {
        let title = TitleID(path: .axis(.power), tier: .gold)
        let card = WeeklyVowCard(
            id: "weekly-vow-W20-recovery",
            lane: .recovery,
            bet: .small,
            displayName: "Power Focus",
            blurb: "Legacy saved card",
            target: VowTarget(count: 1, noun: "recovery reset")
        )
        var state = WeeklyVowsState.empty
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        state.currentVow = WeeklyVow(
            id: card.id,
            userId: "u-legacy",
            weekStart: state.currentWeekStart!,
            chosenCard: card,
            capstoneState: .pending,
            completedAt: nil
        )
        state.unlockedTitles = [title]

        let encoded = try JSONEncoder().encode(state)
        var dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        // Inject the pre-v2 marker that should trip the discard migration.
        dict["completionsByCardKind"] = []
        let legacyData = try JSONSerialization.data(withJSONObject: dict)

        let decoded = try JSONDecoder().decode(WeeklyVowsState.self, from: legacyData)

        XCTAssertNil(decoded.currentTrial)
        XCTAssertTrue(decoded.currentWeekCards.isEmpty)
        XCTAssertTrue(decoded.skippedCurrentWeek)
        XCTAssertEqual(decoded.unlockedTitles, [title])
    }

    /// Core-1 review request: a card JSON missing lane/bet/target decodes to the
    /// documented defaults instead of throwing.
    func testCardMissingLaneBetTargetDecodesToDefaults() throws {
        let cardJSON: [String: Any] = [
            "id": "weekly-vow-W1-x",
            "displayName": "Bare Card",
            "blurb": "Missing lane/bet/target."
        ]
        let data = try JSONSerialization.data(withJSONObject: cardJSON)
        let card = try JSONDecoder().decode(WeeklyVowCard.self, from: data)

        XCTAssertEqual(card.lane, .fuel)
        XCTAssertEqual(card.bet, .medium)
        XCTAssertEqual(card.target.count, 1)
        XCTAssertEqual(card.target.noun, "session")
    }

    func testDecodesLegacyPendingPenaltyAsDebt() throws {
        // A v1 state blob carried `pendingVowPenaltyXP`. v2 must surface that owed
        // amount as collectible debt under `pendingVowDebtXP`.
        let base = WeeklyVowsState.empty
        let baseData = try JSONEncoder().encode(base)
        var dict = try JSONSerialization.jsonObject(with: baseData) as! [String: Any]
        dict["pendingVowPenaltyXP"] = 120
        dict.removeValue(forKey: "pendingVowDebtXP")
        let legacyData = try JSONSerialization.data(withJSONObject: dict)
        let state = try JSONDecoder().decode(WeeklyVowsState.self, from: legacyData)
        XCTAssertEqual(state.pendingVowDebtXP, 120)
    }

    func testDebtSurvivesEncodeRoundTrip() throws {
        var state = WeeklyVowsState.empty
        state.pendingVowDebtXP = 250
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WeeklyVowsState.self, from: data)
        XCTAssertEqual(decoded.pendingVowDebtXP, 250)
    }
}
