import Foundation
import Combine

/// Owns rest-countdown state. Survives its own UI dismissal (isVisible vs
/// isActive). Countdown state is date-based so it stays correct across app
/// backgrounding and across screens that observe the shared model.
@MainActor
final class RestTimerModel: ObservableObject {
    static let shared = RestTimerModel(
        notifier: RestNotifier.shared,
        persistenceKey: "unbound.restTimer.state"
    )

    @Published private(set) var remaining: Int = 0
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var isActive: Bool = false
    private(set) var nextLabel: String = ""

    var onElapsed: (() -> Void)?
    private let notifier: RestNotifying
    private let persistenceKey: String?
    private var endsAt: Date?

    init(notifier: RestNotifying, persistenceKey: String? = nil) {
        self.notifier = notifier
        self.persistenceKey = persistenceKey
        restoreIfPossible()
    }

    func start(seconds: Int, nextLabel: String, now: Date = Date()) {
        if isActive { notifier.cancelPending() }
        self.nextLabel = nextLabel
        let duration = max(1, seconds)
        endsAt = now.addingTimeInterval(TimeInterval(duration))
        remaining = duration
        isVisible = true
        isActive = true
        scheduleNotification()
        persist()
    }

    func tick(now: Date = Date()) {
        guard isActive else { return }
        updateRemaining(now: now)
        if remaining <= 0 { fire() }
    }

    func addThirty(now: Date = Date()) {
        guard isActive else { return }
        updateRemaining(now: now)
        guard isActive, remaining > 0 else { return }
        let base = max(endsAt ?? now, now)
        endsAt = base.addingTimeInterval(30)
        updateRemaining(now: now)
        scheduleNotification()
        persist()
    }

    func dismiss() {
        isVisible = false
        persist()
    }

    func stop() {
        isActive = false
        isVisible = false
        remaining = 0
        endsAt = nil
        notifier.cancelPending()
        clearPersisted()
    }

    private func fire() {
        isActive = false
        isVisible = false
        remaining = 0
        endsAt = nil
        notifier.cancelPending()
        clearPersisted()
        onElapsed?()
    }

    private func updateRemaining(now: Date) {
        guard let endsAt else {
            remaining = 0
            isActive = false
            return
        }
        remaining = max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    private func scheduleNotification() {
        guard isActive, remaining > 0 else { return }
        notifier.schedule(
            after: TimeInterval(remaining),
            title: "[ SYSTEM ] RECOVERY COMPLETE",
            body: nextLabel.isEmpty ? "Your next set is ready." : "Next set: \(nextLabel)."
        )
    }

    private func persist() {
        guard let persistenceKey, let endsAt else { return }
        let snapshot = Snapshot(
            endsAt: endsAt,
            nextLabel: nextLabel,
            isVisible: isVisible
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func restoreIfPossible(now: Date = Date()) {
        guard let persistenceKey,
              let data = UserDefaults.standard.data(forKey: persistenceKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        endsAt = snapshot.endsAt
        nextLabel = snapshot.nextLabel
        isVisible = snapshot.isVisible
        isActive = true
        updateRemaining(now: now)
        if remaining <= 0 {
            stop()
        } else {
            scheduleNotification()
        }
    }

    private func clearPersisted() {
        guard let persistenceKey else { return }
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }

    private struct Snapshot: Codable {
        let endsAt: Date
        let nextLabel: String
        let isVisible: Bool
    }
}
