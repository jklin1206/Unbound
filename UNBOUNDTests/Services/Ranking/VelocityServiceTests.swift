import XCTest
@testable import UNBOUND

@MainActor
final class VelocityServiceTests: XCTestCase {

    // MARK: Fixtures

    private func gain(
        _ definition: MovementDefinition,
        rawAP: Double,
        sourceLogId: String
    ) -> MovementAPGain {
        MovementAPGain(
            userId: "u",
            sourceLogId: sourceLogId,
            sourceExerciseId: nil,
            movementId: definition.id,
            rankStandardMovementId: definition.rankStandardMovementId,
            movementDisplayName: definition.displayName,
            standardDisplayName: definition.displayName,
            rankTemplate: definition.rankTemplate,
            rawAP: rawAP,
            occurredAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    /// Hardest available compound movement (skill + compound both elevated).
    private func veteranMovement() -> MovementDefinition? {
        MovementCatalog.definitions.first {
            $0.difficulty == .elite && $0.muscleGroups.count >= 2
        }
    }

    /// Easiest available isolation movement (skill + compound both baseline).
    private func beginnerMovement() -> MovementDefinition? {
        MovementCatalog.definitions.first {
            $0.difficulty == .beginner && $0.muscleGroups.count == 1
        }
    }

    // MARK: - Cohort proof: equal volume must diverge in LV

    func testVeteranAndBeginnerAtEqualVolumeDivergeInLV() async throws {
        guard let vetMove = veteranMovement(), let begMove = beginnerMovement() else {
            return XCTFail("Catalog must contain an elite-compound and a beginner-isolation movement")
        }

        // Equal *volume*: same number of sets at the same raw AP per set.
        let vetGains = (0..<3).map { gain(vetMove, rawAP: 30, sourceLogId: "vet-\($0)") }
        let begGains = (0..<3).map { gain(begMove, rawAP: 30, sourceLogId: "beg-\($0)") }
        XCTAssertEqual(
            vetGains.reduce(0) { $0 + $1.rawAP },
            begGains.reduce(0) { $0 + $1.rawAP },
            accuracy: 0.001,
            "Personas must have identical training volume for the proof to be honest"
        )

        let service = OverallLevelService.shared
        let database = MockDatabaseService()
        let t = Date(timeIntervalSince1970: 2_000)

        // BEFORE (the bug): the flat scalar path credits volume only, so equal
        // volume → identical LV. Ability is invisible.
        let vetFlat = await service.ingest(
            rawAP: 90, noveltyMultiplier: 1.0, sourceLogId: "vet-flat",
            userId: "vetFlat", at: t, database: database
        )
        let begFlat = await service.ingest(
            rawAP: 90, noveltyMultiplier: 1.0, sourceLogId: "beg-flat",
            userId: "begFlat", at: t, database: database
        )
        XCTAssertEqual(vetFlat.xpGained, begFlat.xpGained, accuracy: 0.001,
                       "Flat volume path: ability is invisible (this is the bug we fix)")

        // AFTER (velocity layer): the same volume, weighted by skill + compound,
        // now diverges — the veteran's harder work earns more LV.
        let vetWeighted = await service.ingest(
            rawAP: 90, noveltyMultiplier: 1.0, sourceLogId: "vet-w",
            userId: "vetW", at: t, gains: vetGains, database: database
        )
        let begWeighted = await service.ingest(
            rawAP: 90, noveltyMultiplier: 1.0, sourceLogId: "beg-w",
            userId: "begW", at: t, gains: begGains, database: database
        )

        XCTAssertGreaterThan(vetWeighted.xpGained, begWeighted.xpGained,
                             "Velocity layer: ability is now visible at equal volume")

        // Integration matches the pure weighting function exactly.
        let expectedVet = RewardLedgerQuantizer.wholePoints(from: VelocityWeighting.weightedAP(gains: vetGains))
        let expectedBeg = RewardLedgerQuantizer.wholePoints(from: VelocityWeighting.weightedAP(gains: begGains))
        XCTAssertEqual(vetWeighted.xpGained, expectedVet, accuracy: 0.001)
        XCTAssertEqual(begWeighted.xpGained, expectedBeg, accuracy: 0.001)
        // Beginner-isolation has unit multipliers → weighted == flat volume.
        XCTAssertEqual(begWeighted.xpGained, 90, accuracy: 0.001)
    }

    // MARK: - Per-lever unit tests

    func testSkillMultiplierIncreasesWithDifficulty() {
        let beginner = VelocityWeighting.skillMultiplier(for: .beginner)
        let intermediate = VelocityWeighting.skillMultiplier(for: .intermediate)
        let advanced = VelocityWeighting.skillMultiplier(for: .advanced)
        let elite = VelocityWeighting.skillMultiplier(for: .elite)
        XCTAssertEqual(beginner, 1.0, accuracy: 0.001)
        XCTAssertLessThan(beginner, intermediate)
        XCTAssertLessThan(intermediate, advanced)
        XCTAssertLessThan(advanced, elite)
    }

    func testCompoundMultiplierRewardsCompound() {
        XCTAssertGreaterThan(
            VelocityWeighting.compoundMultiplier(isCompound: true),
            VelocityWeighting.compoundMultiplier(isCompound: false)
        )
        XCTAssertEqual(VelocityWeighting.compoundMultiplier(isCompound: false), 1.0, accuracy: 0.001)
    }

    func testComebackMultiplierIsNeutralWhenFreshAndCapsWhenStale() {
        XCTAssertEqual(VelocityWeighting.comebackMultiplier(daysSinceLastSession: 0), 1.0, accuracy: 0.001)
        XCTAssertEqual(VelocityWeighting.comebackMultiplier(daysSinceLastSession: 2.9), 1.0, accuracy: 0.001)
        let mid = VelocityWeighting.comebackMultiplier(daysSinceLastSession: 5)
        let longer = VelocityWeighting.comebackMultiplier(daysSinceLastSession: 20)
        let capped = VelocityWeighting.comebackMultiplier(daysSinceLastSession: 400)
        XCTAssertGreaterThan(mid, 1.0)
        XCTAssertGreaterThan(longer, mid)
        XCTAssertEqual(capped, 1.25, accuracy: 0.001)
    }

    func testRankUpBolusScalesWithCrossings() {
        XCTAssertEqual(VelocityWeighting.rankUpBolus(rankUpEvents: 0), 0, accuracy: 0.001)
        XCTAssertEqual(
            VelocityWeighting.rankUpBolus(rankUpEvents: 2),
            2 * VelocityWeighting.bolusPerRankUp,
            accuracy: 0.001
        )
        XCTAssertEqual(VelocityWeighting.rankUpBolus(rankUpEvents: -5), 0, accuracy: 0.001)
    }

    func testRankUpBolusIsAddedToLVAndIsIdempotent() async {
        let service = OverallLevelService.shared
        let database = MockDatabaseService()
        let t = Date(timeIntervalSince1970: 5_000)

        // No volume, one rank-up → bolus-only LV gain.
        let reward = await service.ingest(
            rawAP: 0, noveltyMultiplier: 1.0, sourceLogId: "bolus-1",
            userId: "bolusUser", at: t, rankUpEvents: 1, database: database
        )
        XCTAssertEqual(reward.xpGained, VelocityWeighting.bolusPerRankUp, accuracy: 0.001)

        // Re-ingesting the same source must not double-grant.
        let duplicate = await service.ingest(
            rawAP: 0, noveltyMultiplier: 1.0, sourceLogId: "bolus-1",
            userId: "bolusUser", at: t, rankUpEvents: 1, database: database
        )
        XCTAssertEqual(duplicate.xpGained, 0, accuracy: 0.001)
    }

    func testWeightedAPIsZeroForEmptySession() {
        XCTAssertEqual(VelocityWeighting.weightedAP(gains: []), 0, accuracy: 0.001)
    }
}
