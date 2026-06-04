import Foundation
import UserNotifications

protocol RestNotifying: Sendable {
    func requestAuthIfNeeded() async
    func schedule(after seconds: TimeInterval, title: String, body: String)
    func cancelPending()
}

/// Keeps rest timers in-app only. Older builds scheduled a lock-screen alert
/// for every rest period, so this concrete impl now just clears stale requests.
final class RestNotifier: RestNotifying, @unchecked Sendable {
    static let shared = RestNotifier()
    private let id = "unbound.rest.timer"
    private let center = UNUserNotificationCenter.current()

    func requestAuthIfNeeded() async {
    }

    func schedule(after _: TimeInterval, title _: String, body _: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }
}
