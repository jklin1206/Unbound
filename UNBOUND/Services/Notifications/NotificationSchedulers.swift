import Foundation

struct TrainTimeNotificationScheduler {
    static let identifierPrefix = "com.unbound.workout"

    var allIdentifiers: [String] {
        Weekday.allCases.map(Self.identifier(for:))
    }

    func plan(preferences: NotificationPreferences) -> NotificationSchedulePlan {
        let workout = preferences.workoutReminders
        guard workout.isEnabled,
              let workoutTime = workout.workoutTime,
              !workout.trainingDays.isEmpty
        else {
            return NotificationSchedulePlan(
                identifiersToCancel: allIdentifiers,
                requests: []
            )
        }

        let requests = workout.trainingDays
            .sorted { $0.calendarWeekday < $1.calendarWeekday }
            .map { day in
                var components = DateComponents()
                components.weekday = day.calendarWeekday
                components.hour = workout.hour.map { min(max($0, 0), 23) } ?? workoutTime.notificationHour
                components.minute = min(max(workout.minute, 0), 59)

                return LocalNotificationRequestDescriptor(
                    identifier: Self.identifier(for: day),
                    title: Self.title(for: workoutTime),
                    body: Self.body(for: workoutTime),
                    trigger: .calendar(components, repeats: true)
                )
            }

        return NotificationSchedulePlan(
            identifiersToCancel: allIdentifiers,
            requests: requests
        )
    }

    static func identifier(for day: Weekday) -> String {
        "\(identifierPrefix).\(day.rawValue)"
    }

    private static func title(for _: WorkoutTime) -> String {
        L10n.string(.notificationWorkoutVariesTitle, defaultValue: "Time to go to the gym.")
    }

    private static func body(for _: WorkoutTime) -> String {
        L10n.string(.notificationWorkoutVariesBody, defaultValue: "Your workout is scheduled. Head in and start.")
    }
}

struct RetentionNudgeScheduler {
    static let identifier = "com.unbound.rescan"

    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func plan(
        preferences: NotificationPreferences,
        now: Date = Date()
    ) -> NotificationSchedulePlan {
        let retention = preferences.retentionNudges
        guard retention.isEnabled,
              let anchorDate = retention.anchorDate,
              let deliveryDay = calendar.date(
                byAdding: .day,
                value: max(1, retention.daysAfterAnchor),
                to: anchorDate
              )
        else {
            return NotificationSchedulePlan(
                identifiersToCancel: [Self.identifier],
                requests: []
            )
        }

        var components = calendar.dateComponents([.year, .month, .day], from: deliveryDay)
        components.hour = min(max(retention.hour, 0), 23)
        components.minute = min(max(retention.minute, 0), 59)

        let scheduledDate = calendar.date(from: components) ?? deliveryDay
        guard scheduledDate > now else {
            return NotificationSchedulePlan(
                identifiersToCancel: [Self.identifier],
                requests: []
            )
        }

        let request = LocalNotificationRequestDescriptor(
            identifier: Self.identifier,
            title: L10n.string(
                .notificationRetentionRescanTitle,
                defaultValue: "30-day check. Time for a checkpoint."
            ),
            body: L10n.string(
                .notificationRetentionRescanBody,
                defaultValue: "A month of reps. Lock in the proof."
            ),
            trigger: .calendar(components, repeats: false)
        )

        return NotificationSchedulePlan(
            identifiersToCancel: [Self.identifier],
            requests: [request]
        )
    }
}
