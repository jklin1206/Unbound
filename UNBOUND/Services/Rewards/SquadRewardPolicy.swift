import Foundation

// MARK: - SquadRewardPolicy
//
// Balance constants and dedup-safe sourceId builders for squad rewards.
// Arc amounts approved by jlin 2026-06-11 (plan balance checkpoint).
//
// Consumers:
//   • SquadMissionCelebrationView — CLAIM button uses missionArcs + missionSourceId
//   • FriendChallengeService — settle path pays the 1v1 winner duelWinArcs + duelSourceId
//
// CurrencyWalletStore.grant(_:sourceId:) deduplicates by sourceId, so a member
// is paid exactly once per mission/duel regardless of how many times the
// celebration is claimed or the settle pass re-runs on foreground.

enum SquadRewardPolicy {
    /// Arcs awarded to every squad member when a co-op mission completes.
    static let missionArcs = 300

    /// Arcs awarded to the winner of a 1v1 friend challenge (duel).
    static let duelWinArcs = 120

    /// Stable, ledger-dedup key for a completed squad mission.
    static func missionSourceId(_ missionId: UUID) -> String {
        "squad_mission:\(missionId.uuidString.lowercased())"
    }

    /// Stable, ledger-dedup key for a resolved friend challenge.
    static func duelSourceId(_ challengeId: UUID) -> String {
        "friend_challenge:\(challengeId.uuidString.lowercased())"
    }
}
