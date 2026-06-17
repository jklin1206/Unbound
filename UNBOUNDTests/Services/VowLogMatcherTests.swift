import XCTest
@testable import UNBOUND

final class VowLogMatcherTests: XCTestCase {

    // Recovery sessions persist as routine-sourced PerformanceLogs; the matcher
    // reads them (read-only) and qualifies via title keyword OR mobility block label.
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

    /// A log whose title has no recovery keyword but whose block carries the
    /// MOBILITY WING label — the standalone mobility routine path.
    private func mobilityWingLog(titled title: String, completedAt t: TimeInterval) -> PerformanceLog {
        let block = PerformanceBlock(
            kind: .routine,
            title: "Mobility Block",
            exercises: [],
            notes: RoutineCategory.mobility.label   // "MOBILITY WING"
        )
        return PerformanceLog(
            id: UUID().uuidString,
            userId: "u",
            source: .routine,
            title: title,
            startedAt: Date(timeIntervalSince1970: t),
            completedAt: Date(timeIntervalSince1970: t + 600),
            blocks: [block]
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
        let count = VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, committedAt: weekStart, recoveryLogs: logs)
        XCTAssertEqual(count, 2)
    }

    func testIgnoresRecoveryLogsBeforeWeekStart() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [recoveryLog(titled: "Recovery Reset", completedAt: 1_600_000_000)]
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, committedAt: weekStart, recoveryLogs: logs),
            0
        )
    }

    func testIgnoresRecoveryLogsAtOrAfterWeekEnd() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        // completedAt at exactly weekStart + 7 days is excluded (half-open window).
        let atEnd = 1_700_000_000 + 7 * 86_400.0 - 600  // +600 lands exactly on weekEnd
        let logs = [recoveryLog(titled: "Recovery Reset", completedAt: atEnd)]
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, committedAt: weekStart, recoveryLogs: logs),
            0
        )
    }

    func testRecoveryIgnoresNonRecoveryTitledRoutines() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        // A routine-sourced log that is not a recovery/mobility flow.
        let circuit = recoveryLog(titled: "Hunter Exam Roadwork", completedAt: 1_700_000_500)
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, committedAt: weekStart, recoveryLogs: [circuit]),
            0
        )
    }

    // MARK: - Recovery hybrid signal tests

    func testMobilityWingBlockQualifiesWithoutTitleKeyword() {
        // Standalone mobility routines ("Hip Reset", "Evening Stretch", etc.) carry
        // RoutineCategory.mobility.label on their block notes, not a keyword in the title.
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let log = mobilityWingLog(titled: "Hip Reset", completedAt: 1_700_000_500)
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, committedAt: weekStart, recoveryLogs: [log]),
            1,
            "A log with MOBILITY WING block notes must qualify even without a title keyword"
        )
    }

    func testProgramRestDayQualifiesViaTitleWithoutMobilityBlock() {
        // Program rest-days are titled "Recovery Day" with no mobility block notes.
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let log = recoveryLog(titled: "Recovery Day", completedAt: 1_700_000_500)
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, committedAt: weekStart, recoveryLogs: [log]),
            1,
            "A program rest-day titled 'Recovery Day' must qualify via title keyword alone"
        )
    }

    func testNonRecoveryLogWithoutMobilityBlockDoesNotQualify() {
        // A circuit routine with neither a recovery/mobility title keyword nor
        // a MOBILITY WING block label must not count.
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let block = PerformanceBlock(
            kind: .routine,
            title: "Circuit Block",
            exercises: [],
            notes: "ARSENAL"   // different category label, not MOBILITY WING
        )
        let log = PerformanceLog(
            id: UUID().uuidString,
            userId: "u",
            source: .routine,
            title: "Hunter Exam Roadwork",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_600),
            blocks: [block]
        )
        XCTAssertEqual(
            VowLogMatcher.qualifyingRecoveryCount(weekStart: weekStart, committedAt: weekStart, recoveryLogs: [log]),
            0,
            "A non-recovery log with a non-mobility block must not qualify"
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
            VowLogMatcher.qualifyingCardioCount(weekStart: weekStart, committedAt: weekStart, cardioSessions: sessions),
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
            VowLogMatcher.qualifyingCardioCount(weekStart: weekStart, committedAt: weekStart, cardioSessions: sessions),
            0
        )
    }
}
