// UNBOUND/Services/Trials/VowLogMatcher.swift
import Foundation

/// Counts logged sessions that qualify for an auto-verified vow lane within the
/// bound week (spec §7). Recovery/Engine only; Fuel is self-report.
///
/// Read-only detection source (Binding Vows v2 Core-3): recovery days and
/// standalone cardio never reach the `workoutLogs` stream —
///   - Recovery sessions persist as `PerformanceLog`s with `source == .routine`
///     (e.g. titles "Recovery Day" / "Recovery Reset" / "Mobility flow"), which
///     `TrainingSessionAdapters.workoutLog(from:)` drops (no strength/skill blocks).
///   - Standalone cardio persists to the separate `cardio_sessions` collection as
///     `CardioSession`, never a `WorkoutLog`.
/// So auto-detection reads those sources directly (read-only) and counts here.
/// Fuel never log-matches (self-report taps only).
enum VowLogMatcher {

    // MARK: - Recovery (PerformanceLog, source == .routine)

    /// In-week qualifying recovery completions. `recoveryLogs` are the
    /// routine-sourced `PerformanceLog`s read from the `performanceLogs`
    /// collection; we match on the title string the recovery logging stamps
    /// (recovery / mobility).
    static func qualifyingRecoveryCount(
        weekStart: Date,
        recoveryLogs: [PerformanceLog]
    ) -> Int {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        return recoveryLogs.filter { log in
            log.completedAt >= weekStart
                && log.completedAt < weekEnd
                && recoveryQualifies(log)
        }.count
    }

    private static func recoveryQualifies(_ log: PerformanceLog) -> Bool {
        let title = log.title.lowercased()
        return recoveryKeywords.contains { title.contains($0) }
    }

    // MARK: - Engine (CardioSession)

    /// In-week qualifying cardio completions, counted by `CardioSession.date`.
    static func qualifyingCardioCount(
        weekStart: Date,
        cardioSessions: [CardioSession]
    ) -> Int {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        return cardioSessions.filter { session in
            session.date >= weekStart && session.date < weekEnd
        }.count
    }

    private static let recoveryKeywords = ["recovery", "mobility"]
}
