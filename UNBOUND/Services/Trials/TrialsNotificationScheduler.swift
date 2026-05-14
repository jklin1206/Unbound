// UNBOUND/Services/Trials/TrialsNotificationScheduler.swift
import Foundation
import UserNotifications

/// Schedules 3 local notifications per week per user (Monday picker reminder,
/// Saturday capstone unlock, Sunday window-closing reminder). Notifications
/// are accelerants, not gates — system works without permission.
@MainActor
enum TrialsNotificationScheduler {

    private static let mondayId = "unbound.trial.monday-picker"
    private static let saturdayId = "unbound.trial.saturday-unlock"
    private static let sundayId = "unbound.trial.sunday-closing"

    /// Request permission + reschedule notifications for the given week.
    /// Idempotent. Safe to call on every ensureCurrentWeek.
    static func reschedule(for userId: String, weekStart: Date) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus != .denied else { return }
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        // Clear prior schedule.
        center.removePendingNotificationRequests(withIdentifiers: [mondayId, saturdayId, sundayId])

        // Monday 09:00 — picker reminder
        await schedule(
            id: mondayId,
            title: "This week's trials are ready",
            body: "Choose your direction.",
            on: weekStart.addingTimeInterval(9 * 3600)
        )

        // Saturday 08:00 — capstone unlock
        await schedule(
            id: saturdayId,
            title: "Capstone unlocked",
            body: "Today's the day.",
            on: weekStart.addingTimeInterval(5 * 86_400 + 8 * 3600)
        )

        // Sunday 18:00 — closing reminder
        await schedule(
            id: sundayId,
            title: "Capstone window closes in 6 hours",
            body: "Last chance.",
            on: weekStart.addingTimeInterval(6 * 86_400 + 18 * 3600)
        )
    }

    /// Cancel all 3 notifications. Called from skipThisWeek path.
    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [mondayId, saturdayId, sundayId]
        )
    }

    private static func schedule(id: String, title: String, body: String, on date: Date) async {
        // Don't schedule notifications in the past.
        guard date > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
