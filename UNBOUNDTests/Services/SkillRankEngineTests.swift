import XCTest
@testable import UNBOUND

// Prototype: a skill ranks on the 9-tier RankTier from ONE standard
// (best ÷ standard → shared band). best = standard → Forged; ≈3× → peak.
// Same shape as a lift's RankTier from StrengthStandards.

final class SkillRankEngineTests: XCTestCase {

    private func log(_ exercise: String, reps: Int, weightKg: Double? = nil, seconds: Int? = nil) -> WorkoutLog {
        WorkoutLog(
            id: "l", userId: "u", programId: "p", dayNumber: 1, plannedWorkoutName: "x",
            startedAt: Date(timeIntervalSince1970: 1), completedAt: Date(timeIntervalSince1970: 2),
            exerciseEntries: [
                ExerciseLogEntry(id: "e", exerciseName: exercise, plannedSets: 1, plannedReps: "\(reps)",
                                 sets: [SetLog(id: "s", setNumber: 1, weightKg: weightKg, reps: reps, rpe: nil, isWarmup: false, durationSeconds: seconds)],
                                 skipped: false, notes: nil)
            ],
            overallNotes: nil, overallRPE: nil, durationMinutes: nil)
    }

    private let pullup = PullSkillStandards.table["pp.pullup"]!        // reps, standard 10
    private let frontLeverLike = SkillRankStandard(metric: .seconds(exercise: "dead hang"), standard: 10, weight: 1)

    // MARK: Band shape

    func testHittingTheStandardIsForged() {
        // best == standard → ratio 1.0 → Forged
        let r = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 10)], bodyweightKg: 70)
        XCTAssertEqual(r.tier, .forged)
    }

    func testZeroLogsIsInitiate() {
        let r = SkillRankEngine.rank(pullup, logs: [], bodyweightKg: 70)
        XCTAssertEqual(r.tier, .initiate)
        XCTAssertEqual(r.nextTier, .novice)
    }

    func testBelowStandardClimbsInitiateToForged() {
        // 5 reps of a 10-standard → ratio 0.5 → position 1.5 → Novice (+ progress)
        let r = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 5)], bodyweightKg: 70)
        XCTAssertEqual(r.tier, .novice)
        XCTAssertEqual(r.progressToNextTier, 0.5, accuracy: 0.001)
    }

    func testEliteIsAboutThreeTimesStandard() {
        // 30 reps of a 10-standard → ratio 3.0 → peak
        let r = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 30)], bodyweightKg: 70)
        XCTAssertEqual(r.tier, .ascendant)   // rawValue 8 = peak
        XCTAssertNil(r.nextTier)
        XCTAssertEqual(r.progressToNextTier, 1.0)
    }

    // MARK: Depth within a skill is preserved (3s vs 30s differ)

    func testDepthWithinSkillDiffersByHold() {
        let short = SkillRankEngine.rank(frontLeverLike, logs: [log("dead hang", reps: 0, seconds: 3)], bodyweightKg: 70)
        let long = SkillRankEngine.rank(frontLeverLike, logs: [log("dead hang", reps: 0, seconds: 30)], bodyweightKg: 70)
        XCTAssertLessThan(short.tier, long.tier)   // 3s ≪ 30s
        XCTAssertEqual(long.tier, .ascendant)      // 30s = 3× the 10 standard = peak
    }

    // MARK: Own-movement only (council invariant)

    func testDoesNotRankFromADifferentExercise() {
        let r = SkillRankEngine.rank(pullup, logs: [log("chin-up", reps: 30)], bodyweightKg: 70)
        XCTAssertEqual(r.tier, .initiate)
    }

    // MARK: Weighted points scale with difficulty

    func testWeightedPointsScaleWithDifficulty() {
        let oap = PullSkillStandards.table["pp.one-arm-pullup"]!  // weight 7
        let pu = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 10)], bodyweightKg: 70)        // Forged(3)×2 = 6
        let oa = SkillRankEngine.rank(oap, logs: [log("one-arm pullup", reps: 1)], bodyweightKg: 70)    // Forged(3)×7 = 21
        XCTAssertGreaterThan(SkillRankEngine.weightedPoints(oa, weight: oap.weight),
                             SkillRankEngine.weightedPoints(pu, weight: pullup.weight))
    }
}
