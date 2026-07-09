// UNBOUND/Services/Trials/TrialsStore.swift
import Foundation

/// UserDefaults-backed persistence for WeeklyVowsState. One entry per userId.
final class WeeklyVowsStore {

    static let shared = WeeklyVowsStore(backup: AchievementsCloudBackup.shared)

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.weeklyVowsState."
    private let legacyKeyPrefix = "unbound.trialsState."
    /// Optional cloud mirror fired after every persist — `save` is the single
    /// choke point every vow/title write funnels through (seals, title
    /// unlocks/equips, penalty records, shop cross-grants). The mirror dedupes
    /// on the durable subset, so ephemeral-only saves skip the patch. The
    /// production `.shared` store wires the real backup; test-constructed
    /// stores get nil so unit tests never touch the outbox / SyncedDatabase.
    private let backup: (any AchievementsBackuping)?

    init(defaults: UserDefaults = .standard, backup: (any AchievementsBackuping)? = nil) {
        self.defaults = defaults
        self.backup = backup
    }

    func load(userId: String) -> WeeklyVowsState {
        if let data = defaults.data(forKey: keyPrefix + userId),
           let state = try? JSONDecoder().decode(WeeklyVowsState.self, from: data) {
            return state
        }

        if let legacyData = defaults.data(forKey: legacyKeyPrefix + userId),
           let legacyState = try? JSONDecoder().decode(WeeklyVowsState.self, from: legacyData) {
            save(legacyState, userId: userId)
            return legacyState
        }

        return .empty
    }

    func save(_ state: WeeklyVowsState, userId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
        // Mirror the durable fields onto the synced `users` doc so a reinstall
        // restores titles/kept-vows. Fire-and-forget through the outbox;
        // failures are logged, never silenced. Local remains authoritative.
        backup?.backup(userId: userId)
    }
}

typealias TrialsStore = WeeklyVowsStore
