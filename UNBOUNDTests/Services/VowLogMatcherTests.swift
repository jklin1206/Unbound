import XCTest
@testable import UNBOUND

final class VowLogMatcherTests: XCTestCase {

    // Recovery sessions persist as routine-sourced PerformanceLogs; the matcher
    // reads them (read-only) and matches on the title (recovery / mobility).
    private func recoveryLog(titled title: String, completedAt t: TimeInterval) -> PerformanceLog {
        PerformanceLog(
            id: UUID().uuidString,
            userId: "u",
            source: .routine,
            title: title,
            startedAt: Date(timeIntervalSince1970: t),
            completedAt: Date(timeIntervalSince1970: t + 600),
            blocks: []
        )
    }

    private func cardio(at t: TimeInterval) -> CardioSession {
        CardioSession(
            userId: "u",
            type: .run,
            durationMinutes: 20,
            perceivedEffort: 5,
            date: Date(timeIntervalSince1970: t)
        )
    }

    // MARK: - Recovery

    func testCountsRecoverySessionsInWindow() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [
            recoveryLog(titled: "Recovery Reset", completedAt: 1_700_000_500),
            recoveryLog(titled: "Mobility Flow", completedAt: 1_700_100_000)
        ]
        let count = VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, recoveryLogs: logs)
        XCTAssertEqual(count, 2)
    }

    func testIgnoresRecoveryLogsBeforeWeekStart() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [recoveryLog(titled: "Recovery Reset", completedAt: 1_600_000_000)]
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, recoveryLogs: logs),
            0
        )
    }

    func testIgnoresRecoveryLogsAtOrAfterWeekEnd() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        // completedAt at exactly weekStart + 7 days is excluded (half-open window).
        let atEnd = 1_700_000_000 + 7 * 86_400.0 - 600  // +600 lands exactly on weekEnd
        let logs = [recoveryLog(titled: "Recovery Reset", completedAt: atEnd)]
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, recoveryLogs: logs),
            0
        )
    }

    func testRecoveryIgnoresNonRecoveryTitledRoutines() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        // A routine-sourced log that is not a recovery/mobility flow.
        let circuit = recoveryLog(titled: "Hunter Exam Roadwork", completedAt: 1_700_000_500)
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, recoveryLogs: [circuit]),
            0
        )
    }

    // MARK: - Engine (Cardio)

    func testEngineCountsCardioSessionsInWindow() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            cardio(at: 1_700_000_500),
            cardio(at: 1_700_100_000)
        ]
        XCTAssertEqual(
            VowLogMatcher.qualifyingCardioCount(weekStart: weekStart, cardioSessions: sessions),
            2
        )
    }

    func testEngineIgnoresCardioOutsideWindow() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let weekEnd = 1_700_000_000 + 7 * 86_400.0
        let sessions = [
            cardio(at: 1_600_000_000),   // before
            cardio(at: weekEnd)          // at end (excluded, half-open)
        ]
        XCTAssertEqual(
            VowLogMatcher.qualifyingCardioCount(weekStart: weekStart, cardioSessions: sessions),
            0
        )
    }
}
