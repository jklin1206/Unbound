import Foundation
import Combine

// Dev-only feature flags persisted to UserDefaults for DEBUG builds.
// Release builds never honor persisted debug flags.

final class DevFlags: @unchecked Sendable {
    static let shared = DevFlags()

    private enum Keys {
        static let unlockAllFeatures = "dev.unlockAllFeatures"
    }

    private let defaults = UserDefaults.standard
    private let subject = CurrentValueSubject<Void, Never>(())

    var unlockAllFeaturesPublisher: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    var unlockAllFeatures: Bool {
        get {
            #if DEBUG
            defaults.bool(forKey: Keys.unlockAllFeatures)
            #else
            false
            #endif
        }
        set {
            #if DEBUG
            defaults.set(newValue, forKey: Keys.unlockAllFeatures)
            #else
            if defaults.object(forKey: Keys.unlockAllFeatures) != nil {
                defaults.removeObject(forKey: Keys.unlockAllFeatures)
            }
            #endif
            subject.send(())
        }
    }

    private init() {}
}
