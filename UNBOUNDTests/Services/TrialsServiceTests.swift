// UNBOUNDTests/Services/TrialsServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class WeeklyVowsServiceTests: XCTestCase {

    var suiteName: String!
    var defaults: UserDefaults!
    var store: WeeklyVowsStore!
    var service: WeeklyVowsService!

    override func setUp() {
        super.setUp()
        suiteName = "WeeklyVowsServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = WeeklyVowsStore(defaults: defaults)
        service = WeeklyVowsService(
            store: store,
            recoveryCompletionsProvider: { _ in [] },
            cardioSessionsProvider: { _ in [] }
        )
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Seed the given card as the current week's only offer and commit it.
    private func pickLaneVow(_ card: WeeklyVowCard, userId: String = "u-1") {
        var state = service.state(userId: userId)
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: userId)
        service.pickVowCard(card, userId: userId)
    }

    // MARK: - ensureCurrentWeek

    func testEnsureCurrentWeekGenerates3Cards() async {
        await service.ensureCurrentWeek(userId: "u-1")
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.currentWeekCards.count, 3)
        XCTAssertNotNil(state.currentWeekStart)
    }

    func testEnsureCurrentWeekIdempotentWithinWeek() async {
        await service.ensureCurrentWeek(userId: "u-1")
        let stateA = service.state(userId: "u-1")
        await service.ensureCurrentWeek(userId: "u-1")
        let stateB = service.state(userId: "u-1")
        XCTAssertEqual(stateA, stateB)
    }

    // MARK: - pickCard + skipThisWeek

    func testPickCardPersistsWeeklyVow() {
        let card = makeVowCard(lane: .engine, bet: .medium)
        pickLaneVow(card)
        let state = service.state(userId: "u-1")

        XCTAssertNotNil(state.currentVow)
        XCTAssertEqual(state.currentVow?.chosenCard.id, card.id)
        XCTAssertEqual(state.currentVow?.capstoneState, .pending)
    }

    func testPickCardFiresNotification() {
        let card = makeVowCard(lane: .engine, bet: .medium)
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: "u-1")

        let exp = expectation(forNotification: .weeklyVowPicked, object: nil)
        service.pickVowCard(card, userId: "u-1")
        wait(for: [exp], timeout: 1.0)
    }

    func testSkipThisWeekSetsFlag() async {
        await service.ensureCurrentWeek(userId: "u-1")
        service.skipThisWeek(userId: "u-1")
        let state = service.state(userId: "u-1")

        XCTAssertTrue(state.skippedCurrentWeek)
        XCTAssertNil(state.currentVow)
        XCTAssertTrue(state.weeklyVowPenaltyLedger.isEmpty)
        XCTAssertEqual(state.pendingVowDebtXP, 0)
    }

    func testSkippingPickedVowAddsPenalty() {
        let card = makeVowCard(lane: .fuel, bet: .medium, target: VowTarget(count: 5, noun: "fuel anchor"))
        pickLaneVow(card)
        // Make the vow touched so the skip binds the stake.
        service.logFuelAnchor(userId: "u-1")

        service.skipThisWeek(userId: "u-1")

        let state = service.state(userId: "u-1")
        XCTAssertTrue(state.skippedCurrentWeek)
        XCTAssertNil(state.currentVow)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.count, 1)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.vowId, card.id)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.weekStart, state.currentWeekStart)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.lane, .fuel)
        XCTAssertEqual(state.pendingVowDebtXP, card.bet.oweXP)
    }

    /// Spec §10 switching grace: switching away from an UNTOUCHED vow is free
    /// (mis-tap protection).
    func testRepickingAfterUntouchedVowIsFree() {
        let a = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        let b = makeVowCard(lane: .engine, bet: .large, target: VowTarget(count: 1, noun: "engine session"))
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [a, b]
        store.save(state, userId: "u-1")

        service.pickVowCard(a, userId: "u-1")
        service.pickVowCard(b, userId: "u-1")

        let final = service.state(userId: "u-1")
        XCTAssertEqual(final.currentVow?.id, b.id)
        XCTAssertTrue(final.weeklyVowPenaltyLedger.isEmpty)
        XCTAssertEqual(final.pendingVowDebtXP, 0)
    }

    // MARK: - Missed vow rolls into debt (ensureCurrentWeek)

    func testMissedPickedVowAddsBetDebtOnWeekRoll() async {
        let missedCard = makeVowCard(lane: .engine, bet: .large, target: VowTarget(count: 1, noun: "engine session"))
        var stale = WeeklyVowsState.empty
        stale.currentWeekStart = Date(timeIntervalSince1970: 0)
        stale.currentVow = WeeklyVow(
            id: missedCard.id,
            userId: "u-1",
            weekStart: stale.currentWeekStart!,
            chosenCard: missedCard,
            capstoneState: .windowOpen,
            completedAt: nil
        )
        store.save(stale, userId: "u-1")

        await service.ensureCurrentWeek(userId: "u-1")

        let state = service.state(userId: "u-1")
        XCTAssertNil(state.currentVow)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.count, 1)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.penaltyXP, VowBet.large.oweXP)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.lane, .engine)
        XCTAssertEqual(state.pendingVowDebtXP, VowBet.large.oweXP)
    }

    func testPenaltyDedupeIncludesVowWeekStart() async {
        let card = makeVowCard(lane: .engine, bet: .large, target: VowTarget(count: 1, noun: "engine session"))
        var stale = WeeklyVowsState.empty
        let priorWeekStart = Date(timeIntervalSince1970: 0)
        let repeatedWeekStart = Date(timeIntervalSince1970: 1_000)
        stale.currentWeekStart = repeatedWeekStart
        stale.currentVow = WeeklyVow(
            id: card.id,
            userId: "u-1",
            weekStart: repeatedWeekStart,
            chosenCard: card,
            capstoneState: .windowOpen,
            completedAt: nil
        )
        stale.weeklyVowPenaltyLedger = [
            WeeklyVowPenaltyLedgerEntry(
                vowId: card.id,
                lane: card.lane,
                weekStart: priorWeekStart,
                missedAt: priorWeekStart,
                penaltyXP: card.bet.oweXP
            )
        ]
        stale.pendingVowDebtXP = card.bet.oweXP
        store.save(stale, userId: "u-1")

        await service.ensureCurrentWeek(userId: "u-1")

        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.weeklyVowPenaltyLedger.count, 2)
        XCTAssertEqual(state.pendingVowDebtXP, card.bet.oweXP * 2)
    }

    // MARK: - Broken-vow debt comes from the bet

    func testBrokenVowAddsDebtFromBet() {
        let card = makeVowCard(lane: .engine, bet: .large)
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: "u-1")
        service.pickVowCard(card, userId: "u-1")

        // Force a stale week so ensureCurrentWeek rolls + marks missed.
        var picked = service.state(userId: "u-1")
        picked.currentWeekStart = Date(timeIntervalSince1970: 1)
        store.save(picked, userId: "u-1")

        let exp = expectation(description: "rolled")
        Task { await service.ensureCurrentWeek(userId: "u-1"); exp.fulfill() }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, VowBet.large.oweXP)
    }

    // MARK: - equipTitle

    func testEquipTitleSetsEquippedField() {
        var state = WeeklyVowsState.empty
        let titleId = TitleID(path: .axis(.power), tier: .bronze)
        state.unlockedTitles = [titleId]
        store.save(state, userId: "u-1")

        service.equipTitle(titleId, userId: "u-1")
        XCTAssertEqual(service.state(userId: "u-1").equippedTitle, titleId)
    }

    func testEquipNilUnequips() {
        var state = WeeklyVowsState.empty
        let titleId = TitleID(path: .axis(.power), tier: .bronze)
        state.unlockedTitles = [titleId]
        state.equippedTitle = titleId
        store.save(state, userId: "u-1")

        service.equipTitle(nil, userId: "u-1")
        XCTAssertNil(service.state(userId: "u-1").equippedTitle)
    }

    func testCannotEquipUnUnlockedTitle() {
        let titleId = TitleID(path: .axis(.power), tier: .gold)
        service.equipTitle(titleId, userId: "u-1")
        XCTAssertNil(service.state(userId: "u-1").equippedTitle)
    }

    // MARK: - Lane completion (seal / fuel / auto-verify / switching grace)

    func testFuelTapIncrementsAndSealsAtTarget() {
        let card = makeVowCard(lane: .fuel, bet: .small, target: VowTarget(count: 3, noun: "fuel anchor"))
        pickLaneVow(card)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 1)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 2)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
        XCTAssertEqual(service.state(userId: "u-1").completionsByLane[.fuel], 1)
    }

    func testFuelTapDoesNothingForNonFuelVow() {
        let card = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        pickLaneVow(card)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 0)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)
    }

    func testSealVowPaysBetWinAndMarksCompleted() {
        let card = makeVowCard(lane: .recovery, bet: .medium, target: VowTarget(count: 1, noun: "recovery reset"))
        pickLaneVow(card)
        guard let vow = service.state(userId: "u-1").currentVow else {
            return XCTFail("expected a current vow")
        }

        service.sealVow(userId: "u-1", vow: vow, at: Date(timeIntervalSince1970: 1_700_001_000))
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.currentVow?.capstoneState, .completed)
        XCTAssertNotNil(state.currentVow?.completedAt)
        XCTAssertEqual(state.completionsByLane[.recovery], 1)
    }

    func testSealVowIsIdempotent() {
        let card = makeVowCard(lane: .recovery, bet: .medium, target: VowTarget(count: 1, noun: "recovery reset"))
        pickLaneVow(card)
        guard let vow = service.state(userId: "u-1").currentVow else {
            return XCTFail("expected a current vow")
        }
        service.sealVow(userId: "u-1", vow: vow, at: Date())
        service.sealVow(userId: "u-1", vow: vow, at: Date())
        XCTAssertEqual(service.state(userId: "u-1").completionsByLane[.recovery], 1)
    }

    // MARK: - Auto-verify: recovery source (routine-sourced PerformanceLogs)

    /// A routine-sourced recovery PerformanceLog completed in-week.
    private func recoveryPerfLog(
        titled title: String = "Recovery Reset",
        completedAt t: TimeInterval = 1_700_000_900
    ) -> PerformanceLog {
        PerformanceLog(
            id: UUID().uuidString,
            userId: "u-1",
            source: .routine,
            title: title,
            startedAt: Date(timeIntervalSince1970: t - 600),
            completedAt: Date(timeIntervalSince1970: t),
            blocks: []
        )
    }

    private func cardioSession(at t: TimeInterval = 1_700_000_900) -> CardioSession {
        CardioSession(
            userId: "u-1",
            type: .run,
            durationMinutes: 20,
            perceivedEffort: 5,
            date: Date(timeIntervalSince1970: t)
        )
    }

    private func makeAutoService(
        recovery: @escaping (String) async -> [PerformanceLog] = { _ in [] },
        cardio: @escaping (String) async -> [CardioSession] = { _ in [] }
    ) -> WeeklyVowsService {
        WeeklyVowsService(
            store: store,
            recoveryCompletionsProvider: recovery,
            cardioSessionsProvider: cardio
        )
    }

    private func pick(_ card: WeeklyVowCard, on autoService: WeeklyVowsService, userId: String = "u-1") {
        var state = autoService.state(userId: userId)
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: userId)
        autoService.pickVowCard(card, userId: userId)
    }

    private func runRefresh(on autoService: WeeklyVowsService, userId: String = "u-1") {
        let exp = expectation(description: "auto-verify")
        Task { await autoService.refreshAutoVerifiedVow(userId: userId); exp.fulfill() }
        wait(for: [exp], timeout: 5)
    }

    func testRefreshAutoVerifiedVowSealsWhenRecoveryLogsQualify() {
        let autoService = makeAutoService(recovery: { _ in [self.recoveryPerfLog()] })
        let card = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        pick(card, on: autoService)

        runRefresh(on: autoService)

        XCTAssertEqual(autoService.state(userId: "u-1").currentVow?.capstoneState, .completed)
        XCTAssertEqual(autoService.state(userId: "u-1").completionsByLane[.recovery], 1)
    }

    func testRefreshAutoVerifiedVowSealsWhenCardioQualifies() {
        let autoService = makeAutoService(cardio: { _ in [self.cardioSession()] })
        let card = makeVowCard(lane: .engine, bet: .small, target: VowTarget(count: 1, noun: "easy cardio session"))
        pick(card, on: autoService)

        runRefresh(on: autoService)

        XCTAssertEqual(autoService.state(userId: "u-1").currentVow?.capstoneState, .completed)
        XCTAssertEqual(autoService.state(userId: "u-1").completionsByLane[.engine], 1)
    }

    func testRefreshAutoVerifiedVowIsNoOpForFuel() {
        // Even if recovery/cardio sources are non-empty, a Fuel vow never auto-seals.
        let autoService = makeAutoService(
            recovery: { _ in [self.recoveryPerfLog()] },
            cardio: { _ in [self.cardioSession()] }
        )
        let card = makeVowCard(lane: .fuel, bet: .small, target: VowTarget(count: 1, noun: "fuel anchor"))
        pick(card, on: autoService)

        runRefresh(on: autoService)

        XCTAssertEqual(autoService.state(userId: "u-1").currentVow?.capstoneState, .pending)
        XCTAssertNil(autoService.state(userId: "u-1").completionsByLane[.fuel])
    }

    func testRefreshAutoVerifiedVowDoesNotSealBelowTarget() {
        // Only 1 recovery log, target needs 2.
        let autoService = makeAutoService(recovery: { _ in [self.recoveryPerfLog()] })
        let card = makeVowCard(lane: .recovery, bet: .medium, target: VowTarget(count: 2, noun: "recovery reset"))
        pick(card, on: autoService)

        runRefresh(on: autoService)

        XCTAssertEqual(autoService.state(userId: "u-1").currentVow?.capstoneState, .pending)
    }

    func testSwitchingBeforeProgressIsFree() {
        let a = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        let b = makeVowCard(lane: .engine, bet: .large, target: VowTarget(count: 1, noun: "easy cardio session"))
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [a, b]
        store.save(state, userId: "u-1")

        service.pickVowCard(a, userId: "u-1")
        service.pickVowCard(b, userId: "u-1")  // no progress on A → free switch

        XCTAssertEqual(service.state(userId: "u-1").currentVow?.id, b.id)
        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, 0)
    }

    func testSwitchingAfterProgressOwesStake() {
        let a = makeVowCard(lane: .fuel, bet: .medium, target: VowTarget(count: 5, noun: "fuel anchor"))
        let b = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [a, b]
        store.save(state, userId: "u-1")

        service.pickVowCard(a, userId: "u-1")
        service.logFuelAnchor(userId: "u-1")  // progress on A
        service.pickVowCard(b, userId: "u-1") // bound switch → owes A's stake

        XCTAssertEqual(service.state(userId: "u-1").currentVow?.id, b.id)
        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, VowBet.medium.oweXP) // 250
    }

    // MARK: - skipThisWeek grace (spec §10)

    func testSkipUntouchedVowIsFree() {
        // An untouched recovery vow (no in-app progress) is unbound; skipping it
        // owes no debt — consistent with pickVowCard's mis-tap grace.
        let card = makeVowCard(lane: .recovery, bet: .large, target: VowTarget(count: 1, noun: "recovery reset"))
        pickLaneVow(card)

        service.skipThisWeek(userId: "u-1")

        XCTAssertTrue(service.state(userId: "u-1").skippedCurrentWeek)
        XCTAssertNil(service.state(userId: "u-1").currentVow)
        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, 0)
    }

    func testSkipVowWithProgressOwesStake() {
        // A Fuel vow with a logged anchor is bound; skipping it owes the stake.
        let card = makeVowCard(lane: .fuel, bet: .medium, target: VowTarget(count: 5, noun: "fuel anchor"))
        pickLaneVow(card)
        service.logFuelAnchor(userId: "u-1")  // progress binds the vow

        service.skipThisWeek(userId: "u-1")

        XCTAssertTrue(service.state(userId: "u-1").skippedCurrentWeek)
        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, VowBet.medium.oweXP)
    }
}
