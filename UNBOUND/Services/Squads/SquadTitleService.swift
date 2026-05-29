// UNBOUND/Services/Squads/SquadTitleService.swift
import Foundation

// MARK: - SquadTitleService
//
// Wires the pure `SquadTitleThresholdEvaluator` into persisted squad state.
// When squad counters update (linked sessions, streak weeks, collective axis
// rank-ups, affinity tenure), this computes any newly-crossed thresholds,
// appends them to `SquadState.unlockedSquadTitles`, and posts
// `.squadTitleUnlocked` per new title so the squad badge UI can render.
//
// Squad titles use `SquadTitleID` + `.squadTitleUnlocked` — distinct from the
// individual rank `TitleID` + `.titleUnlocked` (the latter is observed by
// SquadActivityService expecting a TitleID, so squad titles MUST NOT reuse it).

@MainActor
final class SquadTitleService {
    static let shared = SquadTitleService()

    private let store: SquadStore

    init(store: SquadStore = .shared) {
        self.store = store
    }

    /// Compute threshold crossings between two counter snapshots, persist any
    /// newly-unlocked SquadTitleIDs into the user's SquadState, and post
    /// `.squadTitleUnlocked` (object: SquadTitleID) for each new one.
    func applyCounterUpdate(
        prior: SquadTitleThresholdEvaluator.Counters,
        current: SquadTitleThresholdEvaluator.Counters,
        userId: String
    ) async {
        let crossed = SquadTitleThresholdEvaluator.crossings(prior: prior, current: current)
        guard !crossed.isEmpty else { return }

        var state = store.load(userId: userId)
        var alreadyUnlocked = Set(state.unlockedSquadTitles)
        var newlyUnlocked: [SquadTitleID] = []
        for id in crossed where !alreadyUnlocked.contains(id) {
            alreadyUnlocked.insert(id)
            newlyUnlocked.append(id)
        }
        guard !newlyUnlocked.isEmpty else { return }

        state.unlockedSquadTitles.append(contentsOf: newlyUnlocked)
        store.save(state, userId: userId)

        for id in newlyUnlocked {
            NotificationCenter.default.post(name: .squadTitleUnlocked, object: id)
        }
    }
}
