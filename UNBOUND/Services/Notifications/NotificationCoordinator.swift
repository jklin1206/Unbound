import Foundation
import UserNotifications

protocol LocalNotificationScheduling: AnyObject {
    func notificationSettings() async -> UNNotificationSettings
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: LocalNotificationScheduling {}

final class NotificationCoordinator {
    static let shared = NotificationCoordinator()

    private let store: NotificationPreferencesStore
    private let center: any LocalNotificationScheduling
    private let trainTimeScheduler: TrainTimeNotificationScheduler
    private let milestoneNotifier: MilestoneNotificationNotifier

    init(
        store: NotificationPreferencesStore = .shared,
        center: any LocalNotificationScheduling = UNUserNotificationCenter.current(),
        trainTimeScheduler: TrainTimeNotificationScheduler = TrainTimeNotificationScheduler()
    ) {
        self.store = store
        self.center = center
        self.trainTimeScheduler = trainTimeScheduler
        self.milestoneNotifier = MilestoneNotificationNotifier(
            store: store,
            center: center
        )
    }

    func startMilestoneNotifier() {
        milestoneNotifier.start()
    }

    func applyStoredPreferences() async {
        let preferences = trainingOnlyPreferences()
        milestoneNotifier.stop()
        await cancelNonWorkoutNotifications()
        await schedule(plan: trainTimeScheduler.plan(preferences: preferences))
    }

    func scheduleWorkoutReminders(
        workoutTime: WorkoutTime,
        trainingDays: Set<Weekday>,
        minuteOfDay: Int? = nil
    ) async {
        let preferences = store.update { preferences in
            preferences.workoutReminders.isEnabled = true
            preferences.workoutReminders.workoutTime = workoutTime
            preferences.workoutReminders.trainingDays = trainingDays
            if let minuteOfDay {
                preferences.workoutReminders.hour = min(max(minuteOfDay / 60, 0), 23)
                preferences.workoutReminders.minute = min(max(minuteOfDay % 60, 0), 59)
            } else {
                preferences.workoutReminders.hour = nil
                preferences.workoutReminders.minute = 0
            }
            preferences.retentionNudges.isEnabled = false
            preferences.milestones.isEnabled = false
        }
        milestoneNotifier.stop()
        await cancelNonWorkoutNotifications()
        await schedule(plan: trainTimeScheduler.plan(preferences: preferences))
    }

    func cancelWorkoutReminders() {
        _ = store.update { preferences in
            preferences.workoutReminders.isEnabled = false
        }
        center.removePendingNotificationRequests(
            withIdentifiers: trainTimeScheduler.allIdentifiers
        )
    }

    func scheduleRetentionNudge(
        anchorDate: Date = Date(),
        daysAfterAnchor: Int = 30
    ) async {
        cancelRetentionNudge()
    }

    func cancelRetentionNudge() {
        _ = store.update { preferences in
            preferences.retentionNudges.isEnabled = false
        }
        center.removePendingNotificationRequests(
            withIdentifiers: [RetentionNudgeScheduler.identifier]
        )
    }

    private func schedule(plan: NotificationSchedulePlan) async {
        center.removePendingNotificationRequests(withIdentifiers: plan.identifiersToCancel)

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus.allowsLocalNotificationScheduling else {
            return
        }

        for descriptor in plan.requests {
            try? await center.add(descriptor.makeRequest())
        }
    }

    private func trainingOnlyPreferences() -> NotificationPreferences {
        let preferences = store.load()
        guard preferences.retentionNudges.isEnabled || preferences.milestones.isEnabled else {
            return preferences
        }

        return store.update { preferences in
            preferences.retentionNudges.isEnabled = false
            preferences.milestones.isEnabled = false
        }
    }

    private func cancelNonWorkoutNotifications() async {
        var identifiers = Set(knownNonWorkoutNotificationIdentifiers)

        let stalePendingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { identifier in
                nonWorkoutNotificationPrefixes.contains { prefix in
                    identifier.hasPrefix(prefix)
                }
            }
        identifiers.formUnion(stalePendingIdentifiers)

        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(identifiers))
        }
    }

    private var knownNonWorkoutNotificationIdentifiers: [String] {
        [
            RetentionNudgeScheduler.identifier,
            "unbound.weekly-vow.monday-picker",
            "unbound.weekly-vow.saturday-unlock",
            "unbound.weekly-vow.sunday-closing",
            "unbound.trial.monday-picker",
            "unbound.trial.saturday-unlock",
            "unbound.trial.sunday-closing"
        ]
    }

    private var nonWorkoutNotificationPrefixes: [String] {
        [
            "\(MilestoneNotificationPlanner.identifierPrefix).",
            "unbound.weekly-vow.",
            "unbound.trial."
        ]
    }
}

private extension UNAuthorizationStatus {
    var allowsLocalNotificationScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
