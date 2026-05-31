import Foundation

// MARK: - Streak policy (Liftoff-style: day-based, program-agnostic)
//
// Matches the Liftoff FAQ rule exactly — the streak counts DAYS, not sessions,
// and does NOT depend on following the program:
//   • Posting on non-consecutive days credits the gap (Mon → Wed = +2; the rest
//     day is auto-counted).
//   • The streak breaks only after 3 days with no workout — i.e. you must log
//     within a 3-day gap (Mon → must post by Thu; Fri is too late).
//   • Rest days are automatic; no program / scheduled-day coupling.
//
// `resetWindowDays` and `activeProgram` are accepted for call-site compatibility
// but intentionally unused — the rule is purely day-gap based.
enum ProgramAwareStreakPolicy {
    /// The maximum gap (in days) between logged sessions that keeps the streak.
    /// A 3-day gap is the last valid day; a 4-day gap (3 missed days) breaks it.
    static let maxGapDays = 3

    static func shouldExtendStreak(
        from lastSessionDate: Date,
        to sessionDate: Date,
        currentStreak: Int,
        resetWindowDays: Int = 0,
        activeProgram: TrainingProgram? = nil,
        calendar: Calendar = .current
    ) -> (streak: Int, extended: Bool, broken: Bool) {
        let lastDay = calendar.startOfDay(for: lastSessionDate)
        let sessionDay = calendar.startOfDay(for: sessionDate)

        let gapDays = calendar.dateComponents([.day], from: lastDay, to: sessionDay).day ?? 0

        // Same day (or a clock skew) — one session per day counts.
        guard gapDays > 0 else {
            return (max(currentStreak, 1), false, false)
        }

        // Logged within the grace window — credit the elapsed days (rest days
        // included), Liftoff-style.
        if gapDays <= maxGapDays {
            return (currentStreak + gapDays, true, false)
        }

        // 3+ missed days — streak broken; this session starts a fresh run at 1.
        return (1, false, true)
    }
}
