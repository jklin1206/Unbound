import XCTest
@testable import UNBOUND

final class VowLogMatcherTests: XCTestCase {

    // `WorkoutLog` has no `source` field — the only durable lane signal is
    // `plannedWorkoutName` (see VowLogMatcher). Recovery logs title "Recovery
    // Reset"/"Recovery Day"; cardio logs title "<Type> Session"; strength logs
    // title with the workout name (e.g. "Push Day").
    private func log(named name: String, at t: TimeInterval) -> WorkoutLog {
        WorkoutLog(
            id: UUID().uuidString,
            userId: "u",
            programId: "p",
            dayNumber: 1,
            plannedWorkoutName: name,
            startedAt: Date(timeIntervalSince1970: t),
            completedAt: Date(timeIntervalSince1970: t + 600),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: 3,
            durationMinutes: 10
        )
    }

    func testCountsRecoverySessionsInWindow() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [
            log(named: "Recovery Reset", at: 1_700_000_500),
            log(named: "Recovery Day", at: 1_700_100_000)
        ]
        let count = VowLogMatcher.qualifyingCount(lane: .recovery, weekStart: weekStart, logs: logs)
        XCTAssertEqual(count, 2)
    }

    func testIgnoresLogsBeforeWeekStart() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [log(named: "Recovery Reset", at: 1_600_000_000)]
        XCTAssertEqual(
            VowLogMatcher.qualifyingCount(lane: .recovery, weekStart: weekStart, logs: logs),
            0
        )
    }

    func testIgnoresLogsAtOrAfterWeekEnd() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        // weekEnd = weekStart + 7 days. completedAt = start + 600 lands past end.
        let pastEnd = 1_700_000_000 + 7 * 86_400.0
        let logs = [log(named: "Recovery Reset", at: pastEnd)]
        XCTAssertEqual(
            VowLogMatcher.qualifyingCount(lane: .recovery, weekStart: weekStart, logs: logs),
            0
        )
    }

    func testRecoveryLaneIgnoresStrengthLogs() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let strength = log(named: "Push Day", at: 1_700_000_500)
        XCTAssertEqual(
            VowLogMatcher.qualifyingCount(lane: .recovery, weekStart: weekStart, logs: [strength]),
            0
        )
    }

    func testEngineLaneCountsCardioLogs() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [
            log(named: "Run Session", at: 1_700_000_500),
            log(named: "Cycling Session", at: 1_700_100_000),
            log(named: "Push Day", at: 1_700_050_000)  // not cardio
        ]
        XCTAssertEqual(
            VowLogMatcher.qualifyingCount(lane: .engine, weekStart: weekStart, logs: logs),
            2
        )
    }

    func testFuelLaneNeverLogMatches() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [
            log(named: "Recovery Reset", at: 1_700_000_500),
            log(named: "Run Session", at: 1_700_001_000)
        ]
        XCTAssertEqual(
            VowLogMatcher.qualifyingCount(lane: .fuel, weekStart: weekStart, logs: logs),
            0
        )
    }
}
