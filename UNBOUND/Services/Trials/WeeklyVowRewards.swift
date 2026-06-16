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

        let owedXP = vow.chosenCard.kind.missedPenaltyOverallLevelXP
        guard owedXP > 0 else { return }

        state.weeklyVowPenaltyLedger.append(
            WeeklyVowPenaltyLedgerEntry(
                vowId: vow.id,
                cardKind: vow.chosenCard.kind,
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
    }
}

enum WeeklyVowCompletionBonusCatalog {
    static func bonus(
        for vow: WeeklyVow,
        performanceLog: PerformanceLog,
        completionCountAfter: Int
    ) -> WeeklyVowCompletionBonus {
        let kind = vow.chosenCard.kind
        let awardedOverallLevelXP = kind.completionBonusOverallLevelXP
        let badgeTarget = 3
        let cosmeticTarget = 5
        let badgeProgress = min(badgeTarget, ((completionCountAfter - 1) % badgeTarget) + 1)
        let cosmeticProgress = min(cosmeticTarget, ((completionCountAfter - 1) % cosmeticTarget) + 1)
        let shareCard: WeeklyVowShareCardDescriptor?

        if kind == .apex {
            shareCard = WeeklyVowShareCardDescriptor(
                id: "apex-vow-share-\(vow.id)-\(performanceLog.id)",
                title: "\(vow.chosenCard.displayName) Cleared",
                subtitle: "Binding Vow - \(vow.chosenCard.capstone.displayName)",
                metadata: [
                    "vowId": vow.id,
                    "performanceLogId": performanceLog.id,
                    "cardKind": kind.vowIdComponent,
                    "completedAt": ISO8601DateFormatter().string(from: performanceLog.completedAt)
                ]
            )
        } else {
            shareCard = nil
        }

        return WeeklyVowCompletionBonus(
            overallLevelXP: awardedOverallLevelXP,
            badgeProgress: WeeklyVowProgressDescriptor(
                title: "\(kind.displayName) I",
                current: badgeProgress,
                target: badgeTarget
            ),
            cosmeticProgress: WeeklyVowProgressDescriptor(
                title: "\(kind.displayName) Mark",
                current: cosmeticProgress,
                target: cosmeticTarget
            ),
            shareCard: shareCard,
            baseOverallLevelXP: nil,
            penaltyAppliedXP: nil
        )
    }
}
