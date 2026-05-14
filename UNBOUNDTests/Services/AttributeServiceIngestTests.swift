// UNBOUNDTests/Services/AttributeServiceIngestTests.swift
import XCTest
@testable import UNBOUND

final class AttributeServiceIngestTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func stubCatalog(_ entries: [String: AttributeContribution]) -> AttributeCatalogProtocol {
        StubAttributeCatalog(byName: entries)
    }

    func testSingleHeavySquatSessionMovesPowerDominantly() {
        let catalog = stubCatalog([
            "barbell_back_squat": AttributeContribution(weights: [.power: 0.7, .endurance: 0.2, .control: 0.1])
        ])
        let log = WorkoutLog(
            id: "w1", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Heavy Lower",
            startedAt: t0, completedAt: t0.addingTimeInterval(45 * 60),
            exerciseEntries: [
                ExerciseLogEntry(id: "e1", exerciseName: "barbell_back_squat",
                    plannedSets: 5, plannedReps: "5",
                    sets: [SetLog(id: "s1", setNumber: 1, weightKg: 100, reps: 5, rpe: 8, isWarmup: false)],
                    skipped: false, notes: nil)
            ],
            overallNotes: nil, overallRPE: 8, durationMinutes: 45
        )

        let deltas = AttributeIngest.deltas(for: log, catalog: catalog)

        XCTAssertGreaterThan(deltas[.power] ?? 0, 0)
        XCTAssertGreaterThan(deltas[.power] ?? 0, deltas[.endurance] ?? 0)
        XCTAssertGreaterThan(deltas[.endurance] ?? 0, deltas[.control] ?? 0)
        XCTAssertEqual(deltas[.mobility] ?? 0, 0)
    }

    func testEmptySessionYieldsZeroDeltas() {
        let catalog = stubCatalog([:])
        let log = WorkoutLog(
            id: "w2", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Empty", startedAt: t0, completedAt: t0,
            exerciseEntries: [], overallNotes: nil, overallRPE: nil, durationMinutes: 0
        )
        let deltas = AttributeIngest.deltas(for: log, catalog: catalog)
        for key in AttributeKey.allCases {
            XCTAssertEqual(deltas[key] ?? 0, 0)
        }
    }

    func testApplyDeltasLiftsPeakWhenCurrentExceedsPeak() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 25], at: t0)
        XCTAssertEqual(p.value(for: .power).current, 25, accuracy: 0.001)
        XCTAssertEqual(p.value(for: .power).peak,    25, accuracy: 0.001)
        // 0 → 25 crosses several sub-ranks and a tier (initiate → apprentice).
        // We assert at least one crossing is emitted on .power axis — the exact
        // count depends on the SubRank/RankTitle table, but it must be > 0.
        XCTAssertGreaterThan(crossings.count, 0)
        XCTAssertTrue(crossings.allSatisfy { $0.axis == .power })
    }

    func testApplyDeltasClampsCurrentAt100() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(peak: 95, current: 95, lastContributionAt: t0))
        _ = AttributeIngest.applyDeltas(&p, deltas: [.power: 50], at: t0)
        XCTAssertEqual(p.value(for: .power).current, 100, accuracy: 0.001)
        XCTAssertEqual(p.value(for: .power).peak,    100, accuracy: 0.001)
    }

    func testApplyDeltasEmitsTierEventOnCrossingApprenticeToForged() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(peak: 50, current: 29, lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 8], at: t0)
        XCTAssertEqual(crossings.count, 1)
        XCTAssertEqual(crossings.first?.axis, .power)
        XCTAssertEqual(crossings.first?.level, .tier)
    }

    func testApplyDeltasEmitsATierEventOnCrossingHonedToVessel() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(peak: 80, current: 64, lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 10], at: t0)
        XCTAssertEqual(crossings.first?.level, .aTier)
    }

    func testApplyDeltasEmitsSubRankEventOnIntraTierStep() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(peak: 50, current: 0, lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 6], at: t0)
        XCTAssertEqual(crossings.first?.level, .subRank)
    }

    func testFirstBuildIdentityResolvedTransitionDetectable() {
        // Verify the transition pattern that AttributeService.ingest depends on:
        // starting from empty (balancedAthlete), adding enough to a single axis
        // flips the shape. End-to-end badge-fire test requires a mock
        // BadgeService — that's out of scope here; this validates the structural
        // precondition.
        var p = AttributeProfile.empty(userId: "u", at: t0)
        XCTAssertEqual(p.buildIdentity.shape, .balancedAthlete)

        // Push power past balanced threshold: spread = 16 escapes balanced.
        _ = AttributeIngest.applyDeltas(&p, deltas: [.power: 16], at: t0)
        XCTAssertNotEqual(p.buildIdentity.shape, .balancedAthlete)
    }

    func testSkippedExerciseProducesNoDeltas() {
        let catalog = stubCatalog([
            "barbell_back_squat": AttributeContribution(weights: [.power: 0.7, .endurance: 0.2, .control: 0.1])
        ])
        let log = WorkoutLog(
            id: "w3", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Aborted Lower",
            startedAt: t0, completedAt: t0.addingTimeInterval(10 * 60),
            exerciseEntries: [
                ExerciseLogEntry(id: "e1", exerciseName: "barbell_back_squat",
                    plannedSets: 5, plannedReps: "5",
                    // User logged one warmup set then hit skip.
                    sets: [SetLog(id: "s1", setNumber: 1, weightKg: 60, reps: 5, rpe: 6, isWarmup: false)],
                    skipped: true, notes: "left gym early")
            ],
            overallNotes: nil, overallRPE: 6, durationMinutes: 10
        )
        let deltas = AttributeIngest.deltas(for: log, catalog: catalog)
        for key in AttributeKey.allCases {
            XCTAssertEqual(deltas[key] ?? 0, 0, accuracy: 0.001,
                "Skipped exercise must not contribute on axis \(key)")
        }
    }
}

// Test helper
final class StubAttributeCatalog: AttributeCatalogProtocol {
    var byName: [String: AttributeContribution]
    init(byName: [String: AttributeContribution]) { self.byName = byName }
    func contribution(forExerciseName name: String) -> AttributeContribution {
        byName[name] ?? .zero
    }
    func contribution(forSkillNodeId id: String) -> AttributeContribution {
        byName[id] ?? .zero
    }
}
