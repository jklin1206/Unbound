import XCTest
@testable import UNBOUND

final class ProofEngineTests: XCTestCase {
    func testEveryWorkoutSourceRunsProof() {
        let log = pullupLog(reps: 12)

        for source in WorkoutProofSource.allCases {
            let result = ProofEngine.evaluate(log: log, source: source)

            XCTAssertEqual(result.source, source)
            XCTAssertFalse(result.achievedProofs.isEmpty, "\(source) should extract proof")
            XCTAssertFalse(result.standardsCleared.isEmpty, "\(source) should clear standards")
        }
    }

    func testMultiRankEventEmitsFromSingleHighProofLog() {
        let result = ProofEngine.evaluate(log: pullupLog(reps: 12), source: .custom)

        XCTAssertNotNil(result.multiRankEvent)
        XCTAssertGreaterThan(result.multiRankEvent?.ranksAdvanced ?? 0, 1)
        XCTAssertTrue(result.standardsCleared.contains { $0.skillId == "pp.pullup" })
    }

    func testProcessedLogIsIdempotentAndDoesNotDoubleGrant() {
        let log = pullupLog(reps: 12)

        let result = ProofEngine.evaluate(
            log: log,
            source: .generated,
            processedLogIds: [log.id]
        )

        XCTAssertFalse(result.hasRewards)
        XCTAssertTrue(result.standardsCleared.isEmpty)
        XCTAssertTrue(result.unlocks.isEmpty)
    }

    func testEmptyWorkoutProducesNoRewardPayload() {
        var log = pullupLog(reps: 0)
        log.exerciseEntries[0].sets[0].weightKg = nil

        let result = ProofEngine.evaluate(log: log, source: .custom)

        XCTAssertFalse(result.hasRewards)
        XCTAssertTrue(result.achievedProofs.isEmpty)
    }

    private func pullupLog(reps: Int) -> WorkoutLog {
        WorkoutLog(
            id: "log-\(reps)",
            userId: "user-1",
            programId: "program-1",
            dayNumber: 1,
            plannedWorkoutName: "Pull Day",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1300),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "entry-1",
                    exerciseName: "pullup",
                    movementId: nil,
                    rankStandardMovementId: "pp.pullup",
                    plannedSets: 1,
                    plannedReps: "\(reps)",
                    sets: [
                        SetLog(
                            id: "set-1",
                            setNumber: 1,
                            weightKg: nil,
                            reps: reps,
                            rpe: 8,
                            isWarmup: false
                        )
                    ],
                    skipped: false,
                    notes: nil
                )
            ],
            overallNotes: nil,
            overallRPE: 8,
            durationMinutes: 20
        )
    }
}
