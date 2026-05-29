import XCTest
@testable import UNBOUND

// Foundation 2: holds/carries store real seconds in `SetLog.durationSeconds`
// instead of being jammed into the reps column. These tests lock the
// persistence contract (backward-compatible decode) and the seconds-aware
// readers (TierCriterionEvaluator.seconds), including the legacy reps-column
// fallback so pre-Foundation-2 logs still rank.

final class HoldSecondsTests: XCTestCase {

    private let dec = JSONDecoder()
    private let enc = JSONEncoder()

    // MARK: - SetLog persistence

    func testSetLogRoundTripsDurationSeconds() throws {
        let set = SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: 0, rpe: nil,
                         isWarmup: false, durationSeconds: 42)
        let decoded = try dec.decode(SetLog.self, from: try enc.encode(set))
        XCTAssertEqual(decoded.durationSeconds, 42)
        XCTAssertEqual(decoded.reps, 0)
    }

    func testLegacySetLogWithoutDurationDecodesToNil() throws {
        // Pre-Foundation-2 blob: no durationSeconds key, seconds in `reps`.
        let json = """
        { "id": "s1", "setNumber": 1, "reps": 45, "isWarmup": false }
        """
        let set = try dec.decode(SetLog.self, from: Data(json.utf8))
        XCTAssertNil(set.durationSeconds)
        XCTAssertEqual(set.reps, 45)   // legacy seconds-in-reps preserved
    }

    // MARK: - TierCriterionEvaluator.seconds

    private func entry(reps: Int, durationSeconds: Int?) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: "e1",
            exerciseName: "l-sit",
            plannedSets: 1,
            plannedReps: "30s",
            sets: [SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: reps,
                          rpe: nil, isWarmup: false, durationSeconds: durationSeconds)],
            skipped: false,
            notes: nil
        )
    }

    func testSecondsCriterionMetFromDurationSeconds() {
        let history = [entry(reps: 0, durationSeconds: 45)]
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .seconds(30), history: history, bodyweightKg: 70))
    }

    func testSecondsCriterionBelowTarget() {
        let history = [entry(reps: 0, durationSeconds: 20)]
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .seconds(30), history: history, bodyweightKg: 70))
    }

    func testSecondsCriterionFallsBackToLegacyReps() {
        // Legacy log: durationSeconds nil, seconds in the reps column.
        let history = [entry(reps: 45, durationSeconds: nil)]
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .seconds(30), history: history, bodyweightKg: 70))
    }

    func testWarmupSetsExcludedFromSeconds() {
        let warmup = ExerciseLogEntry(
            id: "e1", exerciseName: "l-sit", plannedSets: 1, plannedReps: "30s",
            sets: [SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: 0, rpe: nil,
                          isWarmup: true, durationSeconds: 99)],
            skipped: false, notes: nil
        )
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .seconds(30), history: [warmup], bodyweightKg: 70))
    }
}
