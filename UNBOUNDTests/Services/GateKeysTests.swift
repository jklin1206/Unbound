import XCTest
@testable import UNBOUND

@MainActor
final class GateKeysTests: XCTestCase {

    // MARK: - The any-K-attribute ladder

    func testGateKeyLadderShapePerFormat() {
        func metrics(_ format: RankTrialFormat) -> [GateKeyMetric] {
            GateKeys.keys(for: format).map(\.metric)
        }
        XCTAssertTrue(GateKeys.keys(for: .firstLight).isEmpty)   // level only
        // Each mid gate carries one attribute key + one light "any N movements" key.
        XCTAssertEqual(metrics(.theCount),
                       [.attributesAtRank(count: 1, rank: .novice), .movementsAtRank(count: 2, rank: .novice)])
        XCTAssertEqual(metrics(.theForging),
                       [.attributesAtRank(count: 1, rank: .apprentice), .movementsAtRank(count: 2, rank: .apprentice)])
        XCTAssertEqual(metrics(.deckOfProof),
                       [.attributesAtRank(count: 2, rank: .forged), .movementsAtRank(count: 3, rank: .forged)])
        XCTAssertEqual(metrics(.theAscent),
                       [.attributesAtRank(count: 2, rank: .veteran), .movementsAtRank(count: 3, rank: .veteran)])
        XCTAssertEqual(metrics(.sevenSeals),
                       [.attributesAtRank(count: 3, rank: .veteran), .movementsAtRank(count: 3, rank: .veteran)])
        XCTAssertEqual(metrics(.theThreshold),
                       [.attributesAtRank(count: 3, rank: .master), .movementsAtRank(count: 4, rank: .master)])

        // The final gate also adds the structural "prior gates cleared" meta-gate.
        XCTAssertEqual(metrics(.theLastGate),
                       [.gatesAnswered(7), .attributesAtRank(count: 3, rank: .master), .movementsAtRank(count: 4, rank: .master)])
    }

    // MARK: - "Any K attributes at rank R"

    func testAttributesKeyClearsWithEnoughAttributesAtRank() {
        // sevenSeals = any 3 attributes at Veteran (attribute level 15).
        let key = GateKeys.keys(for: .sevenSeals)[0]
        let met = FixtureGateKeyHistory(attributeProfile: profile(attributesAtLevel: 15, count: 3))
        XCTAssertTrue(GateKeys.clearedKeys(for: .sevenSeals, history: met, bodyweightKg: 80).contains(key.id))
    }

    func testAttributesKeyFailsBelowK() {
        // Only 2 attributes at Veteran — short of the "any 3" bar.
        let key = GateKeys.keys(for: .sevenSeals)[0]
        let short = FixtureGateKeyHistory(attributeProfile: profile(attributesAtLevel: 15, count: 2))
        XCTAssertFalse(GateKeys.clearedKeys(for: .sevenSeals, history: short, bodyweightKg: 80).contains(key.id))
    }

    func testAttributesKeyIsBuildAgnostic_anyAxesCount() {
        // theAscent = any 2 at Veteran. It shouldn't matter WHICH 2.
        let key = GateKeys.keys(for: .theAscent)[0]
        // Last two axes high, the rest at zero — still satisfies "any 2".
        let date = Date(timeIntervalSince1970: 100)
        var p = AttributeProfile.empty(userId: "u1", at: date)
        for axis in [AttributeKey.mobility, .explosiveness] {
            p.set(axis, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 15), lastContributionAt: date))
        }
        let history = FixtureGateKeyHistory(attributeProfile: p)
        XCTAssertTrue(GateKeys.clearedKeys(for: .theAscent, history: history, bodyweightKg: 80).contains(key.id))
    }

    func testAttributesKeyNeedsAProfile() {
        let key = GateKeys.keys(for: .theCount)[0]
        let none = FixtureGateKeyHistory(attributeProfile: nil)
        XCTAssertFalse(GateKeys.clearedKeys(for: .theCount, history: none, bodyweightKg: 80).contains(key.id))
    }

    // MARK: - Final-gate structural meta-gate (prior 7 cleared)

    func testLastGateMetaGateUsesPassedGateAttempts() {
        let gatesKey = GateKeys.keys(for: .theLastGate).first { $0.metric == .gatesAnswered(7) }!
        let firstSeven = OverallRankTrialDefinitions.all.filter { $0.format != .theLastGate }

        let passing = FixtureGateKeyHistory(
            trialProgress: OverallRankTrialProgress(
                highestPassedRank: .ascendant,
                attempts: firstSeven.map { attempt(for: $0, passed: true) }
            )
        )
        XCTAssertTrue(GateKeys.clearedKeys(for: .theLastGate, history: passing, bodyweightKg: 80).contains(gatesKey.id))

        let oneMissing = FixtureGateKeyHistory(
            trialProgress: OverallRankTrialProgress(
                highestPassedRank: .vessel,
                attempts: firstSeven.dropLast().map { attempt(for: $0, passed: true) }
                    + [attempt(for: OverallRankTrialDefinitions.theThreshold, passed: false)]
            )
        )
        XCTAssertFalse(GateKeys.clearedKeys(for: .theLastGate, history: oneMissing, bodyweightKg: 80).contains(gatesKey.id))
    }

    // MARK: - Readiness wiring (attribute key shows; accumulated-rank is gone)

    func testAttributeKeyLineAppearsInReadiness_andAccumulatedRankIsGone() {
        let definition = OverallRankTrialDefinitions.theForging
        let keyIds = GateKeys.keys(for: .theForging).map(\.id)
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel,
                aggregateRank: definition.targetRank,
                equipment: readyEquipment(),
                clearedGateKeys: Set(keyIds)
            )
        )

        let keyLines = readiness.requirements.filter { $0.kind == .gateKey }
        // theForging now carries an attribute key + a light movements key; both show, both met.
        XCTAssertEqual(Set(keyLines.map(\.id)), Set(keyIds))
        XCTAssertTrue(keyLines.allSatisfy(\.isMet))
        // Accumulated-rank line was folded out of the gate.
        XCTAssertFalse(readiness.requirements.contains { $0.id == "accumulated-rank" })
        // Level + equipment + both gate keys met → ready.
        XCTAssertEqual(readiness.status, .ready)
    }

    func testRequirementKindDecodesLegacyRankAndGateKeyLines() throws {
        let legacy = try JSONDecoder().decode(
            OverallRankTrialRequirementLine.self,
            from: Data(#"{"id":"rank","kind":"rank","label":"x","current":"a","required":"b","isMet":false}"#.utf8)
        )
        XCTAssertEqual(legacy.kind, .rank)

        let encoded = try JSONEncoder().encode(
            OverallRankTrialRequirementLine(
                id: "key-attrs-3-master", kind: .gateKey,
                label: "Any 3 attributes at Master", current: "Unproven",
                required: "Any 3 attributes at Master", isMet: false
            )
        )
        XCTAssertEqual(try JSONDecoder().decode(OverallRankTrialRequirementLine.self, from: encoded).kind, .gateKey)
    }

    // MARK: - movementsAtRank gate key

    func testMovementsAtRankKeyCountsProvenMovements() {
        // Read the real key off a gate so the assertion tracks whatever the
        // balance table says (count/rank), not a hardcoded number.
        guard let key = GateKeys.keys(for: .deckOfProof).first(where: {
            if case .movementsAtRank = $0.metric { return true }
            return false
        }), case .movementsAtRank(let count, let rank) = key.metric else {
            return XCTFail("deckOfProof should carry a movementsAtRank key")
        }

        let justEnough = FixtureGateKeyHistory(movementTiers: Array(repeating: rank, count: count))
        let oneShort = FixtureGateKeyHistory(movementTiers: Array(repeating: rank, count: max(0, count - 1)))
        let higherTiersAlsoCount = FixtureGateKeyHistory(movementTiers: Array(repeating: .unbound, count: count))
        let belowRankDoesNotCount = FixtureGateKeyHistory(movementTiers: Array(repeating: .initiate, count: count + 2))

        XCTAssertTrue(justEnough.satisfies(key, bodyweightKg: 70))
        XCTAssertFalse(oneShort.satisfies(key, bodyweightKg: 70))
        XCTAssertTrue(higherTiersAlsoCount.satisfies(key, bodyweightKg: 70))
        XCTAssertFalse(belowRankDoesNotCount.satisfies(key, bodyweightKg: 70))
    }

    // MARK: - Fixtures

    private struct FixtureGateKeyHistory: GateKeyHistory {
        let gateKeySetRecords: [GateKeySetRecord]
        let gateKeyAttributeProfile: AttributeProfile?
        let gateKeyTrialProgress: OverallRankTrialProgress
        let gateKeyMovementTiers: [RankTier]

        init(
            attributeProfile: AttributeProfile? = nil,
            trialProgress: OverallRankTrialProgress = .empty,
            movementTiers: [RankTier] = []
        ) {
            self.gateKeySetRecords = []
            self.gateKeyAttributeProfile = attributeProfile
            self.gateKeyTrialProgress = trialProgress
            self.gateKeyMovementTiers = movementTiers
        }
    }

    /// A profile with the first `count` attributes raised to `level`, the rest at 0.
    private func profile(attributesAtLevel level: Int, count: Int) -> AttributeProfile {
        let date = Date(timeIntervalSince1970: 100)
        var p = AttributeProfile.empty(userId: "u1", at: date)
        for (i, key) in AttributeKey.allCases.enumerated() {
            let lvl = i < count ? level : 0
            p.set(key, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: lvl), lastContributionAt: date))
        }
        return p
    }

    private func attempt(for definition: OverallRankTrialDefinition, passed: Bool) -> OverallRankTrialAttempt {
        OverallRankTrialAttempt(
            id: "\(definition.id)-attempt-\(passed)",
            userId: "u1",
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            performanceLogId: "\(definition.id)-log-\(passed)",
            passed: passed,
            movementAPGained: 0,
            overallLevelXPGained: 0
        )
    }

    private func readyEquipment() -> Set<MovementEquipment> {
        [.bodyweight, .openSpace, .dumbbell, .kettlebell, .band, .pullupBar, .cable, .machine, .cardioMachine]
    }
}
