import Foundation
import UserNotifications

protocol LocalNotificationScheduling: AnyObject {
    func notificationSettings() async -> UNNotificationSettings
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: LocalNotificationScheduling {}

final class NotificationCoordinator {
    static let shared = NotificationCoordinator()

    private let store: NotificationPreferencesStore
    private let center: any LocalNotificationScheduling
    private let trainTimeScheduler: TrainTimeNotificationScheduler
    private let retentionScheduler: RetentionNudgeScheduler
    private let milestoneNotifier: MilestoneNotificationNotifier

    init(
        store: NotificationPreferencesStore = .shared,
        center: any LocalNotificationScheduling = UNUserNotificationCenter.current(),
        trainTimeScheduler: TrainTimeNotificationScheduler = TrainTimeNotificationScheduler(),
        retentionScheduler: RetentionNudgeScheduler = RetentionNudgeScheduler()
    ) {
        self.store = store
        self.center = center
        self.trainTimeScheduler = trainTimeScheduler
        self.retentionScheduler = retentionScheduler
        self.milestoneNotifier = MilestoneNotificationNotifier(
            store: store,
            center: center
        )
    }

    func startMilestoneNotifier() {
        milestoneNotifier.start()
    }

    func applyStoredPreferences() async {
        startMilestoneNotifier()
        let preferences = store.load()
        await schedule(plan: trainTimeScheduler.plan(preferences: preferences))
        await schedule(plan: retentionScheduler.plan(preferences: preferences))
    }

    func scheduleWorkoutReminders(
        workoutTime: WorkoutTime,
        trainingDays: Set<Weekday>
    ) async {
        startMilestoneNotifier()
        let preferences = store.update { preferences in
            preferences.workoutReminders.isEnabled = true
            preferences.workoutReminders.workoutTime = workoutTime
            preferences.workoutReminders.trainingDays = trainingDays
        }
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
        startMilestoneNotifier()
        let preferences = store.update { preferences in
            preferences.retentionNudges.isEnabled = true
            preferences.retentionNudges.anchorDate = anchorDate
            preferences.retentionNudges.daysAfterAnchor = daysAfterAnchor
        }
        await schedule(plan: retentionScheduler.plan(preferences: preferences))
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
