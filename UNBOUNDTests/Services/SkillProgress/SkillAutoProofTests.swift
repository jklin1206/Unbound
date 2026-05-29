import XCTest
@testable import UNBOUND

// Auto-proof for hold / steps / carry nodes. Before this, requirementMet
// returned false for these types, so a logged 60s L-sit could never advance a
// hold node without the manual "I hit it" tap. Holds log seconds in the reps
// column (the same convention RankService uses).

@MainActor
final class SkillAutoProofTests: XCTestCase {

    private func svc() async -> SkillProgressService {
        let db = MockDatabaseService()
        let s = SkillProgressService(database: db)
        await s.load(userId: "u")
        return s
    }

    private func log(exercise: String, reps: Int, weightKg: Double? = nil) -> WorkoutLog {
        WorkoutLog(
            id: "log-1",
            userId: "u",
            programId: "p",
            dayNumber: 1,
            plannedWorkoutName: "Skill",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 2_000),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "e-1",
                    exerciseName: exercise,
                    plannedSets: 1,
                    plannedReps: "\(reps)",
                    sets: [SetLog(id: "s-1", setNumber: 1, weightKg: weightKg, reps: reps, rpe: nil, isWarmup: false)],
                    skipped: false,
                    notes: nil
                )
            ],
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: nil
        )
    }

    /// Kickoff proof: log a 60s L-sit → a 10s L-sit hold node auto-proves.
    func testHoldAutoProvesFromLoggedSeconds() async {
        let s = await svc()
        let req = NodeRequirement.hold(exercise: "l-sit", seconds: 10)
        let logs = [log(exercise: "l-sit", reps: 60)]

        XCTAssertTrue(s.requirementMet(req, logs: logs, bodyweightKg: 70, threshold: 1.0),
                      "60s logged ≥ 10s target → achieved")
        XCTAssertTrue(s.requirementMet(req, logs: logs, bodyweightKg: 70, threshold: 2.0),
                      "60s logged ≥ 2× target → mastered")
    }

    /// Foundation 2: a hold logged with real `durationSeconds` (not the reps
    /// column) proves the node.
    func testHoldAutoProvesFromDurationSeconds() async {
        let s = await svc()
        let req = NodeRequirement.hold(exercise: "l-sit", seconds: 10)
        let holdLog = WorkoutLog(
            id: "log-d", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Skill",
            startedAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 2_000),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "e-1", exerciseName: "l-sit", plannedSets: 1, plannedReps: "10s",
                    sets: [SetLog(id: "s-1", setNumber: 1, weightKg: nil, reps: 0,
                                  rpe: nil, isWarmup: false, durationSeconds: 30)],
                    skipped: false, notes: nil
                )
            ],
            overallNotes: nil, overallRPE: nil, durationMinutes: nil
        )
        XCTAssertTrue(s.requirementMet(req, logs: [holdLog], bodyweightKg: 70, threshold: 1.0),
                      "30s in durationSeconds ≥ 10s target → proven")
    }

    func testHoldStaysLockedBelowTarget() async {
        let s = await svc()
        let req = NodeRequirement.hold(exercise: "l-sit", seconds: 10)
        let logs = [log(exercise: "l-sit", reps: 5)]
        XCTAssertFalse(s.requirementMet(req, logs: logs, bodyweightKg: 70, threshold: 1.0),
                       "5s < 10s target → not proven")
    }

    func testStepsAutoProve() async {
        let s = await svc()
        let req = NodeRequirement.steps(exercise: "pistol squat", count: 8)
        XCTAssertTrue(s.requirementMet(req, logs: [log(exercise: "pistol squat", reps: 8)], bodyweightKg: 70, threshold: 1.0))
        XCTAssertFalse(s.requirementMet(req, logs: [log(exercise: "pistol squat", reps: 4)], bodyweightKg: 70, threshold: 1.0))
    }

    func testCarryRequiresLoad() async {
        let s = await svc()
        let req = NodeRequirement.carry(exercise: "farmer carry", seconds: 30, load: "2x bw")
        // Loaded carry of 40s → proven.
        XCTAssertTrue(s.requirementMet(req, logs: [log(exercise: "farmer carry", reps: 40, weightKg: 60)], bodyweightKg: 70, threshold: 1.0))
        // Same duration but unloaded → not a carry proof.
        XCTAssertFalse(s.requirementMet(req, logs: [log(exercise: "farmer carry", reps: 40, weightKg: nil)], bodyweightKg: 70, threshold: 1.0))
    }

    func testCompositeRequiresAllParts() async {
        let s = await svc()
        let req = NodeRequirement.composite([
            .hold(exercise: "l-sit", seconds: 10),
            .reps(exercise: "pull-up", count: 5)
        ])
        let bothMet = [log(exercise: "l-sit", reps: 12), log2(exercise: "pull-up", reps: 6)]
        XCTAssertTrue(s.requirementMet(req, logs: bothMet, bodyweightKg: 70, threshold: 1.0))
        // Only the hold met → composite fails.
        XCTAssertFalse(s.requirementMet(req, logs: [log(exercise: "l-sit", reps: 12)], bodyweightKg: 70, threshold: 1.0))
    }

    // Second log with a distinct id so composite pools both entries.
    private func log2(exercise: String, reps: Int) -> WorkoutLog {
        var l = log(exercise: exercise, reps: reps)
        return WorkoutLog(
            id: "log-2", userId: l.userId, programId: l.programId, dayNumber: 2,
            plannedWorkoutName: l.plannedWorkoutName, startedAt: l.startedAt, completedAt: l.completedAt,
            exerciseEntries: l.exerciseEntries, overallNotes: nil, overallRPE: nil, durationMinutes: nil
        )
    }
}
