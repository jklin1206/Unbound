import Foundation

/// Pure helpers for determining where we are in the current 2-week block.
///
/// Used by the home UI to show "days remaining" and by the rollover flow
/// to detect when to prompt a re-scan / generate the next block.
///
/// Distinct from `ProgramPhaseEngine` — the legacy phase engine computes
/// Accumulation/Intensification/etc. signals from logs + progression. This
/// scheduler does only one thing: map (program.createdAt, now) → day number.
enum BlockRolloverScheduler {

    /// True if the current block has run its full 14-day duration.
    static func shouldRollover(program: TrainingProgram, now: Date = Date()) -> Bool {
        daysRemaining(program: program, now: now) == 0
    }

    /// Days left in the current block, clamped to [0, durationDays].
    static func daysRemaining(program: TrainingProgram, now: Date = Date()) -> Int {
        let elapsedDays = Int(now.timeIntervalSince(program.createdAt) / 86400)
        let remaining = program.durationDays - elapsedDays
        return max(0, remaining)
    }

    /// 1-indexed current day within the block, clamped to [1, durationDays].
    static func currentDayNumber(program: TrainingProgram, now: Date = Date()) -> Int {
        let elapsedDays = Int(now.timeIntervalSince(program.createdAt) / 86400)
        let dayNumber = elapsedDays + 1
        return min(program.durationDays, max(1, dayNumber))
    }
}
