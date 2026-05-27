import Foundation

// MARK: - NotificationService
//
// Compatibility facade for older call sites. The scheduling implementation
// lives under Services/Notifications so preferences, schedule planning, and
// notification-center side effects can be tested separately.

enum NotificationService {

    static func scheduleWorkoutReminders(
        workoutTime: WorkoutTime,
        trainingDays: Set<Weekday>
    ) async {
        await NotificationCoordinator.shared.scheduleWorkoutReminders(
            workoutTime: workoutTime,
            trainingDays: trainingDays
        )
    }

    static func cancelWorkoutReminders() {
        NotificationCoordinator.shared.cancelWorkoutReminders()
    }

    static func scheduleRescanReminder() async {
        await NotificationCoordinator.shared.scheduleRetentionNudge(
            daysAfterAnchor: 30
        )
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
