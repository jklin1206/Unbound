// UNBOUNDTests/Services/RankServiceAggregateTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class RankServiceAggregateTests: XCTestCase {
    func testMockAggregateRankReturnsOverride() async {
        let svc = MockRankService()
        svc.aggregateRankOverride = .master
        let rank = await svc.aggregateRank(userId: "u")
        XCTAssertEqual(rank, .master)
    }

    func testMockAggregateRankDefaultsToForged() async {
        let svc = MockRankService()
        let rank = await svc.aggregateRank(userId: "u")
        XCTAssertEqual(rank, .forged)
    }

    // MARK: - Barbell lift tiers feed the aggregate

    private func liftEntry(_ name: String, weightKg: Double?, reps: Int) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: "log-\(name)", exerciseName: name, movementId: nil,
            rankStandardMovementId: nil, plannedSets: 1, plannedReps: "\(reps)",
            sets: [SetLog(id: UUID().uuidString, setNumber: 1, weightKg: weightKg,
                          reps: reps, rpe: 8, isWarmup: false, durationSeconds: nil)],
            skipped: false, notes: nil
        )
    }

    /// A logged barbell compound now resolves to its canonical key and a real tier,
    /// so the overall-rank aggregate (which reads LiftTierService) finally counts it.
    /// Anchored to `StrengthStandards.rank` so balance retunes don't break the test.
    func testHeavyBenchProducesAboveInitiateBarbellTier() {
        let bw = 70.0, sex = BiologicalSex.male, liftKg = 100.0
        let tiers = RankService.shared.bestBarbellLiftTiers(
            history: [liftEntry("Bench Press", weightKg: liftKg, reps: 1)],
            bodyweightKg: bw, sex: sex
        )
        let expected = StrengthStandards.rank(
            liftKg: liftKg, bodyweightKg: bw, exerciseKey: "bench press", sex: sex
        )
        XCTAssertNotNil(expected)
        XCTAssertEqual(tiers["bench press"], expected)
        XCTAssertGreaterThan(
            (expected ?? .initiate).rawValue, SkillTier.initiate.rawValue,
            "A heavy bench must rank above Initiate — the whole point of wiring lifts in."
        )
    }

    /// Bodyweight movements must NOT bucket into the barbell-compound aggregate.
    func testBodyweightMovementDoesNotEnterBarbellAggregate() {
        let tiers = RankService.shared.bestBarbellLiftTiers(
            history: [liftEntry("Pull-Up", weightKg: nil, reps: 15)],
            bodyweightKg: 70.0, sex: .male
        )
        XCTAssertTrue(tiers.isEmpty, "Bodyweight movements must not populate barbell lift tiers")
    }
}
