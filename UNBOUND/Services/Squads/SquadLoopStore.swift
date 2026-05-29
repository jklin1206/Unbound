// UNBOUND/Services/Squads/SquadLoopStore.swift
import Foundation

/// UserDefaults-backed persistence for the squad-loop reconciler's dedup +
/// counter state. One entry-group per userId. Mirrors the SquadStore pattern.
///
/// Persists across relaunches so a linked session is bonused exactly once and
/// the squad-title counters keep advancing.
final class SquadLoopStore {

    static let shared = SquadLoopStore()

    private let defaults: UserDefaults
    private let processedPrefix = "unbound.squadLoop.processedLinked."   // + userId → [uuidString]
    private let countPrefix = "unbound.squadLoop.linkedCount."           // + userId → Int
    private let streakPrefix = "unbound.squadLoop.lastStreakWeeks."      // + userId → Int

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Processed linked-session ids

    func isLinkedSessionProcessed(_ id: UUID, userId: String) -> Bool {
        processedIds(userId: userId).contains(id.uuidString)
    }

    func markLinkedSessionProcessed(_ id: UUID, userId: String) {
        var ids = processedIds(userId: userId)
        guard !ids.contains(id.uuidString) else { return }
        ids.append(id.uuidString)
        // Cap to avoid unbounded growth; oldest dropped first.
        if ids.count > 500 { ids = Array(ids.suffix(500)) }
        defaults.set(ids, forKey: processedPrefix + userId)
    }

    private func processedIds(userId: String) -> [String] {
        defaults.stringArray(forKey: processedPrefix + userId) ?? []
    }

    // MARK: Linked-session running count

    func linkedSessionsCount(userId: String) -> Int {
        defaults.integer(forKey: countPrefix + userId)
    }

    func addLinkedSessions(_ delta: Int, userId: String) {
        guard delta > 0 else { return }
        defaults.set(linkedSessionsCount(userId: userId) + delta, forKey: countPrefix + userId)
    }

    // MARK: Last-known squad streak (for crossing detection)

    func lastKnownStreakWeeks(userId: String) -> Int {
        defaults.integer(forKey: streakPrefix + userId)
    }

    func setLastKnownStreakWeeks(_ weeks: Int, userId: String) {
        defaults.set(max(0, weeks), forKey: streakPrefix + userId)
    }
}
