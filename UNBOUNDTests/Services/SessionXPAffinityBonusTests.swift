// UNBOUNDTests/Services/SessionXPAffinityBonusTests.swift
import XCTest
@testable import UNBOUND

// MARK: - Test doubles

@MainActor
private final class StubSquadService: SquadServiceProtocol {
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

/// Catalog that routes any exercise name to a fixed contribution.
private final class FixedCatalog: AttributeCatalogProtocol {
    let contribution: AttributeContribution
    init(dominant: AttributeKey) {
        // Dominant axis gets weight 1.0; all others 0.
        contribution = AttributeContribution(weights: [dominant: 1.0])
    }
    func contribution(forExerciseName name: String) -> AttributeContribution { contribution }
    func contribution(forSkillNodeId id: String) -> AttributeContribution { contribution }
}

// MARK: - Helpers

/// Minimal non-empty WorkoutLog (one exercise entry with one non-warmup set).
private func makeLog(userId: String = "user1") -> WorkoutLog {
    let set = SetLog(id: UUID().uuidString, setNumber: 1, weightKg: 100, reps: 5, rpe: 8, isWarmup: false)
    let entry = ExerciseLogEntry(
        id: UUID().uuidString,
        exerciseName: "back squat",
        plannedSets: 3,
        plannedReps: "5",
        sets: [set],
        skipped: false
    )
    return WorkoutLog(
        id: UUID().uuidString,
        userId: userId,
        programId: "prog1",
        dayNumber: 1,
        plannedWorkoutName: "Day A",
        startedAt: Date(),
        completedAt: Date(),
        exerciseEntries: [entry],
        overallRPE: 8
    )
}

private func makeSquad(affinityAxis: AttributeKey?) -> Squad {
    Squad(
        id: UUID(),
        name: "Test Squad",
        captainId: UUID(),
        affinityAxis: affinityAxis,
        affinitySetAt: affinityAxis != nil ? Date() : nil,
        inviteCode: "TSTCOD",
        maxSize: 8,
        squadStreakWeeks: 0,
        createdAt: Date()
    )
}

// MARK: - SessionXPAffinityBonusTests

@MainActor
final class SessionXPAffinityBonusTests: XCTestCase {

    private var mockXP: MockSessionXPService!
    private var squadService: StubSquadService!
    private let userId = "user1"

    override func setUp() {
        super.setUp()
        mockXP = MockSessionXPService()
        squadService = StubSquadService()
    }

    // MARK: 1 — +10% applied when squad affinity matches session dominant axis

    func testAffinityBonusAppliedWhenAxisMatches() async {
        // Squad has affinity .power; catalog returns dominant = .power.
        let squad = makeSquad(affinityAxis: .power)
        squadService.stubbedState = SquadState(
            currentSquad: squad, roster: [], activeRosterPresence: [], recentActivity: [], unlockedSquadTitles: []
        )
        let catalog = FixedCatalog(dominant: .power)
        let log = makeLog(userId: userId)

        await mockXP.recordSessionWithAffinity(
            userId: userId, at: Date(), log: log, catalog: catalog, squadService: squadService
        )

        // Should have exactly one bonus call with reason "affinity" and amount 1 (+10% of base 10).
        let affinityBonus = mockXP.bonusCalls.first(where: { $0.reason == "affinity" })
        XCTAssertNotNil(affinityBonus, "Expected an affinity bonus call")
        XCTAssertEqual(affinityBonus?.amount, 1)   // 10% of baseXP(10) = 1
    }

    // MARK: 2 — No bonus when user has no squad

    func testNoAffinityBonusWhenNoSquad() async {
        // stubbedState defaults to .empty (no squad).
        let catalog = FixedCatalog(dominant: .power)
        let log = makeLog(userId: userId)

        await mockXP.recordSessionWithAffinity(
            userId: userId, at: Date(), log: log, catalog: catalog, squadService: squadService
        )

        XCTAssertTrue(
            mockXP.bonusCalls.filter { $0.reason == "affinity" }.isEmpty,
            "Expected no affinity bonus when user has no squad"
        )
    }

    // MARK: 3 — No bonus when squad has nil affinity

    func testNoAffinityBonusWhenSquadAffinityIsNil() async {
        let squad = makeSquad(affinityAxis: nil)   // no affinity set
        squadService.stubbedState = SquadState(
            currentSquad: squad, roster: [], activeRosterPresence: [], recentActivity: [], unlockedSquadTitles: []
        )
        let catalog = FixedCatalog(dominant: .power)
        let log = makeLog(userId: userId)

        await mockXP.recordSessionWithAffinity(
            userId: userId, at: Date(), log: log, catalog: catalog, squadService: squadService
        )

        XCTAssertTrue(
            mockXP.bonusCalls.filter { $0.reason == "affinity" }.isEmpty,
            "Expected no affinity bonus when squad has nil affinity"
        )
    }

    // MARK: 4 — No bonus when session dominant axis differs from affinity

    func testNoAffinityBonusWhenAxisMismatch() async {
        // Squad affinity = .endurance; session dominant = .power → no match.
        let squad = makeSquad(affinityAxis: .endurance)
        squadService.stubbedState = SquadState(
            currentSquad: squad, roster: [], activeRosterPresence: [], recentActivity: [], unlockedSquadTitles: []
        )
        let catalog = FixedCatalog(dominant: .power)   // session is power-dominant
        let log = makeLog(userId: userId)

        await mockXP.recordSessionWithAffinity(
            userId: userId, at: Date(), log: log, catalog: catalog, squadService: squadService
        )

        XCTAssertTrue(
            mockXP.bonusCalls.filter { $0.reason == "affinity" }.isEmpty,
            "Expected no affinity bonus when session axis mismatches squad affinity"
        )
    }

    // MARK: 5 — +20% linked supersedes +10% affinity (net == +20% from base)
    //
    // Scenario: affinity bonus was already applied (+10% of baseXP = 1 unit).
    // LinkedSessionEvaluator should add (20% of base) − (affinity already applied)
    // = 2 − 1 = 1 extra unit, so cumulative total from bonuses = 2 units (+20% of 10).

    func testLinkedSupersedes_affinityNetTwentyPercent() async {
        // Simulate: affinity bonus of 1 already applied.
        mockXP.stubbedAffinityBonus = 1

        let baseXP = 10   // matches the base unit used by recordSessionWithAffinity

        await LinkedSessionEvaluator.applyLinkedXPBonus(
            userId: userId,
            sessionXPDelta: baseXP,
            service: mockXP
        )

        let linkedCall = mockXP.bonusCalls.first(where: { $0.reason == "linkedSession" })
        XCTAssertNotNil(linkedCall, "Expected a linkedSession bonus call")

        // +20% of base = 2; minus affinity already applied (1) = net 1 extra unit.
        // Total bonus from both = 1 (affinity) + 1 (linked net) = 2 = +20% of 10.
        XCTAssertEqual(linkedCall?.amount, 1,
            "Net linked bonus should be 1 (= +20% base - +10% already applied)")
    }
}
