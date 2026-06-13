import XCTest
@testable import UNBOUND

@MainActor
final class GateKeysTests: XCTestCase {
    func testForgeKeysClearFromWorkoutHistory() {
        let keys = GateKeys.keys(for: .theForging)
        XCTAssertEqual(keys.map(\.id), ["key-forge-pullups", "key-forge-hinge"])

        let history = WorkoutLogGateKeyHistory(
            workoutLogs: [
                workoutLog(entries: [
                    entry("Pull-Up", movementId: "exercise.pullup", reps: 3),
                    entry(
                        "Dumbbell Romanian Deadlift",
                        movementId: "exercise.dumbbell-romanian-deadlift",
                        rankStandardMovementId: "exercise.romanian-deadlift",
                        reps: 5,
                        weightKg: 100
                    )
                ])
            ],
            attributeProfile: nil,
            trialProgress: .empty
        )

        let cleared = GateKeys.clearedKeys(for: .theForging, history: history, bodyweightKg: 80)
        XCTAssertEqual(cleared, Set(keys.map(\.id)))
    }

    func testLoadedKeysRequireLoadAndRepsInOneSet() {
        let splitProof = FixtureGateKeyHistory(
            records: [
                record("exercise.romanian-deadlift", reps: 5, loadKg: 40),
                record("exercise.romanian-deadlift", reps: 1, loadKg: 100)
            ]
        )
        XCTAssertFalse(GateKeys.clearedKeys(for: .theForging, history: splitProof, bodyweightKg: 80).contains("key-forge-hinge"))

        let sameSetProof = FixtureGateKeyHistory(
            records: [record("exercise.romanian-deadlift", reps: 5, loadKg: 100)]
        )
        XCTAssertTrue(GateKeys.clearedKeys(for: .theForging, history: sameSetProof, bodyweightKg: 80).contains("key-forge-hinge"))
    }

    func testThresholdCarryUsesNormalCatalogCarryIds() {
        let history = FixtureGateKeyHistory(
            records: [record("carry.farmer-carry", reps: 100, loadKg: 30)]
        )

        let cleared = GateKeys.clearedKeys(for: .theThreshold, history: history, bodyweightKg: 100)
        XCTAssertTrue(cleared.contains("key-threshold-carry"))
    }

    func testAttributeFloorReadsAttributeProfile() {
        let passing = FixtureGateKeyHistory(attributeProfile: attributeProfile(level: 25))
        XCTAssertEqual(
            GateKeys.clearedKeys(for: .sevenSeals, history: passing, bodyweightKg: 80),
            Set(["key-seals-hexagon"])
        )

        var failingProfile = attributeProfile(level: 25)
        failingProfile.set(
            .mobility,
            AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 24), lastContributionAt: Date(timeIntervalSince1970: 100))
        )
        let failing = FixtureGateKeyHistory(attributeProfile: failingProfile)
        XCTAssertTrue(GateKeys.clearedKeys(for: .sevenSeals, history: failing, bodyweightKg: 80).isEmpty)
    }

    func testLastGateKeyUsesPassedGateAttempts() {
        let firstSeven = OverallRankTrialDefinitions.all.filter { $0.format != .theLastGate }
        let passing = FixtureGateKeyHistory(
            trialProgress: OverallRankTrialProgress(
                highestPassedRank: .ascendant,
                attempts: firstSeven.map { attempt(for: $0, passed: true) }
            )
        )
        XCTAssertEqual(
            GateKeys.clearedKeys(for: .theLastGate, history: passing, bodyweightKg: 80),
            Set(["key-lastgate-stamps"])
        )

        let oneMissing = FixtureGateKeyHistory(
            trialProgress: OverallRankTrialProgress(
                highestPassedRank: .vessel,
                attempts: firstSeven.dropLast().map { attempt(for: $0, passed: true) }
                    + [attempt(for: OverallRankTrialDefinitions.theThreshold, passed: false)]
            )
        )
        XCTAssertTrue(GateKeys.clearedKeys(for: .theLastGate, history: oneMissing, bodyweightKg: 80).isEmpty)
    }

    func testKeyLinesAppearInReadinessRequirements() {
        let definition = OverallRankTrialDefinitions.theForging
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel,
                aggregateRank: definition.targetRank,
                equipment: readyEquipment(),
                clearedGateKeys: ["key-forge-pullups"]
            )
        )

        let keyLines = readiness.requirements.filter { $0.kind == .gateKey }
        XCTAssertEqual(keyLines.map(\.id), ["key-forge-pullups", "key-forge-hinge"])
        XCTAssertEqual(keyLines.map(\.current), ["Proven", "Unproven"])
        XCTAssertEqual(keyLines.map(\.isMet), [true, false])
        XCTAssertEqual(readiness.status, .locked)
    }

    func testRequirementKindDecodesLegacyRequirementLinesAndGateKeyLines() throws {
        let legacyData = Data("""
        {"id":"rank","kind":"rank","label":"Accumulated rank","current":"Apprentice","required":"Forged","isMet":false}
        """.utf8)
        let legacy = try JSONDecoder().decode(OverallRankTrialRequirementLine.self, from: legacyData)
        XCTAssertEqual(legacy.kind, .rank)

        let gateKeyData = try JSONEncoder().encode(
            OverallRankTrialRequirementLine(
                id: "key-forge-pullups",
                kind: .gateKey,
                label: "3 strict pull-ups, one set",
                current: "Proven",
                required: "3 strict pull-ups, one set",
                isMet: true
            )
        )
        let gateKey = try JSONDecoder().decode(OverallRankTrialRequirementLine.self, from: gateKeyData)
        XCTAssertEqual(gateKey.kind, .gateKey)
    }

    func testEveryGateKeyMovementIdIsNonEmptyResolvableAndNotTrialLocal() {
        let forbidden = Set(["exercise.single-leg-rdl", "carry.loaded-march"])

        for format in RankTrialFormat.allCases {
            for key in GateKeys.keys(for: format) {
                XCTAssertFalse(key.movementIds.isEmpty, key.id)
                XCTAssertTrue(forbidden.isDisjoint(with: key.movementIds), key.id)

                for movementId in key.movementIds {
                    let definition = MovementCatalog.definition(for: movementId)
                    XCTAssertNotNil(definition, "\(key.id) lists unresolved movement id \(movementId)")
                    if let definition {
                        let resolved = MovementResolver.resolve(definition.displayName)
                        XCTAssertEqual(resolved.movementId, movementId, "\(definition.displayName) should resolve back to \(movementId)")
                    }
                }
            }
        }
    }

    private struct FixtureGateKeyHistory: GateKeyHistory {
        let gateKeySetRecords: [GateKeySetRecord]
        let gateKeyAttributeProfile: AttributeProfile?
        let gateKeyTrialProgress: OverallRankTrialProgress

        init(
            records: [GateKeySetRecord] = [],
            attributeProfile: AttributeProfile? = nil,
            trialProgress: OverallRankTrialProgress = .empty
        ) {
            self.gateKeySetRecords = records
            self.gateKeyAttributeProfile = attributeProfile
            self.gateKeyTrialProgress = trialProgress
        }
    }

    private func record(
        _ movementId: String,
        reps: Int = 0,
        loadKg: Double? = nil,
        holdSeconds: Int? = nil
    ) -> GateKeySetRecord {
        GateKeySetRecord(
            movementIds: [movementId],
            reps: reps,
            loadKg: loadKg,
            holdSeconds: holdSeconds,
            isProofEligible: true
        )
    }

    private func workoutLog(entries: [ExerciseLogEntry]) -> WorkoutLog {
        WorkoutLog(
            id: UUID().uuidString,
            userId: "u1",
            programId: "program-1",
            dayNumber: 1,
            plannedWorkoutName: "Gate Key Proof",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            exerciseEntries: entries
        )
    }

    private func entry(
        _ exerciseName: String,
        movementId: String,
        rankStandardMovementId: String? = nil,
        reps: Int,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil
    ) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: exerciseName,
            movementId: movementId,
            rankStandardMovementId: rankStandardMovementId,
            plannedSets: 1,
            plannedReps: "\(reps)",
            sets: [
                SetLog(
                    id: UUID().uuidString,
                    setNumber: 1,
                    weightKg: weightKg,
                    reps: reps,
                    rpe: 8,
                    isWarmup: false,
                    durationSeconds: durationSeconds,
                    qualityFlags: [],
                    notes: nil
                )
            ],
            skipped: false,
            notes: nil
        )
    }

    private func attributeProfile(level: Int) -> AttributeProfile {
        let date = Date(timeIntervalSince1970: 100)
        var profile = AttributeProfile.empty(userId: "u1", at: date)
        for key in AttributeKey.allCases {
            profile.set(
                key,
                AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: level), lastContributionAt: date)
            )
        }
        return profile
    }

    private func attempt(
        for definition: OverallRankTrialDefinition,
        passed: Bool
    ) -> OverallRankTrialAttempt {
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
        [
            .bodyweight,
            .openSpace,
            .dumbbell,
            .kettlebell,
            .band,
            .pullupBar,
            .cable,
            .machine,
            .cardioMachine
        ]
    }
}
