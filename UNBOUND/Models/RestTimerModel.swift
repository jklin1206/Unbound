import Foundation
import Combine

/// Owns rest-countdown state. Survives its own UI dismissal (isVisible vs
/// isActive). Drives a haptic + local notification at zero. The view starts a
/// 1s Timer and calls `tick()`; the model is otherwise pure and unit-tested.
@MainActor
final class RestTimerModel: ObservableObject {
    @Published private(set) var remaining: Int = 0
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var isActive: Bool = false
    private(set) var nextLabel: String = ""

    var onElapsed: (() -> Void)?
    private let notifier: RestNotifying

    init(notifier: RestNotifying) { self.notifier = notifier }

    func start(seconds: Int, nextLabel: String) {
        if isActive { notifier.cancelPending() }
        self.nextLabel = nextLabel
        remaining = max(1, seconds)
        isVisible = true
        isActive = true
        notifier.schedule(after: TimeInterval(remaining),
                          title: "Rest complete",
                          body: nextLabel.isEmpty ? "Back to it." : "Next: \(nextLabel)")
    }

    func tick() {
        guard isActive else { return }
        remaining -= 1
        if remaining <= 0 { fire() }
    }

    func addThirty() {
        guard isActive else { return }
        remaining += 30
        notifier.schedule(after: TimeInterval(remaining),
                          title: "Rest complete",
                          body: nextLabel.isEmpty ? "Back to it." : "Next: \(nextLabel)")
    }

    func dismiss() { isVisible = false }

    private func fire() {
        isActive = false
        isVisible = false
        notifier.cancelPending()
        onElapsed?()
    }
}
