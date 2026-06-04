// UNBOUND/Services/Trials/TrialsNotificationScheduler.swift
import Foundation
import UserNotifications

/// Weekly vows stay in-app by default. This scheduler now only clears legacy
/// pending vow notifications so the lock-screen surface stays training-focused.
@MainActor
enum WeeklyVowsNotificationScheduler {

    private static let mondayId = "unbound.weekly-vow.monday-picker"
    private static let saturdayId = "unbound.weekly-vow.saturday-unlock"
    private static let sundayId = "unbound.weekly-vow.sunday-closing"
    private static let legacyIds = [
        "unbound.trial.monday-picker",
        "unbound.trial.saturday-unlock",
        "unbound.trial.sunday-closing"
    ]

    /// Idempotent. Safe to call on every ensureCurrentWeek.
    static func reschedule(for _: String, weekStart _: Date) async {
        cancelAll()
    }

    /// Cancel all 3 notifications. Called from skipThisWeek path.
    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [mondayId, saturdayId, sundayId] + legacyIds
        )
    }

}

typealias TrialsNotificationScheduler = WeeklyVowsNotificationScheduler
