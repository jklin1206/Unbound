import Foundation
import SwiftUI

extension WorkoutRewardSequenceSummary {
    static var previewSample: WorkoutRewardSequenceSummary {
        WorkoutRewardSequenceSummary(
            workoutName: "Push · Strength",
            durationMinutes: 54,
            workSets: 18,
            volumeKg: 7820,
            rpe: 8,
            xp: XPReward(
                total: 340,
                previousLevel: 12,
                newLevel: 13,
                previousProgress: 0.72,
                newProgress: 0.18,
                breakdown: [
                    XPBreakdownLine(label: "Session logged", amount: 120),
                    XPBreakdownLine(label: "Targets hit", amount: 80),
                    XPBreakdownLine(label: "Volume bonus", amount: 50),
                    XPBreakdownLine(label: "PR bonus", amount: 90)
                ]
            ),
            liftProgress: [
                LiftProgressReward(liftName: "Bench Press", family: .press, fromTier: .forged, toTier: .veteran, fromProgress: 0.82, toProgress: 0.14, xpGained: 108),
                LiftProgressReward(liftName: "Overhead Press", family: .press, fromTier: .apprentice, toTier: .apprentice, fromProgress: 0.42, toProgress: 0.61, xpGained: 72),
                LiftProgressReward(liftName: "Dip", family: .core, fromTier: .novice, toTier: .novice, fromProgress: 0.36, toProgress: 0.54, xpGained: 58)
            ],
            attributeDeltas: [
                AttributeDeltaReward(key: .power, previousTier: .forged, currentTier: .forged),
                AttributeDeltaReward(key: .control, previousTier: .apprentice, currentTier: .apprentice),
                AttributeDeltaReward(key: .endurance, previousTier: .apprentice, currentTier: .apprentice),
                AttributeDeltaReward(key: .explosiveness, previousTier: .novice, currentTier: .novice)
            ],
            personalRecords: [
                PersonalRecordReward(liftName: "Bench Press", valueText: "82.5 kg", deltaText: "+5 kg over best", family: .press)
            ],
            badges: [
                BadgeUnlock(id: "pr.session", title: "PR Feat", subtitle: "Set a new best lift.", assetName: "badge_art_pr_session")
            ],
            arcProgress: ArcProgressReward(arcName: "Arc 1 · Foundation", week: 2, totalWeeks: 4, completedSessions: 3, totalSessions: 4, didCompleteWeek: false, didCompleteArc: false, bonusXP: 500),
            arcsEarned: 240,
            cosmeticUnlock: CosmeticUnlockReward(title: "PR Frame · Ember", subtitle: "Available for major lift share cards.", tint: Color.unbound.emberGlow)
        )
    }
}
