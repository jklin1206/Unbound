import Foundation
import UserNotifications

struct NotificationSchedulePlan: Equatable {
    var identifiersToCancel: [String]
    var requests: [LocalNotificationRequestDescriptor]

    static let empty = NotificationSchedulePlan(
        identifiersToCancel: [],
        requests: []
    )
}

struct LocalNotificationRequestDescriptor: Equatable {
    enum Trigger: Equatable {
        case calendar(DateComponents, repeats: Bool)
        case timeInterval(TimeInterval, repeats: Bool)
    }

    var identifier: String
    var title: String
    var body: String
    var trigger: Trigger
    var sound: Bool

    init(
        identifier: String,
        title: String,
        body: String,
        trigger: Trigger,
        sound: Bool = true
    ) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.trigger = trigger
        self.sound = sound
    }

    func makeRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound {
            content.sound = .default
        }

        let notificationTrigger: UNNotificationTrigger
        switch trigger {
        case .calendar(let components, let repeats):
            notificationTrigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: repeats
            )
        case .timeInterval(let interval, let repeats):
            notificationTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, interval),
                repeats: repeats
            )
        }

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: notificationTrigger
        )
    }
}
