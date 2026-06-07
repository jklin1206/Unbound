import Foundation
import UserNotifications

protocol RestNotifying: Sendable {
    func requestAuthIfNeeded() async
    func schedule(after seconds: TimeInterval, title: String, body: String)
    func cancelPending()
}

/// Schedules the one active rest timer as a local notification so it can alert
/// even if the user leaves the app.
final class RestNotifier: RestNotifying, @unchecked Sendable {
    static let shared = RestNotifier()
    static let identifier = "unbound.rest.timer"
    private let center = UNUserNotificationCenter.current()

    func requestAuthIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(after seconds: TimeInterval, title: String, body: String) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: trigger
        )

        Task {
            await requestAuthIfNeeded()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus.allowsRestTimerScheduling else { return }
            try? await center.add(request)
        }
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}

private extension UNAuthorizationStatus {
    var allowsRestTimerScheduling: Bool {
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
