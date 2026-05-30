import XCTest
@testable import UNBOUND

// Prototype: a skill is mastered through 5 DISCRETE stars from its own movement's
// best (hand-authored ascending thresholds). A star fills when best ≥ threshold —
// no curve, no bar. Past 5 stars it just carries the PB.

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

    private let pullup = PullSkillStandards.table["pp.pullup"]!        // reps [1,5,10,15,20]
    private let holdLike = SkillRankStandard(metric: .seconds(exercise: "dead hang"), thresholds: [5, 10, 20, 40, 60], weight: 1)

    // MARK: Stars fill on cleared thresholds

    func testZeroLogsIsZeroStars() {
        let r = SkillRankEngine.rank(pullup, logs: [], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 0)
        XCTAssertEqual(r.label, "Locked")
        XCTAssertEqual(r.nextThreshold, 1)   // first star threshold
    }

    func testFirstThresholdLearned() {
        let r = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 1)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 1)
        XCTAssertEqual(r.label, "Learned")
        XCTAssertEqual(r.nextThreshold, 5)
    }

    func testMidLadderCountsClearedThresholds() {
        // 12 reps clears 1, 5, 10 → 3 stars; next is 15
        let r = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 12)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 3)
        XCTAssertEqual(r.nextThreshold, 15)
        XCTAssertEqual(r.best, 12)
    }

    func testTopThresholdMasters() {
        let r = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 20)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 5)
        XCTAssertTrue(r.isMastered)
        XCTAssertEqual(r.label, "Mastered")
        XCTAssertNil(r.nextThreshold)
    }

    func testBeyondTopStaysMasteredAndCarriesPB() {
        // 47 reps: still 5 stars, but PB reflects the real best (the forever-flex)
        let r = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 47)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 5)
        XCTAssertEqual(r.best, 47)
        XCTAssertNil(r.nextThreshold)
    }

    // MARK: Depth within a skill (a hold's seconds drive stars)

    func testDepthWithinSkillDiffersByHold() {
        let short = SkillRankEngine.rank(holdLike, logs: [log("dead hang", reps: 0, seconds: 4)], bodyweightKg: 70)
        let long = SkillRankEngine.rank(holdLike, logs: [log("dead hang", reps: 0, seconds: 60)], bodyweightKg: 70)
        XCTAssertEqual(short.stars, 0)   // 4s clears nothing
        XCTAssertEqual(long.stars, 5)    // 60s clears all five
    }

    // MARK: Own-movement only (council invariant)

    func testDoesNotRankFromADifferentExercise() {
        let r = SkillRankEngine.rank(pullup, logs: [log("chin-up", reps: 30)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 0)
    }

    // MARK: Weighted points scale with difficulty

    func testWeightedPointsScaleWithDifficulty() {
        let oap = PullSkillStandards.table["pp.one-arm-pullup"]!  // weight 7, thresholds [1,2,3,4,5]
        let pu = SkillRankEngine.rank(pullup, logs: [log("pullup", reps: 5)], bodyweightKg: 70)        // 2 stars × 2 = 4
        let oa = SkillRankEngine.rank(oap, logs: [log("one-arm pullup", reps: 1)], bodyweightKg: 70)   // 1 star × 7 = 7
        XCTAssertGreaterThan(SkillRankEngine.weightedPoints(oa, weight: oap.weight),
                             SkillRankEngine.weightedPoints(pu, weight: pullup.weight))
    }
}
