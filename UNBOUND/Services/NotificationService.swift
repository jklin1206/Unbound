import Foundation

// MARK: - NotificationService
//
// Compatibility facade for older call sites. The scheduling implementation
// lives under Services/Notifications so preferences, schedule planning, and
// notification-center side effects can be tested separately.

enum NotificationService {

    static func scheduleWorkoutReminders(
        workoutTime: WorkoutTime,
        trainingDays: Set<Weekday>,
        minuteOfDay: Int? = nil
    ) async {
        await NotificationCoordinator.shared.scheduleWorkoutReminders(
            workoutTime: workoutTime,
            trainingDays: trainingDays,
            minuteOfDay: minuteOfDay
        )
    }

    static func cancelWorkoutReminders() {
        NotificationCoordinator.shared.cancelWorkoutReminders()
    }

    static func scheduleRescanReminder() async {
        NotificationCoordinator.shared.cancelRetentionNudge()
    }

    static func cancelRescanReminder() {
        NotificationCoordinator.shared.cancelRetentionNudge()
    }

    static func applyStoredPreferences() async {
        await NotificationCoordinator.shared.applyStoredPreferences()
    }

    static func startMilestoneNotifier() {
        NotificationCoordinator.shared.startMilestoneNotifier()
    }
}
