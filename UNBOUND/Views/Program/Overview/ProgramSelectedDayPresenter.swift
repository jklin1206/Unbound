import SwiftUI

struct ProgramSelectedDayPresentation {
    let headerLabel: String
    let title: String
    let contextLabel: String
    let badge: ProgramDayBadgeState
    let heroTint: Color
    let metrics: [ProgramCommandMetricModel]
    let skillNodes: [SkillNode]
}

enum ProgramSelectedDayPresenter {
    static func presentation(
        day: ProgramDay?,
        date: Date,
        isToday: Bool,
        isCompleted: Bool,
        workout: Workout?,
        skillNodes: [SkillNode],
        calendar: Calendar = .current
    ) -> ProgramSelectedDayPresentation {
        let isCalibration = Self.isCalibrationDay(day)
        let heroTint = isCalibration
            ? Color.unbound.accent
            : (isToday ? Color.unbound.coachCyan : Color.unbound.textPrimary.opacity(0.72))

        return ProgramSelectedDayPresentation(
            headerLabel: headerLabel(for: day, isToday: isToday, isCalibration: isCalibration),
            title: title(for: day, skillNodes: skillNodes),
            contextLabel: contextLabel(for: day, date: date),
            badge: badgeState(day: day, isToday: isToday, isCompleted: isCompleted, isCalibration: isCalibration),
            heroTint: heroTint,
            metrics: [
                ProgramCommandMetricModel(
                    title: "\(exerciseCountLabel(for: day, workout: workout)) moves",
                    icon: "list.bullet.clipboard",
                    tint: heroTint
                ),
                ProgramCommandMetricModel(
                    title: durationLabel(for: day, workout: workout),
                    icon: day?.isRestDay == true ? "leaf.fill" : "timer",
                    tint: Color.unbound.accent,
                    foreground: Color.unbound.textPrimary
                ),
                ProgramCommandMetricModel(
                    title: ProgramSkillFocusResolver.metricTitle(
                        for: skillNodes,
                        day: day,
                        isCalibration: isCalibration
                    ),
                    icon: ProgramSkillFocusResolver.metricIcon(
                        for: skillNodes,
                        day: day,
                        isCalibration: isCalibration
                    ),
                    tint: day?.isRestDay == true ? Color.unbound.textSecondary : Color.unbound.success
                )
            ],
            skillNodes: skillNodes
        )
    }

    static func isCalibrationDay(_ day: ProgramDay?) -> Bool {
        guard let day, !day.isRestDay else { return false }
        if day.label.localizedCaseInsensitiveContains("Calibration") { return true }
        return day.workout?.notes?.localizedCaseInsensitiveContains("Calibration:") == true
    }

    static func badgeState(
        day: ProgramDay?,
        isToday: Bool,
        isCompleted: Bool,
        isCalibration: Bool
    ) -> ProgramDayBadgeState {
        if isCompleted { return .completed }
        if day?.isRestDay == true { return .rest }
        if isCalibration { return .calibration }
        if isToday { return .today }
        return .planned
    }

    private static func headerLabel(
        for day: ProgramDay?,
        isToday: Bool,
        isCalibration: Bool
    ) -> String {
        if isCalibration { return "CALIBRATION" }
        if isToday { return "DAILY QUEST" }
        if let day { return "DAY \(day.dayNumber) QUEST" }
        return "DAILY"
    }

    private static func title(
        for day: ProgramDay?,
        skillNodes: [SkillNode]
    ) -> String {
        guard let day else { return "NO QUEST" }
        if day.isRestDay { return "RECOVERY QUEST" }
        if let skillTitle = ProgramSkillFocusResolver.compactTitle(for: skillNodes) {
            return skillTitle
        }
        return day.workout?.name.uppercased() ?? "NO QUEST"
    }

    private static func contextLabel(for day: ProgramDay?, date: Date) -> String {
        let dateText = longDateLabel(for: date).uppercased()
        guard let day, !day.isRestDay else { return dateText }
        let base = day.workout?.name.uppercased() ?? day.label.uppercased()
        return "\(dateText) - \(base)"
    }

    private static func exerciseCountLabel(for day: ProgramDay?, workout: Workout?) -> String {
        guard let day, !day.isRestDay, let workout else { return "0" }
        return "\(workout.mainExercises.count)"
    }

    private static func durationLabel(for day: ProgramDay?, workout: Workout?) -> String {
        guard let day, !day.isRestDay, let workout else { return "REC" }
        return "~\(workout.estimatedMinutes)M"
    }

    private static func longDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date)
    }
}
