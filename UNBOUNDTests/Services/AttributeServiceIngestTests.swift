// UNBOUNDTests/Services/AttributeServiceIngestTests.swift
import XCTest
@testable import UNBOUND

final class AttributeServiceIngestTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func stubCatalog(
        _ entries: [String: AttributeContribution],
        movements: [String: AttributeContribution] = [:]
    ) -> AttributeCatalogProtocol {
        StubAttributeCatalog(byName: entries, byMovement: movements)
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

    func testApplyDeltasConvertsDeltaToPermanentXP() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        // delta 25 × sessionDeltaXPScale(50) = 1_250 xp → L8 (base=16: 16·64=1_024 ≤ 1_250 < 16·81=1_296).
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 25], at: t0)
        XCTAssertEqual(p.value(for: .power).xp, 1_250, accuracy: 0.001)
        XCTAssertEqual(p.value(for: .power).level, 8)
        // 0 → L8 crosses tiers (initiate → apprentice) — at least one event.
        XCTAssertGreaterThan(crossings.count, 0)
        XCTAssertTrue(crossings.allSatisfy { $0.axis == .power })
    }

    func testApplyDeltasAccumulatesXP() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(xp: 100, lastContributionAt: t0))
        _ = AttributeIngest.applyDeltas(&p, deltas: [.power: 50], at: t0)
        // 100 + 50 × 50 = 2_600 xp.
        XCTAssertEqual(p.value(for: .power).xp, 2_600, accuracy: 0.001)
    }

    func testApplyDeltasEmitsTierEventOnCrossingApprenticeToForged() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        // Seed at L9 (base=16: 16·81 = 1_296, apprentice band L6..9). delta 8 × 50 = 400 → 1_696 xp → L10 = forged.
        p.set(.power, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 9), lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 8], at: t0)
        XCTAssertEqual(crossings.count, 1)
        XCTAssertEqual(crossings.first?.axis, .power)
        XCTAssertEqual(crossings.first?.toTitle, .forged)
        XCTAssertEqual(crossings.first?.level, .tier)
    }

    func testApplyDeltasEmitsATierEventOnCrossingMasterToVessel() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        // Seed at L39 (base=16: 16·1_521 = 24_336, master band L25..39). delta 30 × 50 = 1_500 → 25_836 → L40 = vessel.
        p.set(.power, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 39), lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 30], at: t0)
        XCTAssertEqual(crossings.first?.toTitle, .vessel)
        XCTAssertEqual(crossings.first?.level, .aTier)
    }

    func testApplyDeltasEmitsNoEventForIntraTierStep() {
        // A small delta that stays inside one RankTitle band fires no rank-up.
        // Seed at L11 (28·121 = 3_388, apprentice→forged band is L10..14 → forged).
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(xp: 3_388, lastContributionAt: t0))  // L11, forged
        // delta 1 × 50 = 50 → 3_438 → still L11, still forged.
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 1], at: t0)
        XCTAssertTrue(crossings.isEmpty)
    }

    func testFirstBuildIdentityResolvedTransitionDetectable() {
        // Starting from empty (balancedAthlete), adding enough to a single axis
        // flips the shape (buildIdentity is now level-spread based; spread ≥ 15
        // escapes balanced).
        var p = AttributeProfile.empty(userId: "u", at: t0)
        XCTAssertEqual(p.buildIdentity.shape, .balancedAthlete)

        // delta 150 × 50 = 7_500 xp → L21 (base=16: 16·441 = 7_056 ≤ 7_500 < 16·484 = 7_744). spread 21 ≥ 15.
        _ = AttributeIngest.applyDeltas(&p, deltas: [.power: 150], at: t0)
        XCTAssertEqual(p.value(for: .power).level, 21)
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

    func testMovementIdContributionWinsOverFallbackExerciseName() {
        let catalog = stubCatalog(
            [
                "Lat Pulldown (Neutral)": AttributeContribution(weights: [.endurance: 1.0])
            ],
            movements: [
                "exercise.lat-pulldown-neutral": AttributeContribution(weights: [.power: 1.0])
            ]
        )
        let log = WorkoutLog(
            id: "w4", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Pull",
            startedAt: t0, completedAt: t0.addingTimeInterval(30 * 60),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "e1",
                    exerciseName: "Lat Pulldown (Neutral)",
                    movementId: "exercise.lat-pulldown-neutral",
                    rankStandardMovementId: "exercise.lat-pulldown",
                    plannedSets: 3,
                    plannedReps: "10",
                    sets: [SetLog(id: "s1", setNumber: 1, weightKg: 70, reps: 10, rpe: 8, isWarmup: false)],
                    skipped: false,
                    notes: nil
                )
            ],
            overallNotes: nil, overallRPE: 8, durationMinutes: 30
        )

        let deltas = AttributeIngest.deltas(for: log, catalog: catalog)

        XCTAssertGreaterThan(deltas[.power] ?? 0, 0)
        XCTAssertEqual(deltas[.endurance] ?? 0, 0, accuracy: 0.001)
    }

    func testMovementAPFansIntoPermanentAttributeXP() {
        let catalog = stubCatalog(
            [:],
            movements: [
                "exercise.bench-press": AttributeContribution(weights: [.power: 0.75, .control: 0.25])
            ]
        )
        let gain = MovementAPGain(
            userId: "u",
            sourceLogId: "perf-1",
            sourceExerciseId: "e1",
            movementId: "exercise.bench-press",
            rankStandardMovementId: "exercise.bench-press",
            movementDisplayName: "Bench Press",
            standardDisplayName: "Bench Press",
            rankTemplate: .barbellStrength,
            rawAP: 120,
            reps: 5,
            loadKg: 100,
            estimatedOneRepMaxKg: 116.7,
            occurredAt: t0
        )

        let xpDeltas = AttributeIngest.xpDeltas(for: [gain], catalog: catalog)
        XCTAssertEqual(xpDeltas[.power] ?? 0, 90, accuracy: 0.001)
        XCTAssertEqual(xpDeltas[.control] ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(xpDeltas[.endurance] ?? 0, 0, accuracy: 0.001)

        var profile = AttributeProfile.empty(userId: "u", at: t0)
        let applied = AttributeIngest.applyXPDeltas(&profile, xpDeltas: xpDeltas, at: t0)

        // Empty profile → all axes L0 → mean 0 → catch-up factor 1.0 (no scaling).
        XCTAssertEqual(profile.value(for: .power).xp, 90, accuracy: 0.001)
        XCTAssertEqual(profile.value(for: .control).xp, 30, accuracy: 0.001)
        XCTAssertEqual(applied.rewards.count, 2)
        XCTAssertTrue(applied.rewards.contains { $0.key == .power && $0.xpGained == 90 })
    }

    func testMovementAPFanoutUsesWholeDisplayedXPAndReconcilesRounding() {
        let catalog = stubCatalog(
            [:],
            movements: [
                "exercise.mixed": AttributeContribution(weights: [.power: 1, .control: 1, .endurance: 1])
            ]
        )
        let gain = MovementAPGain(
            userId: "u",
            sourceLogId: "perf-integer",
            sourceExerciseId: "e1",
            movementId: "exercise.mixed",
            rankStandardMovementId: "exercise.mixed",
            movementDisplayName: "Mixed Lift",
            standardDisplayName: "Mixed Lift",
            rankTemplate: .barbellStrength,
            rawAP: 10,
            reps: 5,
            loadKg: 100,
            estimatedOneRepMaxKg: 116.7,
            occurredAt: t0
        )

        let xpDeltas = AttributeIngest.xpDeltas(
            for: [gain],
            catalog: catalog,
            noveltyMultiplier: 0.5
        )
        let totalXP = xpDeltas.values.reduce(0, +)

        XCTAssertEqual(totalXP, 10, accuracy: 0.001)
        XCTAssertTrue(xpDeltas.values.allSatisfy { $0 == floor($0) })
        XCTAssertEqual(xpDeltas.values.sorted(), [3, 3, 4])
    }
}

// Test helper
final class StubAttributeCatalog: AttributeCatalogProtocol {
    var byName: [String: AttributeContribution]
    var byMovement: [String: AttributeContribution]

    init(byName: [String: AttributeContribution], byMovement: [String: AttributeContribution] = [:]) {
        self.byName = byName
        self.byMovement = byMovement
    }

    func contribution(forExerciseName name: String) -> AttributeContribution {
        byName[name] ?? .zero
    }

    func contribution(forSkillNodeId id: String) -> AttributeContribution {
        byName[id] ?? .zero
    }

    func contribution(
        forMovementId movementId: String?,
        rankStandardMovementId: String?,
        fallbackExerciseName name: String
    ) -> AttributeContribution {
        if let movementId, let contribution = byMovement[movementId] {
            return contribution
        }
        if let rankStandardMovementId, let contribution = byMovement[rankStandardMovementId] {
            return contribution
        }
        return contribution(forExerciseName: name)
    }
}
