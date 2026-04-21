import Foundation
import Combine

// Dev-only feature flags persisted to UserDefaults. The UI that flips these
// is compiled out of Release builds — the flags themselves stay readable in
// Release (in case we want to ship a hidden-gesture developer menu later),
// but by default they default to false and there's no way to turn them on.

final class DevFlags: @unchecked Sendable {
    static let shared = DevFlags()

    private enum Keys {
        static let unlockAllFeatures = "dev.unlockAllFeatures"
    }

    private let defaults = UserDefaults.standard
    private let subject = CurrentValueSubject<Void, Never>(())

    var unlockAllFeaturesPublisher: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    var unlockAllFeatures: Bool {
        get { defaults.bool(forKey: Keys.unlockAllFeatures) }
        set {
            defaults.set(newValue, forKey: Keys.unlockAllFeatures)
            subject.send(())
        }
    }

    private init() {}
}
