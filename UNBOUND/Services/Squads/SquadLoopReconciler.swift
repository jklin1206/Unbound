// UNBOUND/Services/Squads/SquadLoopReconciler.swift
import Foundation

// MARK: - SquadLoopReconciler
//
// Closes two squad loops that had no production trigger (council BLOCKER 3 + 4):
//
//   • Linked-session +20% LV bonus (BLOCKER 3): the `detect_linked_sessions`
//     Edge Function inserts a `linked_sessions` row when squadmates' workouts
//     overlap, but nothing in the app consumed it. On squad load/refresh we
//     fetch the squad's recent `linked_sessions`, take the rows the user
//     participates in that we have NOT processed yet, and drive
//     `handleLinkedSessionDetected` once per row. A persisted processed-id set
//     keyed on the linked_sessions row id prevents a double bonus on
//     re-fetch / relaunch.
//
//   • squadStreak + linkedSessions squad titles (BLOCKER 4 a/b): each processed
//     linked session bumps a persisted `linkedSessionsCount`; the squad streak
//     comes from the freshly-loaded `Squad.squadStreakWeeks`
//     (extended server-side by the evaluate_squad_streak cron). We snapshot the
//     counters before/after and feed `SquadTitleService.applyCounterUpdate`, so
//     crossing a threshold awards a SquadTitle and posts `.squadTitleUnlocked`.
//
// RESIDUAL GAP (documented, not faked): `linked_sessions` carries only
// id / squad_id / user_ids / started_at / ended_at — NO workout-log id and NO
// base-XP column. The true per-session base XP therefore cannot be recovered
// from the row, and SessionXPRecord stores only cumulative counters (not
// per-session XP). We use the SAME fixed base-XP proxy the affinity bonus path
// already uses (`SquadXPBonusBaseline.baseSessionXP`, see
// SessionXPService.recordSessionWithAffinity). This keeps the linked (+20%) and
// affinity (+10%) bonuses consistent and non-stacking; it does not fabricate a
// per-session value. A fully exact bonus requires the Edge Function to persist
// the originating log id (or its session XP) on the linked_sessions row.

enum SquadXPBonusBaseline {
    /// Base session XP used for out-of-band squad XP bonuses (affinity +10%,
    /// linked +20%). Matches the constant in SessionXPService /
    /// MockSessionXPService so the two bonuses stay consistent + non-stacking.
    static let baseSessionXP = 10
}

@MainActor
final class SquadLoopReconciler {
    static let shared = SquadLoopReconciler()

    private let backend: SquadBackendProtocol
    private let activityService: SquadActivityServiceProtocol
    private let titleService: SquadTitleService
    private let store: SquadLoopStore
    private let logger = LoggingService.shared

    init(
        backend: SquadBackendProtocol = SquadBackend.shared,
        activityService: SquadActivityServiceProtocol = SquadActivityService.shared,
        titleService: SquadTitleService = .shared,
        store: SquadLoopStore = .shared
    ) {
        self.backend = backend
        self.activityService = activityService
        self.titleService = titleService
        self.store = store
    }

    /// Reconcile linked-session bonuses + squad titles for `userId` against the
    /// freshly-loaded `squad`. Safe to call on every squad load — processed
    /// linked sessions are deduped by id, and title crossings dedupe in
    /// SquadTitleService.
    func reconcile(userId: String, userUUID: UUID, squad: Squad) async {
        let prior = SquadTitleThresholdEvaluator.Counters(
            linkedSessionsCount: store.linkedSessionsCount(userId: userId),
            squadStreakWeeks: store.lastKnownStreakWeeks(userId: userId)
        )

        var newlyProcessed = 0
        do {
            let sessions = try await backend.fetchRecentLinkedSessions(squadId: squad.id, limit: 50)
            // Oldest first so the persisted count advances in chronological order.
            let unprocessed = sessions
                .filter { $0.userIds.contains(userUUID) && !store.isLinkedSessionProcessed($0.id, userId: userId) }
                .sorted { $0.startedAt < $1.startedAt }

            for session in unprocessed {
                store.markLinkedSessionProcessed(session.id, userId: userId)
                let names = session.userIds.filter { $0 != userUUID }.map { $0.uuidString }
                await activityService.handleLinkedSessionDetected(
                    userId: userId,
                    participantDisplayNames: names,
                    baseSessionXP: SquadXPBonusBaseline.baseSessionXP
                )
                newlyProcessed += 1
            }
        } catch {
            logger.log("SquadLoopReconciler linked-session fetch failed: \(error)", level: .warning)
        }

        if newlyProcessed > 0 {
            store.addLinkedSessions(newlyProcessed, userId: userId)
        }
        // Persist the streak we just observed so the next reconcile can detect a
        // crossing relative to it.
        store.setLastKnownStreakWeeks(squad.squadStreakWeeks, userId: userId)

        let current = SquadTitleThresholdEvaluator.Counters(
            linkedSessionsCount: store.linkedSessionsCount(userId: userId),
            squadStreakWeeks: squad.squadStreakWeeks
        )

        // BLOCKER 4(d) DEFERRED: collectiveAxisRankUps + affinityTenureMonths
        // have no aggregation source in the app, so their counters stay 0 here.
        // Do NOT fabricate them — see SquadTitleThresholdEvaluator.

        guard current != prior else { return }
        await titleService.applyCounterUpdate(prior: prior, current: current, userId: userId)
    }
}
