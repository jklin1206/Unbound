import XCTest
@testable import UNBOUND

// Prototype: the star-standard engine rates a node on its OWN movement only
// (0–3 stars vs a standard), with progress to the next star and difficulty
// weighting for the overall rank.

final class StarRatingEngineTests: XCTestCase {

    private func log(_ exercise: String, reps: Int, weightKg: Double? = nil, durationSeconds: Int? = nil) -> WorkoutLog {
        WorkoutLog(
            id: "l", userId: "u", programId: "p", dayNumber: 1, plannedWorkoutName: "x",
            startedAt: Date(timeIntervalSince1970: 1), completedAt: Date(timeIntervalSince1970: 2),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "e", exerciseName: exercise, plannedSets: 1, plannedReps: "\(reps)",
                    sets: [SetLog(id: "s", setNumber: 1, weightKg: weightKg, reps: reps, rpe: nil,
                                  isWarmup: false, durationSeconds: durationSeconds)],
                    skipped: false, notes: nil)
            ],
            overallNotes: nil, overallRPE: nil, durationMinutes: nil)
    }

    private let pullup = PullStarStandards.table["pp.pullup"]!          // reps 1/8/15
    private let deadHang = PullStarStandards.table["pp.dead-hang"]!     // seconds 30/60/120
    private let weightedPullup = PullStarStandards.table["pp.weighted-pullup"]! // +bw 0.1/0.33/0.5

    // MARK: Reps metric

    func testZeroStarsBelowFirstThreshold() {
        let r = StarRatingEngine.rate(pullup, logs: [], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 0)
        XCTAssertEqual(r.nextThreshold, 1)
    }

    func testOneStarAtFirstCleanRep() {
        let r = StarRatingEngine.rate(pullup, logs: [log("pullup", reps: 1)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 1)
        XCTAssertEqual(r.nextThreshold, 8)   // next = ★★
    }

    func testTwoStarsAtWorkingSet() {
        let r = StarRatingEngine.rate(pullup, logs: [log("pullup", reps: 8)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 2)
    }

    func testThreeStarsMaxedOut() {
        let r = StarRatingEngine.rate(pullup, logs: [log("pullup", reps: 20)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 3)
        XCTAssertNil(r.nextThreshold)
        XCTAssertEqual(r.progressToNext, 1)
    }

    func testProgressInterpolatesBetweenStars() {
        // best 4 reps, between ★(1) and ★★(8) → (4-1)/(8-1) ≈ 0.43
        let r = StarRatingEngine.rate(pullup, logs: [log("pullup", reps: 4)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 1)
        XCTAssertEqual(r.progressToNext, 3.0 / 7.0, accuracy: 0.001)
    }

    // MARK: Seconds metric (uses durationSeconds, F2)

    func testSecondsFromDurationSeconds() {
        let r = StarRatingEngine.rate(deadHang, logs: [log("dead hang", reps: 0, durationSeconds: 65)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 2)   // 65 ≥ 60 (★★), < 120 (★★★)
    }

    func testSecondsLegacyRepsFallback() {
        let r = StarRatingEngine.rate(deadHang, logs: [log("dead hang", reps: 30)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 1)   // 30 ≥ 30 (★)
    }

    // MARK: Bodyweight-ratio metric (added load)

    func testBodyweightRatioAddedLoad() {
        // 70kg athlete, +35kg = 0.5x bw → ★★★
        let r = StarRatingEngine.rate(weightedPullup, logs: [log("weighted pullup", reps: 1, weightKg: 35)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 3)
    }

    // MARK: Own-movement only (the council invariant)

    func testDoesNotRankFromADifferentExercise() {
        // Logging 20 chin-ups must NOT earn pull-up stars.
        let r = StarRatingEngine.rate(pullup, logs: [log("chin-up", reps: 20)], bodyweightKg: 70)
        XCTAssertEqual(r.stars, 0)
    }

    // MARK: Difficulty weighting toward overall rank

    func testWeightedPointsScaleWithDifficulty() {
        let oap = PullStarStandards.table["pp.one-arm-pullup"]!   // weight 7
        let oneStarPullup = StarRatingEngine.rate(pullup, logs: [log("pullup", reps: 1)], bodyweightKg: 70)
        let oneStarOAP = StarRatingEngine.rate(oap, logs: [log("one-arm pullup", reps: 1)], bodyweightKg: 70)
        // A single ★ on the OAP outweighs a single ★ on the pull-up.
        XCTAssertGreaterThan(oneStarOAP.weightedPoints(weight: oap.weight),
                             oneStarPullup.weightedPoints(weight: pullup.weight))
    }

    func testFamilyWeightedSum() {
        let logs = [log("pullup", reps: 8), log("muscle-up", reps: 1), log("dead hang", reps: 60)]
        var total = 0
        for (_, std) in PullStarStandards.table {
            total += StarRatingEngine.rate(std, logs: logs, bodyweightKg: 70).weightedPoints(weight: std.weight)
        }
        // pull-up ★★ (2×2=4) + muscle-up ★ (1×4=4) + dead-hang ★★ (2×1=2) = 10
        XCTAssertEqual(total, 10)
    }
}
