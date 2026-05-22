import Foundation

enum ProgramAwareStreakPolicy {
    static func shouldExtendStreak(
        from lastSessionDate: Date,
        to sessionDate: Date,
        currentStreak: Int,
        resetWindowDays: Int,
        activeProgram: TrainingProgram?,
        calendar: Calendar = .current
    ) -> (streak: Int, extended: Bool, broken: Bool) {
        let lastDay = calendar.startOfDay(for: lastSessionDate)
        let sessionDay = calendar.startOfDay(for: sessionDate)

        if lastDay == sessionDay {
            return (max(currentStreak, 1), false, false)
        }

        let gapDays = calendar.dateComponents([.day], from: lastDay, to: sessionDay).day ?? 0
        guard gapDays > 0 else {
            return (max(currentStreak, 1), false, false)
        }

        if gapDays <= 2 {
            return (currentStreak + 1, true, false)
        }

        let resetWindow = max(2, resetWindowDays)
        if gapDays <= resetWindow,
           skippedDaysAreAllRecovery(from: lastDay, to: sessionDay, in: activeProgram, calendar: calendar) {
            return (currentStreak + 1, true, false)
        }

        return (1, false, true)
    }

    static func skippedDaysAreAllRecovery(
        from lastSessionDay: Date,
        to sessionDay: Date,
        in program: TrainingProgram?,
        calendar: Calendar = .current
    ) -> Bool {
        guard let program, !program.days.isEmpty else { return false }

        var probe = calendar.date(byAdding: .day, value: 1, to: lastSessionDay)
        while let date = probe, date < sessionDay {
            guard let day = programDay(for: date, in: program, calendar: calendar),
                  day.isRestDay || day.workout == nil else {
                return false
            }
            probe = calendar.date(byAdding: .day, value: 1, to: date)
        }

        return true
    }

    static func programDay(
        for date: Date,
        in program: TrainingProgram,
        calendar: Calendar = .current
    ) -> ProgramDay? {
        guard !program.days.isEmpty else { return nil }
        let start = calendar.startOfDay(for: program.createdAt)
        let target = calendar.startOfDay(for: date)
        let daysSinceStart = max(0, calendar.dateComponents([.day], from: start, to: target).day ?? 0)
        let dayIndex = daysSinceStart % program.days.count
        return program.days[dayIndex]
    }
}
