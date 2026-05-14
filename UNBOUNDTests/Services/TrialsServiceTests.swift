// UNBOUNDTests/Services/TrialsServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class TrialsServiceTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: TrialsStore!
    private var attribute: MockAttributeService!
    private var service: TrialsService!

    override func setUp() {
        super.setUp()
        suiteName = "TrialsServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = TrialsStore(defaults: defaults)
        attribute = MockAttributeService()
        service = TrialsService(
            store: store,
            attribute: attribute,
            recentLogsProvider: { _ in [] }
        )
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func seedAttribute(power: Double = 70, control: Double = 30) {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        for axis in AttributeKey.allCases {
            let value: Double = {
                switch axis {
                case .power: return power
                case .control: return control
                default: return 50
                }
            }()
            profile.set(axis, AttributeValue(peak: value, current: value, lastContributionAt: .now))
        }
        attribute.profileByUser["u-1"] = profile
    }

    // MARK: - T6.2 ensureCurrentWeek

    func testEnsureCurrentWeekGenerates3Cards() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.currentWeekCards.count, 3)
        XCTAssertNotNil(state.currentWeekStart)
    }

    func testEnsureCurrentWeekIdempotentWithinWeek() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let stateA = service.state(userId: "u-1")
        await service.ensureCurrentWeek(userId: "u-1")
        let stateB = service.state(userId: "u-1")
        XCTAssertEqual(stateA, stateB)
    }

    // MARK: - T6.3 pickCard + skipThisWeek

    func testPickCardPersistsTrial() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let cards = service.state(userId: "u-1").currentWeekCards
        let aligned = cards.first(where: { $0.kind == .aligned })!

        service.pickCard(aligned, userId: "u-1")
        let state = service.state(userId: "u-1")

        XCTAssertNotNil(state.currentTrial)
        XCTAssertEqual(state.currentTrial?.chosenCard.id, aligned.id)
        XCTAssertEqual(state.currentTrial?.capstoneState, .pending)
    }

    func testPickCardFiresNotification() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let cards = service.state(userId: "u-1").currentWeekCards
        let aligned = cards.first(where: { $0.kind == .aligned })!

        let exp = expectation(forNotification: .trialPicked, object: nil)
        service.pickCard(aligned, userId: "u-1")
        await fulfillment(of: [exp], timeout: 1.0)
    }

    func testSkipThisWeekSetsFlag() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        service.skipThisWeek(userId: "u-1")
        let state = service.state(userId: "u-1")

        XCTAssertTrue(state.skippedCurrentWeek)
        XCTAssertNil(state.currentTrial)
    }

    // MARK: - T6.4 completeCapstone

    func testCompleteCapstoneIncrementsAxisCounter() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let aligned = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .aligned })!
        service.pickCard(aligned, userId: "u-1")
        service.completeCapstone(userId: "u-1", at: .now)
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.completionsByAxis[.power], 1)
    }

    func testCompleteCapstoneIncrementsCardKindCounter() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let aligned = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .aligned })!
        service.pickCard(aligned, userId: "u-1")
        service.completeCapstone(userId: "u-1", at: .now)
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.completionsByCardKind[.aligned], 1)
    }

    func testCompleteCapstoneSetsStateAndFiresNotification() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let aligned = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .aligned })!
        service.pickCard(aligned, userId: "u-1")
        let exp = expectation(forNotification: .trialCompleted, object: nil)
        service.completeCapstone(userId: "u-1", at: .now)
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(service.state(userId: "u-1").currentTrial?.capstoneState, .completed)
    }

    func testCompleteCapstoneUnlocksTitleAtThreshold() async {
        seedAttribute()
        // Pre-seed 2 completions on power axis (just below bronze threshold)
        var initial = TrialsState.empty
        initial.completionsByAxis[.power] = 2
        initial.completionsByCardKind[.aligned] = 2
        store.save(initial, userId: "u-1")

        await service.ensureCurrentWeek(userId: "u-1")
        let aligned = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .aligned })!
        service.pickCard(aligned, userId: "u-1")

        let titleExp = expectation(forNotification: .titleUnlocked, object: nil)
        titleExp.expectedFulfillmentCount = 2  // axis + cardKind cross simultaneously
        service.completeCapstone(userId: "u-1", at: .now)
        await fulfillment(of: [titleExp], timeout: 1.0)

        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.unlockedTitles.count, 2)
        XCTAssertTrue(state.unlockedTitles.contains(TitleID(path: .axis(.power), tier: .bronze)))
        XCTAssertTrue(state.unlockedTitles.contains(TitleID(path: .cardKind(.aligned), tier: .bronze)))
    }

    // MARK: - T6.5 evaluateCapstoneFromLog + checkCapstoneWindow

    func testEvaluateCapstoneFromLogNoOpWhenPending() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        // Force the aligned card to use a known autoFromLog criterion.
        var aligned = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .aligned })!
        aligned = TrialCard(
            id: aligned.id, kind: aligned.kind, theme: aligned.theme,
            displayName: aligned.displayName, blurb: aligned.blurb,
            capstone: TrialCapstone(
                displayName: "Test",
                description: "Test",
                evaluation: .autoFromLog(.reps(5, exerciseName: "pullup"))
            )
        )
        service.pickCard(aligned, userId: "u-1")
        // currentTrial.capstoneState is .pending — should not fire.
        let history = [
            ExerciseLogEntry(
                id: "e1", exerciseName: "pullup",
                plannedSets: 1, plannedReps: "10",
                sets: [SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: 10, rpe: nil, isWarmup: false)],
                skipped: false, notes: nil
            )
        ]
        await service.evaluateCapstoneFromLog(userId: "u-1", history: history, bodyweightKg: 70)
        XCTAssertNotEqual(service.state(userId: "u-1").currentTrial?.capstoneState, .completed)
    }

    func testEvaluateCapstoneFromLogCompletesWhenWindowOpen() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        var aligned = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .aligned })!
        aligned = TrialCard(
            id: aligned.id, kind: aligned.kind, theme: aligned.theme,
            displayName: aligned.displayName, blurb: aligned.blurb,
            capstone: TrialCapstone(
                displayName: "Test",
                description: "Test",
                evaluation: .autoFromLog(.reps(5, exerciseName: "pullup"))
            )
        )
        service.pickCard(aligned, userId: "u-1")

        // Force capstone window open by directly mutating state.
        var state = service.state(userId: "u-1")
        state.currentTrial?.capstoneState = .windowOpen
        store.save(state, userId: "u-1")

        let history = [
            ExerciseLogEntry(
                id: "e1", exerciseName: "pullup",
                plannedSets: 1, plannedReps: "10",
                sets: [SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: 10, rpe: nil, isWarmup: false)],
                skipped: false, notes: nil
            )
        ]
        await service.evaluateCapstoneFromLog(userId: "u-1", history: history, bodyweightKg: 70)
        XCTAssertEqual(service.state(userId: "u-1").currentTrial?.capstoneState, .completed)
    }

    // MARK: - T6.6 equipTitle

    func testEquipTitleSetsEquippedField() {
        var state = TrialsState.empty
        let titleId = TitleID(path: .axis(.power), tier: .bronze)
        state.unlockedTitles = [titleId]
        store.save(state, userId: "u-1")

        service.equipTitle(titleId, userId: "u-1")
        XCTAssertEqual(service.state(userId: "u-1").equippedTitle, titleId)
    }

    func testEquipNilUnequips() {
        var state = TrialsState.empty
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
}
