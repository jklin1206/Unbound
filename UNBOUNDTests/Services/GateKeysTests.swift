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
        // Top gates (2026-07-09 retune): movement keys tightened onto the
        // widened skills-or-lifts pool - counts 4/5/6, required rank one tier
        // below the gate target capped at Vessel. Attribute keys unchanged.
        XCTAssertEqual(metrics(.sevenSeals),
                       [.attributesAtRank(count: 3, rank: .veteran), .movementsAtRank(count: 4, rank: .master)])
        XCTAssertEqual(metrics(.theThreshold),
                       [.attributesAtRank(count: 3, rank: .master), .movementsAtRank(count: 5, rank: .vessel)])

        // The final gate also adds the structural "prior gates cleared" meta-gate.
        XCTAssertEqual(metrics(.theLastGate),
                       [.gatesAnswered(7), .attributesAtRank(count: 3, rank: .master), .movementsAtRank(count: 6, rank: .vessel)])
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

    func testLastGateMetaGateDerivesFromHighestPassedRank() {
        let gatesKey = GateKeys.keys(for: .theLastGate).first { $0.metric == .gatesAnswered(7) }!

        // Ascendant confirmed → all seven prior gates were answered.
        let passing = FixtureGateKeyHistory(
            trialProgress: OverallRankTrialProgress(highestPassedRank: .ascendant, attempts: [])
        )
        XCTAssertTrue(GateKeys.clearedKeys(for: .theLastGate, history: passing, bodyweightKg: 80).contains(gatesKey.id))

        // Vessel confirmed → only six prior gates answered, so the final gate's
        // seven-gate meta-key stays unmet.
        let oneShort = FixtureGateKeyHistory(
            trialProgress: OverallRankTrialProgress(highestPassedRank: .vessel, attempts: [])
        )
        XCTAssertFalse(GateKeys.clearedKeys(for: .theLastGate, history: oneShort, bodyweightKg: 80).contains(gatesKey.id))
    }

    // Regression: the store trims `attempts` to a 50-entry tail. A player with
    // >50 lifetime attempts loses their early gate-pass records from the log,
    // but `gatesAnswered(7)` must still hold - it now reads the monotonic
    // `highestPassedRank`, never the trimmed log. Before the fix this was a
    // permanent, unrecoverable Last Gate lockout.
    func testLastGateMetaGateSurvivesAttemptLogTrimming() {
        let gatesKey = GateKeys.keys(for: .theLastGate).first { $0.metric == .gatesAnswered(7) }!

        // 50 recent FAILED attempts and not a single passing record: exactly the
        // shape the 50-cap leaves once early passes have scrolled out. Rank is
        // Ascendant (monotonic state never regressed).
        let trimmedLog = (0..<50).map { i in
            attempt(for: OverallRankTrialDefinitions.theLastGate, passed: false, salt: i)
        }
        let progress = OverallRankTrialProgress(highestPassedRank: .ascendant, attempts: trimmedLog)
        XCTAssertFalse(progress.attempts.contains(where: \.passed), "fixture models an all-failure trimmed tail")
        XCTAssertEqual(progress.answeredGateCount, 7, "answered count comes from highestPassedRank, not the log")

        let history = FixtureGateKeyHistory(trialProgress: progress)
        XCTAssertTrue(
            GateKeys.clearedKeys(for: .theLastGate, history: history, bodyweightKg: 80).contains(gatesKey.id),
            "gatesAnswered(7) must hold once Ascendant is confirmed, regardless of the trimmed attempt log"
        )
    }

    // The two former gate-count call sites - the `gatesAnswered` gate key
    // (GateKeys) and the Home deck tally (UnboundHomeView.passedGateCount) - now
    // read one source: OverallRankTrialProgress.answeredGateCount. Lock that they
    // agree across every rank.
    func testGatesAnsweredKeyAndHomeCountShareOneSource() {
        for rank in RankTitle.allCases {
            let progress = OverallRankTrialProgress(highestPassedRank: rank, attempts: [])
            // What UnboundHomeView.passedGateCount returns for this progress.
            let homeCount = progress.answeredGateCount
            let expected = min(rank.overallRankTrialOrder, 7)
            XCTAssertEqual(homeCount, expected, "answeredGateCount mismatch at \(rank)")

            let history = FixtureGateKeyHistory(trialProgress: progress)
            for count in 1...7 {
                let key = GateKeyDefinition(
                    id: "probe-\(count)", label: "", movementIds: [], metric: .gatesAnswered(count)
                )
                XCTAssertEqual(
                    history.satisfies(key, bodyweightKg: 80),
                    homeCount >= count,
                    "gatesAnswered(\(count)) must track answeredGateCount at \(rank)"
                )
            }
        }
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

    // MARK: - Widened movement pool (skills + every StrengthStandards-ranked lift)

    func testGateKeyMovementPoolCountsAccessoryFamilyAndRowAndCollapsesVariants() throws {
        // 80kg male. Two bench VARIANTS (must count once), barbell row, and two
        // curl VARIANTS (one accessory FAMILY, must count once) + a lat
        // pulldown (verticalPull family) - 6 logged standards, 4 movements.
        let bodyweight = 80.0
        let states = [
            loadedState("Bench Press", id: "exercise.bench-press", loadKg: 130),
            loadedState("Incline Bench Press", id: "exercise.incline-bench-press", loadKg: 120),
            loadedState("Barbell Row", id: "exercise.barbell-row", loadKg: 100),
            loadedState("Lat Pulldown", id: "exercise.lat-pulldown", loadKg: 80, template: .machineStrength),
            loadedState("Cable Curl", id: "exercise.cable-curl", loadKg: 40, template: .machineStrength),
            loadedState("EZ Bar Curl", id: "exercise.ez-bar-curl", loadKg: 52, template: .machineStrength)
        ]
        let pool = TrialReadinessService.gateKeyMovementTierPool(
            skillTiers: .empty,
            progressStates: states,
            bodyweightKg: bodyweight,
            sex: .male
        )

        XCTAssertEqual(pool.count, 4, "6 logged standards must dedupe to 4 canonical movements")

        // Tiers come from the SAME StrengthStandards math the rank library
        // shows; per identity the best variant wins.
        func expectedTier(_ key: String, _ loadKg: Double) throws -> RankTier {
            try XCTUnwrap(StrengthStandards.rank(
                liftKg: loadKg, bodyweightKg: bodyweight, exerciseKey: key, sex: .male
            ))
        }
        let expected = try [
            expectedTier("bench press", 130),      // best bench variant
            expectedTier("barbell row", 100),
            expectedTier("lat pulldown", 80),
            expectedTier("ez bar curl", 52)        // best curl-family variant
        ]
        XCTAssertEqual(pool.sorted(), expected.sorted())

        // The widened pool feeds the real key: sevenSeals' movement key (read
        // off the gate) turns only because the accessory family and barbell
        // row count - with the curl family removed the pool is one short, and
        // the surviving bench duplicate must not fill the gap.
        let key = try XCTUnwrap(GateKeys.keys(for: .sevenSeals).first {
            if case .movementsAtRank = $0.metric { return true }
            return false
        })
        XCTAssertTrue(FixtureGateKeyHistory(movementTiers: pool).satisfies(key, bodyweightKg: bodyweight))

        let withoutCurls = TrialReadinessService.gateKeyMovementTierPool(
            skillTiers: .empty,
            progressStates: states.filter { !$0.displayName.contains("Curl") },
            bodyweightKg: bodyweight,
            sex: .male
        )
        XCTAssertEqual(withoutCurls.count, 3)
        XCTAssertFalse(FixtureGateKeyHistory(movementTiers: withoutCurls).satisfies(key, bodyweightKg: bodyweight))
    }

    func testGateKeyMovementPoolFoldsSkillOwnedLoadedStandardsIntoTheSkill() {
        // Weighted pull-up is BOTH a loaded standard and a skill node; the
        // owning-skill join makes the skill the single rank source, so the
        // pair must count as ONE movement.
        let skillTiers = UserSkillTierState(
            perSkill: ["pp.weighted-pullup": .vessel],
            rankUpsEarned: 0,
            ascendantSkills: []
        )
        let pool = TrialReadinessService.gateKeyMovementTierPool(
            skillTiers: skillTiers,
            progressStates: [
                loadedState("Weighted Pull-Up", id: "exercise.weighted-pullup", loadKg: 40, template: .weightedBodyweight)
            ],
            bodyweightKg: 80,
            sex: .male
        )
        XCTAssertEqual(pool, [.vessel])
    }

    private func loadedState(
        _ displayName: String,
        id: String,
        loadKg: Double,
        template: MovementRankTemplate = .barbellStrength
    ) -> MovementProgressState {
        MovementProgressState(
            userId: "u1",
            rankStandardMovementId: id,
            displayName: displayName,
            rankTemplate: template,
            bestLoadKg: loadKg
        )
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

    private func attempt(
        for definition: OverallRankTrialDefinition,
        passed: Bool,
        salt: Int? = nil
    ) -> OverallRankTrialAttempt {
        let suffix = salt.map { "-\($0)" } ?? ""
        return OverallRankTrialAttempt(
            id: "\(definition.id)-attempt-\(passed)\(suffix)",
            userId: "u1",
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            performanceLogId: "\(definition.id)-log-\(passed)\(suffix)",
            passed: passed,
            movementAPGained: 0,
            overallLevelXPGained: 0
        )
    }

    private func readyEquipment() -> Set<MovementEquipment> {
        [.bodyweight, .openSpace, .dumbbell, .kettlebell, .band, .pullupBar, .cable, .machine, .cardioMachine]
    }
}
