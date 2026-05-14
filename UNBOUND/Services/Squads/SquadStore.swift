// UNBOUND/Services/Squads/SquadStore.swift
import Foundation

/// UserDefaults-backed persistence for SquadState. One entry per userId.
/// Mirrors the TrialsStore pattern from the Trials service.
final class SquadStore {

    static let shared = SquadStore()

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.squadState."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userId: String) -> SquadState {
        guard let data = defaults.data(forKey: keyPrefix + userId),
              let state = try? JSONDecoder().decode(SquadState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    func save(_ state: SquadState, userId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
    }
}
