import Foundation

struct NotificationPreferences: Codable, Equatable {
    var workoutReminders: WorkoutReminderNotificationPreferences
    var retentionNudges: RetentionNudgeNotificationPreferences
    var milestones: MilestoneNotificationPreferences
    var updatedAt: Date

    init(
        workoutReminders: WorkoutReminderNotificationPreferences = WorkoutReminderNotificationPreferences(),
        retentionNudges: RetentionNudgeNotificationPreferences = RetentionNudgeNotificationPreferences(),
        milestones: MilestoneNotificationPreferences = MilestoneNotificationPreferences(),
        updatedAt: Date = Date()
    ) {
        self.workoutReminders = workoutReminders
        self.retentionNudges = retentionNudges
        self.milestones = milestones
        self.updatedAt = updatedAt
    }
}

struct WorkoutReminderNotificationPreferences: Codable, Equatable {
    var isEnabled: Bool
    var workoutTime: WorkoutTime?
    var trainingDays: Set<Weekday>
    var minute: Int

    init(
        isEnabled: Bool = false,
        workoutTime: WorkoutTime? = nil,
        trainingDays: Set<Weekday> = [],
        minute: Int = 0
    ) {
        self.isEnabled = isEnabled
        self.workoutTime = workoutTime
        self.trainingDays = trainingDays
        self.minute = minute
    }
}

struct RetentionNudgeNotificationPreferences: Codable, Equatable {
    var isEnabled: Bool
    var anchorDate: Date?
    var daysAfterAnchor: Int
    var hour: Int
    var minute: Int

    init(
        isEnabled: Bool = true,
        anchorDate: Date? = nil,
        daysAfterAnchor: Int = 30,
        hour: Int = 9,
        minute: Int = 0
    ) {
        self.isEnabled = isEnabled
        self.anchorDate = anchorDate
        self.daysAfterAnchor = daysAfterAnchor
        self.hour = hour
        self.minute = minute
    }
}

struct MilestoneNotificationPreferences: Codable, Equatable {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}
