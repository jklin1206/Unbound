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
    /// collection.
    ///
    /// Two-signal qualifier (hybrid):
    ///   1. Title keyword — catches program rest-days titled "Recovery Day" /
    ///      "Recovery Reset", which carry no special block notes.
    ///   2. Mobility category label on any block — catches standalone mobility
    ///      routines (e.g. "Hip Reset", "Evening Stretch", "Shoulder + Spine Reset",
    ///      "Ankle + Squat Prep") that stamp `RoutineCategory.mobility.label`
    ///      ("MOBILITY WING") onto their block notes but whose titles contain no
    ///      keyword.
    static func qualifyingRecoveryCount(
        weekStart: Date,
        committedAt: Date,
        recoveryLogs: [PerformanceLog]
    ) -> Int {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        // Only sessions at or after the commitment count, so a log from earlier
        // in the week can't retroactively seal a vow the user picked later.
        let lowerBound = max(weekStart, committedAt)
        return recoveryLogs.filter { log in
            log.completedAt >= lowerBound
                && log.completedAt < weekEnd
                && recoveryQualifies(log)
        }.count
    }

    private static func recoveryQualifies(_ log: PerformanceLog) -> Bool {
        // Signal 1: title keyword (case-insensitive) — program rest-day path.
        let title = log.title.lowercased()
        if recoveryKeywords.contains(where: { title.contains($0) }) { return true }
        // Signal 2: any block carries the mobility category label — standalone routine path.
        return log.blocks.contains { ($0.notes ?? "") == RoutineCategory.mobility.label }
    }

    // MARK: - Engine (CardioSession)

    /// In-week qualifying cardio completions, counted by `CardioSession.date`.
    static func qualifyingCardioCount(
        weekStart: Date,
        committedAt: Date,
        cardioSessions: [CardioSession]
    ) -> Int {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        let lowerBound = max(weekStart, committedAt)
        return cardioSessions.filter { session in
            session.date >= lowerBound && session.date < weekEnd
        }.count
    }

    private static let recoveryKeywords = ["recovery", "mobility"]
}
