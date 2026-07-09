// UNBOUND/Services/Attributes/BuildClassStore.swift
import Foundation

/// Hold-window hysteresis so the displayed class doesn't flicker with the
/// live hex. The held identity is sticky: it only changes after a DIFFERENT
/// live reading has held continuously for `holdWindow`. A dip back to the
/// held identity (or a flip to a third shape) resets the candidate clock.
///
/// The hex only moves at attribute ingest, so `observe` is called from
/// `AttributeService`'s persist choke point; display surfaces use the pure
/// `heldIdentity` read. UserDefaults-backed, one entry per userId
/// (UserSkillTierStore pattern).
final class BuildClassStore {

    static let shared = BuildClassStore()

    /// How long a different live reading must hold before it becomes the
    /// held identity (and therefore the displayed class).
    static let holdWindow: TimeInterval = 21 * 24 * 60 * 60

    struct HoldState: Codable, Equatable, Sendable {
        var held: BuildIdentity?
        var candidate: BuildIdentity?
        var candidateSince: Date?

        static let empty = HoldState(held: nil, candidate: nil, candidateSince: nil)
    }

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.buildClassHold."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The identity the class reads from. Pure — falls back to `live`
    /// before the first observation, which is safe because the hex only
    /// changes at ingest (where `observe` bootstraps the hold).
    func heldIdentity(userId: String, live: BuildIdentity) -> BuildIdentity {
        load(userId: userId).held ?? live
    }

    /// Advance the hysteresis against the latest live reading. Called
    /// whenever the attribute profile is persisted.
    func observe(_ live: BuildIdentity, userId: String, at now: Date) {
        var state = load(userId: userId)

        guard let held = state.held else {
            state.held = live
            save(HoldState(held: live, candidate: nil, candidateSince: nil), userId: userId)
            return
        }

        if live == held {
            guard state.candidate != nil else { return }
            state.candidate = nil
            state.candidateSince = nil
            save(state, userId: userId)
            return
        }

        if live == state.candidate, let since = state.candidateSince {
            guard now.timeIntervalSince(since) >= Self.holdWindow else { return }
            save(HoldState(held: live, candidate: nil, candidateSince: nil), userId: userId)
            return
        }

        state.candidate = live
        state.candidateSince = now
        save(state, userId: userId)
    }

    func load(userId: String) -> HoldState {
        guard let data = defaults.data(forKey: keyPrefix + userId),
              let state = try? JSONDecoder().decode(HoldState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    private func save(_ state: HoldState, userId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
    }
}
