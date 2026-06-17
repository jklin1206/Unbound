import Foundation

enum WeeklyVowPenaltyCatalog {
    private static let maxLedgerEntries = 100

    static func applyMissedPenaltyIfNeeded(
        for vow: WeeklyVow,
        missedAt: Date,
        state: inout WeeklyVowsState
    ) {
        guard vow.capstoneState != .completed, vow.capstoneState != .missed else { return }
        guard !state.weeklyVowPenaltyLedger.contains(where: { $0.vowId == vow.id && $0.weekStart == vow.weekStart }) else { return }

        let owedXP = vow.chosenCard.bet.oweXP
        guard owedXP > 0 else { return }

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
        // Spec §5: a broken vow becomes collectible debt, withheld from future
        // earned training XP — not a deduction from the next vow win.
        state.pendingVowDebtXP = max(0, state.pendingVowDebtXP + owedXP)

        // A Fuel vow's self-report anchors are keyed by the (stable) weekly card
        // id. Now that the vow is charged as missed, clear its tally so re-picking
        // the same card id can't resume the old count and re-seal an already-
        // broken, already-charged vow — which would pay its win token a second
        // time. No-op for non-Fuel lanes.
        state.fuelAnchorsByVowId[vow.id] = nil
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
