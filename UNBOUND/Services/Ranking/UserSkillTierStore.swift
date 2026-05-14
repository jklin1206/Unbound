// UNBOUND/Services/Ranking/UserSkillTierStore.swift
import Foundation

/// UserDefaults-backed persistence for UserSkillTierState. One entry per
/// userId. Mirrors the existing AttributeProfileStore pattern.
final class UserSkillTierStore {

    static let shared = UserSkillTierStore()

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.skillTierState."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userId: String) -> UserSkillTierState {
        guard let data = defaults.data(forKey: keyPrefix + userId),
              let state = try? JSONDecoder().decode(UserSkillTierState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    func save(_ state: UserSkillTierState, userId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
    }
}
