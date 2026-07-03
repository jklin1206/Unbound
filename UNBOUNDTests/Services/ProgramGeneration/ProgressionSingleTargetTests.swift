import XCTest
@testable import UNBOUND

/// Locks the single-number prescription contract: the min...max window stays
/// the engine's internal rails, and `currentTargetReps` is the one number the
/// user chases — bottom to start, +1 per delivered session, hold at the top,
/// reset to the bottom after a weight bump, keep climbing after an accessory
/// window widening.
final class ProgressionSingleTargetTests: XCTestCase {
    private func state(
        last: Int?,
        hit: Bool?,
        consecutive: Int = 0,
        min: Int = 8,
        max: Int = 12
    ) -> ProgressionState {
        var s = ProgressionState.seed(userId: "u1", exercise: "bench press", startingWeightKg: 60)
        s.targetRepMin = min
        s.targetRepMax = max
        s.lastSessionReps = last
        s.lastSessionHitTarget = hit
        s.consecutiveSessionsAtTarget = consecutive
        return s
    }

    func testNoHistoryStartsAtBottomOfWindow() {
        XCTAssertEqual(state(last: nil, hit: nil).currentTargetReps, 8)
    }

    func testTargetClimbsOneRepPastLastSession() {
        XCTAssertEqual(state(last: 8, hit: false).currentTargetReps, 9)
        XCTAssertEqual(state(last: 10, hit: false).currentTargetReps, 11)
    }

    func testMissBelowWindowClampsToBottom() {
        XCTAssertEqual(state(last: 5, hit: false).currentTargetReps, 8)
    }

    func testTopHitHoldsAtTopUntilSecondHitBumps() {
        // One top hit (counter 1): ask the top again — the second hit bumps.
        XCTAssertEqual(state(last: 12, hit: true, consecutive: 1).currentTargetReps, 12)
    }

    func testWeightBumpRestartsAtBottom() {
        // applyBump resets the counter after a top-range session → new weight,
        // climb restarts at the bottom of the window.
        XCTAssertEqual(state(last: 12, hit: true, consecutive: 0).currentTargetReps, 8)
    }

    func testAccessoryWindowWideningKeepsClimbing() {
        // Accessory bump widens the top (12 → 14) instead of adding weight;
        // last session (12) is now inside the window, so the ask keeps climbing.
        XCTAssertEqual(state(last: 12, hit: true, consecutive: 0, max: 14).currentTargetReps, 13)
    }

    func testResolverEmitsSingleRepTarget() {
        var s = state(last: 9, hit: false)
        s.currentWorkingWeightKg = 60
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .custom,
            title: "Push",
            estimatedMinutes: 30,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Main Work",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "bench press",
                            sets: 4,
                            target: .repsRange(8, 12),
                            restSeconds: 120,
                            muscleGroups: [.chest]
                        )
                    ]
                )
            ]
        )
        let resolved = TrainingPrescriptionResolver.resolve(
            draft: draft,
            progressionStates: ["bench press": s]
        )
        XCTAssertEqual(resolved.blocks.first?.prescriptions.first?.target, .reps(10))
    }
}
