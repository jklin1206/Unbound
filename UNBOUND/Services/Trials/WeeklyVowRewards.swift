import Foundation

enum WeeklyVowPenaltyCatalog {
    private static let maxLedgerEntries = 100

    /// Record a broken vow in the penalty ledger (idempotent per vow + week) and
    /// return the stake owed, so the caller can dock it straight off the user's
    /// XP. Returns 0 when the break was already recorded or the vow can't owe.
    @discardableResult
    static func recordBreakIfNeeded(
        for vow: WeeklyVow,
        missedAt: Date,
        state: inout WeeklyVowsState
    ) -> Int {
        guard vow.capstoneState != .completed, vow.capstoneState != .missed else { return 0 }
        guard !state.weeklyVowPenaltyLedger.contains(where: { $0.vowId == vow.id && $0.weekStart == vow.weekStart }) else { return 0 }

        let owedXP = vow.chosenCard.bet.oweXP
        guard owedXP > 0 else { return 0 }

        state.weeklyVowPenaltyLedger.append(
            WeeklyVowPenaltyLedgerEntry(
                vowId: vow.id,
                lane: vow.chosenCard.lane,
                weekStart: vow.weekStart,
                missedAt: missedAt,
                penaltyXP: owedXP
            )
        )
        if state.weeklyVowPenaltyLedger.count > maxLedgerEntries {
            state.weeklyVowPenaltyLedger.removeFirst(state.weeklyVowPenaltyLedger.count - maxLedgerEntries)
        }

        // A vow's self-report tally is keyed by the (stable) weekly card id. Now
        // that the vow is broken, clear its tally and once-a-day log clock so
        // re-picking the same card id starts fresh and can't resume the old count
        // to re-seal an already-charged vow (paying its win token a second time).
        state.fuelAnchorsByVowId[vow.id] = nil
        state.lastVowLogByVowId[vow.id] = nil

        return owedXP
    }
}

enum WeeklyVowCompletionBonusCatalog {
    static func bonus(
        for vow: WeeklyVow,
        performanceLog: PerformanceLog,
        completionCountAfter: Int
    ) -> WeeklyVowCompletionBonus {
        let lane = vow.chosenCard.lane
        let awardedOverallLevelXP = vow.chosenCard.bet.winXP
        // Badge milestones are driven by VowBadgeTrack thresholds. The progress
        // descriptor here is a rolling display counter (e.g., "Power I 3/5") until
        // Phase 5b wires the real milestone-based badge award.
        let badgeTarget = VowBadgeTrack.thresholds.first ?? 5
        let badgeProgress = min(badgeTarget, ((completionCountAfter - 1) % badgeTarget) + 1)
        let laneLabel = lane.displayLabel.capitalized

        return WeeklyVowCompletionBonus(
            overallLevelXP: awardedOverallLevelXP,
            badgeProgress: WeeklyVowProgressDescriptor(
                title: "\(laneLabel) I",
                current: badgeProgress,
                target: badgeTarget
            )
        )
    }
}
