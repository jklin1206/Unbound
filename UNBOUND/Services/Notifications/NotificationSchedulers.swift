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

    private static func title(for workoutTime: WorkoutTime) -> String {
        let key: L10n.Key
        let defaultValue: String

        switch workoutTime {
        case .earlyMorning:
            key = .notificationWorkoutEarlyMorningTitle
            defaultValue = "[ SYSTEM ] DAWN DIRECTIVE"
        case .morning:
            key = .notificationWorkoutMorningTitle
            defaultValue = "[ SYSTEM ] MORNING DIRECTIVE"
        case .lunch:
            key = .notificationWorkoutLunchTitle
            defaultValue = "[ SYSTEM ] MIDDAY DIRECTIVE"
        case .afternoon:
            key = .notificationWorkoutAfternoonTitle
            defaultValue = "[ SYSTEM ] TRAINING WINDOW"
        case .evening:
            key = .notificationWorkoutEveningTitle
            defaultValue = "[ SYSTEM ] EVENING DIRECTIVE"
        case .lateNight:
            key = .notificationWorkoutLateNightTitle
            defaultValue = "[ SYSTEM ] NIGHT DIRECTIVE"
        case .varies:
            key = .notificationWorkoutVariesTitle
            defaultValue = "[ SYSTEM ] DIRECTIVE ISSUED"
        }

        return L10n.string(key, defaultValue: defaultValue)
    }

    private static func body(for workoutTime: WorkoutTime) -> String {
        let key: L10n.Key
        let defaultValue: String

        switch workoutTime {
        case .earlyMorning:
            key = .notificationWorkoutEarlyMorningBody
            defaultValue = "The day is quiet. Complete today's Arc."
        case .morning:
            key = .notificationWorkoutMorningBody
            defaultValue = "Set the pace. Today's Arc is ready."
        case .lunch:
            key = .notificationWorkoutLunchBody
            defaultValue = "Your midday window is open. Begin the Arc."
        case .afternoon:
            key = .notificationWorkoutAfternoonBody
            defaultValue = "Your training window is open. Begin the Arc."
        case .evening:
            key = .notificationWorkoutEveningBody
            defaultValue = "Close the day by completing today's Arc."
        case .lateNight:
            key = .notificationWorkoutLateNightBody
            defaultValue = "The night window is open. Complete today's Arc."
        case .varies:
            key = .notificationWorkoutVariesBody
            defaultValue = "Today's training is ready. Begin your Arc."
        }

        return L10n.string(key, defaultValue: defaultValue)
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
                defaultValue: "[ SYSTEM ] SCAN DUE"
            ),
            body: L10n.string(
                .notificationRetentionRescanBody,
                defaultValue: "Your 30-day checkpoint is ready. Record new proof."
            ),
            trigger: .calendar(components, repeats: false)
        )

        return NotificationSchedulePlan(
            identifiersToCancel: [Self.identifier],
            requests: [request]
        )
    }
}
