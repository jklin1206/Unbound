import Foundation

/// Pure helpers for determining where we are in the current generated program.
///
/// Used by the home UI to show "days remaining" and by the rollover flow
/// to detect when to prompt a Checkpoint / generate the next Arc. Normal
/// Arcs are 28 days; first-run Calibration Week stays 7 days.
///
/// Distinct from `ProgramPhaseEngine` — the legacy phase engine computes
/// Accumulation/Intensification/etc. signals from logs + progression. This
/// scheduler does only one thing: map (program.createdAt, now) → day number.
enum BlockRolloverScheduler {

    /// True if the current program has run its full declared duration.
    static func shouldRollover(program: TrainingProgram, now: Date = Date()) -> Bool {
        daysRemaining(program: program, now: now) == 0
    }

    /// Days left in the current Arc or Calibration Week, clamped to [0, durationDays].
    static func daysRemaining(program: TrainingProgram, now: Date = Date()) -> Int {
        let elapsedDays = Int(now.timeIntervalSince(program.createdAt) / 86400)
        let remaining = program.durationDays - elapsedDays
        return max(0, remaining)
    }

    /// 1-indexed current day within the Arc or Calibration Week, clamped to [1, durationDays].
    static func currentDayNumber(program: TrainingProgram, now: Date = Date()) -> Int {
        let elapsedDays = Int(now.timeIntervalSince(program.createdAt) / 86400)
        let dayNumber = elapsedDays + 1
        return min(program.durationDays, max(1, dayNumber))
    }
}
