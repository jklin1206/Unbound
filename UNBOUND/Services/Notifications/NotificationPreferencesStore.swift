import Foundation

final class NotificationPreferencesStore {
    static let shared = NotificationPreferencesStore()

    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        key: String = "unbound.notificationPreferences"
    ) {
        self.defaults = defaults
        self.key = key

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> NotificationPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? decoder.decode(NotificationPreferences.self, from: data)
        else {
            return NotificationPreferences()
        }
        return preferences
    }

    func save(_ preferences: NotificationPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }

    @discardableResult
    func update(_ mutate: (inout NotificationPreferences) -> Void) -> NotificationPreferences {
        var preferences = load()
        mutate(&preferences)
        preferences.updatedAt = Date()
        save(preferences)
        return preferences
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
