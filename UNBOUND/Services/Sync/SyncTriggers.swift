import Foundation
import Network

extension Notification.Name {
    static let outboxDidEnqueue = Notification.Name("unbound.outboxDidEnqueue")
}

/// Owns the flush triggers: network-reconnect, post-write debounce.
/// Foreground (.active) is driven by the app's scenePhase (see app entry).
@MainActor
final class SyncTriggers {
    static let shared = SyncTriggers(debounce: 2.0) {
        Task { await SyncEngine.shared.flush() }
    }

    private let monitor = NWPathMonitor()
    private let debounce: TimeInterval
    private let onFire: () -> Void
    private var work: DispatchWorkItem?
    private var token: NSObjectProtocol?

    init(debounce: TimeInterval, onFire: @escaping () -> Void) {
        self.debounce = debounce; self.onFire = onFire
    }

    func start() {
        token = NotificationCenter.default.addObserver(
            forName: .outboxDidEnqueue, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleDebounced() }
        }
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in self?.onFire() }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    func stop() {
        if let token { NotificationCenter.default.removeObserver(token) }
        monitor.cancel(); work?.cancel()
    }

    private func scheduleDebounced() {
        work?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.onFire() }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: w)
    }
}
