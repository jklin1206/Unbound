// UNBOUND/Services/Trials/TrialsStore.swift
import Foundation

/// UserDefaults-backed persistence for WeeklyVowsState. One entry per userId.
final class WeeklyVowsStore {

    static let shared = WeeklyVowsStore()

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.weeklyVowsState."
    private let legacyKeyPrefix = "unbound.trialsState."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
    }
}

typealias TrialsStore = WeeklyVowsStore
