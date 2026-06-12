import Foundation
import SwiftUI

// MARK: - WorkoutRewardSequenceSummary
//
// Rich workout-end reward payload. This is intentionally separate from
// RewardSummary: RewardSummary captures event diffs; this model powers the
// full post-workout beat sequence shared by program, skill, routine, cardio,
// quick-log, and custom completion routes.

struct WorkoutRewardSequenceSummary: Identifiable {
    let id = UUID()
    var workoutName: String
    var durationMinutes: Int
    var workSets: Int
    var volumeKg: Double
    var rpe: Int?

    var xp: XPReward
    var liftProgress: [LiftProgressReward]
    var attributeDeltas: [AttributeDeltaReward]
    var attributePreviousHexValues: [AttributeKey: Double] = [:]
    var attributeCurrentHexValues: [AttributeKey: Double] = [:]
    var attributePreviousLevels: [AttributeKey: Int] = [:]
    var attributeLevels: [AttributeKey: Int] = [:]
    var attributePreviousTiers: [AttributeKey: RankTitle] = [:]
    var attributeTiers: [AttributeKey: RankTitle] = [:]
    var personalRecords: [PersonalRecordReward]
    var badges: [BadgeUnlock]
    var arcProgress: ArcProgressReward
    /// Shop currency paid out for this completed session.
    var arcsEarned: Int = 0
    var cosmeticUnlock: CosmeticUnlockReward?
    var progression: ProgressionReceipt? = nil
    var weeklyVowCallout: WeeklyVowRewardCallout? = nil
    var rankTrialCallout: RankTrialRewardCallout? = nil
    var beats: [RewardBeat] = []
    var tally: RewardTally = .empty
    var emblemIgnition: Bool = false
    var showsSessionSummary: Bool = true
    var showsFinalSummary: Bool = true

    /// Unified per-exercise rank cards (skills AND lifts) for the RANKS beat:
    /// one card per movement showing the rank badge earned, progress toward the
    /// next rank, and any PR. Replaces the old per-(skill,tier) "proof" rows and
    /// the separate lift-rank page.
    var exerciseRanks: [ExerciseRankReward] = []

    /// Day-streak reward, when this session counted toward a streak.
    var streak: StreakReward? = nil

    /// Cosmetics unlocked this session (skill-tree skins, profile frames…) so the
    /// reward flow surfaces them instead of a silent toast later.
    var cosmeticUnlocks: [CosmeticUnlockReward] = []

    var hasShareableMoment: Bool {
        weeklyVowCallout?.completionBonus?.shareCard != nil
            || !personalRecords.isEmpty
            || !badges.isEmpty
            || liftProgress.contains(where: \.didAdvanceTier)
            || arcProgress.didCompleteArc
            || emblemIgnition
    }
}

extension WorkoutRewardSequenceSummary {
    static func trainingReceipt(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult? = nil,
        rewardSummary: RewardSummary? = nil,
        fallbackXP: Int = 0,
        sourceName: String? = nil,
        weeklyVowCallout: WeeklyVowRewardCallout? = nil
    ) -> WorkoutRewardSequenceSummary {
        let allSets = performanceLog.blocks.flatMap(\.exercises).flatMap(\.sets)
        let metricOnlyBlocks = performanceLog.blocks.filter { block in
            block.exercises.isEmpty
                && ((block.durationSeconds ?? 0) > 0
                    || (block.distanceMeters ?? 0) > 0
                    || (block.calories ?? 0) > 0)
        }.count
        let workSets = allSets.filter { !$0.isWarmup && setHasWork($0) }.count + metricOnlyBlocks
        let volumeKg = allSets.reduce(0.0) { total, set in
            total + ((set.weightKg ?? 0) * Double(set.reps ?? 0))
        }
        let rpeValues = allSets.compactMap(\.rpe)
        let averageRPE = rpeValues.isEmpty
            ? performanceLog.overallRPE
            : Int((Double(rpeValues.reduce(0, +)) / Double(rpeValues.count)).rounded())
        let durationMinutes = max(1, Int(performanceLog.completedAt.timeIntervalSince(performanceLog.startedAt) / 60))
        let progression = rewardSummary?.progression ?? completionResult?.progressionReceipt
        let sequenceXP = xpReward(
            progression: progression,
            completionResult: completionResult,
            rewardSummary: rewardSummary,
            fallbackXP: fallbackXP,
            sourceName: sourceName ?? performanceLog.source.rawValue.capitalized
        )

        let attributeDeltas = attributeDeltas(from: completionResult, progression: progression)
        let attributePreviousLevels = attributePreviousLevels(from: completionResult, progression: progression)
        let attributeLevels = attributeLevels(from: completionResult, progression: progression)
        let previousAttributeTiers = attributePreviousTiers(from: completionResult, deltas: attributeDeltas)
        let currentAttributeTiers = attributeTiers(from: completionResult, deltas: attributeDeltas)

        var summary = WorkoutRewardSequenceSummary(
            workoutName: performanceLog.title,
            durationMinutes: durationMinutes,
            workSets: workSets,
            volumeKg: volumeKg,
            rpe: averageRPE,
            xp: sequenceXP,
            liftProgress: liftProgress(from: rewardSummary, progression: progression, fallbackXP: sequenceXP.total),
            attributeDeltas: attributeDeltas,
            attributePreviousHexValues: attributeHexValues(
                profile: completionResult?.attributeProfileBefore,
                fallbackDeltas: attributeDeltas,
                useCurrent: false
            ),
            attributeCurrentHexValues: attributeHexValues(
                profile: completionResult?.attributeProfileAfter,
                fallbackDeltas: attributeDeltas,
                useCurrent: true
            ),
            attributePreviousLevels: attributePreviousLevels,
            attributeLevels: attributeLevels,
            attributePreviousTiers: previousAttributeTiers,
            attributeTiers: currentAttributeTiers,
            personalRecords: personalRecords(from: rewardSummary),
            badges: badges(from: rewardSummary),
            arcProgress: ArcProgressReward(
                arcName: sourceName ?? performanceLog.source.rawValue.capitalized,
                week: max(1, (performanceLog.dayNumber ?? 1) / 7 + 1),
                totalWeeks: 1,
                completedSessions: workSets > 0 || sequenceXP.total > 0 ? 1 : 0,
                totalSessions: 1,
                didCompleteWeek: false,
                didCompleteArc: false,
                bonusXP: 0
            ),
            cosmeticUnlock: nil,
            progression: progression,
            weeklyVowCallout: weeklyVowCallout
        )
        summary.arcsEarned = max(0, completionResult?.arcsEarned ?? 0)
        if let proofResult = completionResult?.proofEngineResult {
            summary = RewardPayloadBuilder.attachProofRewards(proofResult, to: summary)
        }
        if let cr = completionResult, cr.streakCount > 0 {
            summary.streak = StreakReward(dayCount: cr.streakCount, didExtend: cr.streakExtended)
        }
        if let cr = completionResult, !cr.unlockedSkins.isEmpty {
            summary.cosmeticUnlocks = cr.unlockedSkins.map { skin in
                CosmeticUnlockReward(
                    title: "\(skin.displayName) Skin",
                    subtitle: "Skill-tree cosmetic — equip in Appearance.",
                    tint: Color.unbound.rankGold
                )
            }
        }
        return summary
    }

    static func simpleReceipt(
        workoutName: String,
        durationMinutes: Int,
        workSets: Int,
        volumeKg: Double = 0,
        rpe: Int? = nil,
        xpTotal: Int,
        xpLabel: String,
        sourceName: String,
        badges: [BadgeUnlock] = [],
        arcsEarned: Int = 0
    ) -> WorkoutRewardSequenceSummary {
        let progress = min(1.0, max(0.0, Double(xpTotal) / 100.0))
        return WorkoutRewardSequenceSummary(
            workoutName: workoutName,
            durationMinutes: max(1, durationMinutes),
            workSets: max(0, workSets),
            volumeKg: volumeKg,
            rpe: rpe,
            xp: XPReward(
                total: max(0, xpTotal),
                previousLevel: 1,
                newLevel: xpTotal >= 100 ? 2 : 1,
                previousProgress: 0,
                newProgress: progress,
                previousXP: 0,
                currentXP: Double(max(0, xpTotal)),
                levelFloorXP: 0,
                nextLevelXP: 100,
                breakdown: xpTotal > 0 ? [XPBreakdownLine(label: xpLabel, amount: xpTotal)] : []
            ),
            liftProgress: [],
            attributeDeltas: [],
            personalRecords: [],
            badges: badges,
            arcProgress: ArcProgressReward(
                arcName: sourceName,
                week: 1,
                totalWeeks: 1,
                completedSessions: xpTotal > 0 || workSets > 0 ? 1 : 0,
                totalSessions: 1,
                didCompleteWeek: false,
                didCompleteArc: false,
                bonusXP: 0
            ),
            arcsEarned: max(0, arcsEarned),
            cosmeticUnlock: nil
        )
    }

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
