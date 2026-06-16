// UNBOUND/Services/Trials/VowLogMatcher.swift
import Foundation

/// Counts logged sessions that qualify for an auto-verified vow lane within the
/// bound week (spec §7). Recovery/Engine only; Fuel is self-report.
///
/// Lane → log qualifier (recon, Binding Vows v2 Core-2):
/// `WorkoutLog` has **no `source` field** — its only durable lane signal is
/// `plannedWorkoutName` (copied from `PerformanceLog.title` in
/// `TrainingSessionAdapters.workoutLog(from:)`). So we match on the title string
/// that the real recovery / cardio logging stamps:
///   - Recovery sessions title as "Recovery Day" / "Recovery Reset" / "Mobility flow"
///     → match `recovery` or `mobility`.
///   - Cardio sessions title as "<Type> Session" (Run / Cycling / Row / …) and
///     the in-app logger reads "cardio" → match `cardio` or a known cardio modality.
/// Fuel never log-matches (self-report taps only).
///
/// NOTE for Core-3: recovery days (logged as `.routine` blocks) and standalone
/// cardio (stored as `CardioSession`, never a `WorkoutLog`) are currently
/// filtered out of `WorkoutLogService.fetchRecentLogs` upstream, so this matcher
/// only fires on data that already reaches the `[WorkoutLog]` stream. Wiring the
/// recovery/cardio completion sources into that stream is Core-3 / Phase-4 work.
enum VowLogMatcher {
    static func qualifyingCount(lane: VowLane, weekStart: Date, logs: [WorkoutLog]) -> Int {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        return logs.filter { log in
            guard let completedAt = log.completedAt else { return false }
            return completedAt >= weekStart
                && completedAt < weekEnd
                && qualifies(lane: lane, log: log)
        }.count
    }

    private static func qualifies(lane: VowLane, log: WorkoutLog) -> Bool {
        let name = log.plannedWorkoutName.lowercased()
        switch lane {
        case .recovery:
            return recoveryKeywords.contains { name.contains($0) }
        case .engine:
            return engineKeywords.contains { name.contains($0) }
        case .fuel:
            return false  // self-report, never log-matched
        }
    }

    private static let recoveryKeywords = ["recovery", "mobility"]
    private static let engineKeywords = [
        "cardio", "run", "jog", "walk", "bike", "cycle", "cycling",
        "row", "swim", "conditioning"
    ]
}
