import Foundation
import UserNotifications

protocol RestNotifying: Sendable {
    func requestAuthIfNeeded() async
    func schedule(after seconds: TimeInterval, title: String, body: String)
    func cancelPending()
}

/// Thin wrapper over UNUserNotificationCenter. Behaviour is exercised via the
/// RestTimerModel tests using a spy; this concrete impl is build-verified.
final class RestNotifier: RestNotifying, @unchecked Sendable {
    static let shared = RestNotifier()
    private let id = "unbound.rest.timer"
    private let center = UNUserNotificationCenter.current()

    func requestAuthIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(after seconds: TimeInterval, title: String, body: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }
}
