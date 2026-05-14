import Foundation
import UserNotifications

// MARK: - NotificationService
//
// Schedules and cancels local workout reminders based on the user's
// chosen training days and workout time from onboarding.
//
// One repeating `UNCalendarNotificationTrigger` per training day, firing
// weekly at the hour that matches their `WorkoutTime` preference.
// Identifiers are stable so rescheduling (e.g. from Settings) replaces
// existing requests cleanly without duplicating.

enum NotificationService {

    // MARK: - Workout reminders

    static func scheduleWorkoutReminders(
        workoutTime: WorkoutTime,
        trainingDays: Set<Weekday>
    ) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        guard !trainingDays.isEmpty else { return }

        // Cancel existing workout reminders before writing new ones.
        center.removePendingNotificationRequests(withIdentifiers: workoutReminderIds)

        let hour = workoutTime.notificationHour

        for day in trainingDays {
            let content = UNMutableNotificationContent()
            content.title = title(for: workoutTime)
            content.body  = body(for: workoutTime)
            content.sound = .default

            var components = DateComponents()
            components.weekday = day.calendarWeekday
            components.hour    = hour
            components.minute  = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: workoutReminderId(for: day),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    static func cancelWorkoutReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: workoutReminderIds)
    }

    // MARK: - Rescan reminder (30 days out)

    static func scheduleRescanReminder() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        center.removePendingNotificationRequests(withIdentifiers: [rescanReminderId])

        let content = UNMutableNotificationContent()
        content.title = "30-day check. Time to rescan."
        content.body  = "A month of reps. Your frame has moved. Lock in the proof."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 30 * 24 * 60 * 60,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: rescanReminderId,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - Identifiers

    private static let rescanReminderId = "com.unbound.rescan"

    private static var workoutReminderIds: [String] {
        Weekday.allCases.map { workoutReminderId(for: $0) }
    }

    private static func workoutReminderId(for day: Weekday) -> String {
        "com.unbound.workout.\(day.rawValue)"
    }

    // MARK: - Copy

    private static func title(for time: WorkoutTime) -> String {
        switch time {
        case .earlyMorning: return "Early birds get the reps."
        case .morning:      return "Morning session. Go."
        case .lunch:        return "Midday window is open."
        case .afternoon:    return "Afternoon grind."
        case .evening:      return "Evening session. Don't skip."
        case .lateNight:    return "Late-night rep. Most people sleep."
        case .varies:       return "Time to train."
        }
    }

    private static func body(for time: WorkoutTime) -> String {
        switch time {
        case .earlyMorning: return "Gym is empty. Reps are yours."
        case .morning:      return "Set the tone before the day sets it for you."
        case .lunch:        return "This is the one most people skip. You're not most people."
        case .afternoon:    return "Afternoon window. Your protocol is waiting."
        case .evening:      return "The day's almost done. Finish it right."
        case .lateNight:    return "Everyone else is asleep. You're building."
        case .varies:       return "Your session is on the schedule. Earn it."
        }
    }
}
