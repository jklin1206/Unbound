// UNBOUND/Services/Trials/TrialsStore.swift
import Foundation

/// UserDefaults-backed persistence for TrialsState. One entry per userId.
/// Mirrors the existing UserSkillTierStore pattern from sub-project #4.
final class TrialsStore {

    static let shared = TrialsStore()

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.trialsState."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userId: String) -> TrialsState {
        guard let data = defaults.data(forKey: keyPrefix + userId),
              let state = try? JSONDecoder().decode(TrialsState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    func save(_ state: TrialsState, userId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
    }
}
