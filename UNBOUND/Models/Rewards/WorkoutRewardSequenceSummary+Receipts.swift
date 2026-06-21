import Foundation
import SwiftUI

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

    private static func setHasWork(_ set: PerformanceSet) -> Bool {
        if let reps = set.reps, reps > 0 { return true }
        if let holdSeconds = set.holdSeconds, holdSeconds > 0 { return true }
        if let durationSeconds = set.durationSeconds, durationSeconds > 0 { return true }
        if let distanceMeters = set.distanceMeters, distanceMeters > 0 { return true }
        if let calories = set.calories, calories > 0 { return true }
        return false
    }

    private static func xpReward(
        progression: ProgressionReceipt?,
        completionResult: TrainingCompletionResult?,
        rewardSummary: RewardSummary?,
        fallbackXP: Int,
        sourceName: String
    ) -> XPReward {
        var breakdown: [XPBreakdownLine] = []
        let hasCanonicalCompletion = completionResult != nil
        let overallXP = Int(((completionResult?.overallLevelXPGained ?? progression?.overallLevelXPGained) ?? 0).rounded())
        let skillXP = completionResult?.skillXPGained ?? rewardSummary?.xpGained ?? 0

        if skillXP > 0 {
            breakdown.append(XPBreakdownLine(label: "Skill XP", amount: skillXP))
        }
        if overallXP > 0 {
            breakdown.append(XPBreakdownLine(label: "Level XP", amount: overallXP))
        }
        if !hasCanonicalCompletion && fallbackXP > 0 && breakdown.isEmpty {
            breakdown.append(XPBreakdownLine(label: "\(sourceName) logged", amount: fallbackXP))
        }

        let totalXP = hasCanonicalCompletion
            ? breakdown.reduce(0) { $0 + $1.amount }
            : max(
                fallbackXP,
                overallXP,
                progression == nil ? (rewardSummary?.xpGained ?? 0) : 0,
                breakdown.reduce(0) { $0 + $1.amount }
            )
        if totalXP > 0 && breakdown.isEmpty {
            breakdown.append(XPBreakdownLine(label: "Session logged", amount: totalXP))
        }

        let previousLevel = max(1, progression?.overallLevelBefore ?? 1)
        let newLevel = max(previousLevel, progression?.overallLevelAfter ?? (totalXP >= 100 ? previousLevel + 1 : previousLevel))
        let previousProgress = progression?.overallLevelProgressBefore ?? 0
        let newProgress = progression?.overallLevelProgressAfter ?? min(1.0, max(0.0, Double(totalXP) / 100.0))
        let overallReward = completionResult?.overallLevelReward
        let previousXP = overallReward?.previousXP ?? 0
        let currentXP = overallReward?.currentXP ?? (previousXP + Double(totalXP))
        let rawCurrentLevel = overallReward?.currentLevel ?? progression?.overallLevelAfter ?? 0
        let levelFloorXP = rawCurrentLevel <= 0 ? 0 : OverallLevelCurve.xpRequired(forLevel: rawCurrentLevel)
        let nextLevelXP = OverallLevelCurve.xpRequired(forLevel: max(1, rawCurrentLevel + 1))

        return XPReward(
            total: totalXP,
            previousLevel: previousLevel,
            newLevel: newLevel,
            previousProgress: previousProgress,
            newProgress: newProgress,
            previousXP: previousXP,
            currentXP: currentXP,
            levelFloorXP: levelFloorXP,
            nextLevelXP: nextLevelXP,
            breakdown: breakdown
        )
    }

    private static func liftProgress(
        from rewardSummary: RewardSummary?,
        progression: ProgressionReceipt?,
        fallbackXP: Int
    ) -> [LiftProgressReward] {
        guard let rankUp = rewardSummary?.rankUp else { return [] }
        let fromTier = rankUp.fromTier ?? previousTier(before: rankUp.toTier)
        // Real progress into the new tier — derived from the movement's best
        // metric via StrengthStandards.progressToNextRank (carried on the
        // matching ProgressionMovementLine), never a hardcoded animation value.
        let line = progression?.movementLines.first {
            $0.id == rankUp.skillId ||
            MovementCatalog.normalized($0.name) == MovementCatalog.normalized(rankUp.skillTitle)
        }
        let fraction = line?.fractionToNextRank ?? (rankUp.toTier.next == nil ? 1.0 : 0)
        return [
            LiftProgressReward(
                liftName: rankUp.skillTitle,
                family: family(for: rankUp.skillTitle, skillId: rankUp.skillId),
                fromTier: fromTier,
                toTier: rankUp.toTier,
                fromProgress: fraction,
                toProgress: fraction,
                xpGained: max(0, rewardSummary?.xpGained ?? fallbackXP)
            )
        ]
    }

    private static func attributeDeltas(
        from completionResult: TrainingCompletionResult?,
        progression: ProgressionReceipt?
    ) -> [AttributeDeltaReward] {
        if let rewards = completionResult?.attributeRewards, !rewards.isEmpty {
            return rewards
                .sorted { lhs, rhs in
                    if lhs.xpGained == rhs.xpGained {
                        return lhs.key.shortCode < rhs.key.shortCode
                    }
                    return lhs.xpGained > rhs.xpGained
                }
                .prefix(4)
                .map {
                    AttributeDeltaReward(
                        key: $0.key,
                        xpGained: $0.xpGained,
                        previousXP: $0.previousXP,
                        currentXP: $0.currentXP,
                        previousLevel: $0.previousLevel,
                        currentLevel: $0.currentLevel,
                        previousProgress: AttributeLevelCurve.progressFraction(forXP: $0.previousXP),
                        currentProgress: AttributeLevelCurve.progressFraction(forXP: $0.currentXP),
                        previousTier: $0.previousTier,
                        currentTier: $0.currentTier
                    )
                }
        }

        return (progression?.attributeLines ?? [])
            .prefix(4)
            .map {
                AttributeDeltaReward(
                    key: $0.key,
                    xpGained: $0.xpGained,
                    previousXP: 0,
                    currentXP: $0.xpGained,
                    previousLevel: $0.levelBefore,
                    currentLevel: $0.levelAfter,
                    previousProgress: $0.progressBefore,
                    currentProgress: $0.progressAfter,
                    previousTier: $0.tierAfter,
                    currentTier: $0.tierAfter
                )
            }
    }

    private static func attributeLevels(
        from completionResult: TrainingCompletionResult?,
        progression: ProgressionReceipt?
    ) -> [AttributeKey: Int] {
        if let profile = completionResult?.attributeProfileAfter {
            return profile.levels
        }

        if let rewards = completionResult?.attributeRewards, !rewards.isEmpty {
            return Dictionary(uniqueKeysWithValues: rewards.map { ($0.key, $0.currentLevel) })
        }

        return Dictionary(uniqueKeysWithValues: (progression?.attributeLines ?? []).map { ($0.key, $0.levelAfter) })
    }

    private static func attributePreviousLevels(
        from completionResult: TrainingCompletionResult?,
        progression: ProgressionReceipt?
    ) -> [AttributeKey: Int] {
        if let profile = completionResult?.attributeProfileBefore {
            return profile.levels
        }

        if let rewards = completionResult?.attributeRewards, !rewards.isEmpty {
            return Dictionary(uniqueKeysWithValues: rewards.map { ($0.key, $0.previousLevel) })
        }

        return Dictionary(uniqueKeysWithValues: (progression?.attributeLines ?? []).map { ($0.key, $0.levelBefore) })
    }

    private static func attributePreviousTiers(
        from completionResult: TrainingCompletionResult?,
        deltas: [AttributeDeltaReward]
    ) -> [AttributeKey: RankTitle] {
        if let profile = completionResult?.attributeProfileBefore {
            return profile.levelRankTitles
        }

        return Dictionary(uniqueKeysWithValues: deltas.map { ($0.key, $0.previousTier) })
    }

    private static func attributeTiers(
        from completionResult: TrainingCompletionResult?,
        deltas: [AttributeDeltaReward]
    ) -> [AttributeKey: RankTitle] {
        if let profile = completionResult?.attributeProfileAfter {
            return profile.levelRankTitles
        }

        return Dictionary(uniqueKeysWithValues: deltas.map { ($0.key, $0.currentTier) })
    }

    /// The REWARD hex shows each axis's progress toward its NEXT level (0–100%),
    /// not the absolute level/100 (that's the profile page's honest cumulative
    /// shape). Progress moves a lot per session, so the radar visibly pushes on
    /// the axes you trained. Axes that leveled up this session animate from empty
    /// (the level rolled over) rather than wrapping backward.
    private static func attributeHexValues(
        profile: AttributeProfile?,
        fallbackDeltas: [AttributeDeltaReward],
        useCurrent: Bool
    ) -> [AttributeKey: Double] {
        let leveledUp = Set(fallbackDeltas.filter(\.didIncreaseLevel).map(\.key))
        if let profile {
            return Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
                if !useCurrent && leveledUp.contains(key) { return (key, 0.0) }
                return (key, AttributeLevelCurve.progressFraction(forXP: profile.value(for: key).xp) * 100)
            })
        }

        return Dictionary(uniqueKeysWithValues: fallbackDeltas.map {
            ($0.key, (useCurrent ? $0.currentProgress : $0.levelProgressStart) * 100)
        })
    }

    private static func personalRecords(from rewardSummary: RewardSummary?) -> [PersonalRecordReward] {
        guard let pr = rewardSummary?.personalRecord else { return [] }
        return [
            PersonalRecordReward(
                liftName: pr.exerciseName,
                valueText: pr.displayValue,
                deltaText: pr.deltaText ?? "New best",
                family: family(for: pr.exerciseName, skillId: nil)
            )
        ]
    }

    private static func badges(from rewardSummary: RewardSummary?) -> [BadgeUnlock] {
        var badges = rewardSummary?.badgeUnlocks ?? []
        if let first = rewardSummary?.firstSet {
            badges.insert(
                BadgeUnlock(
                    id: "first-rep-\(first.skillId)",
                    title: "First Rep",
                    subtitle: "Started \(first.skillTitle).",
                    assetName: "badge_art_consistency_loop"
                ),
                at: 0
            )
        }
        return badges
    }

    private static func previousTier(before tier: RankTitle) -> RankTitle {
        let tiers = RankTitle.allCases
        guard let index = tiers.firstIndex(of: tier), index > tiers.startIndex else {
            return tier
        }
        return tiers[tiers.index(before: index)]
    }

    private static func family(for title: String, skillId: String?) -> LiftRewardFamily {
        let text = "\(skillId ?? "") \(title)".lowercased()
        if text.contains("pull") || text.contains("chin") || text.contains("row") || text.hasPrefix("pp.") {
            return .pull
        }
        if text.contains("squat") || text.contains("lunge") || text.contains("nordic") || text.hasPrefix("ld.") {
            return .legs
        }
        if text.contains("sit") || text.contains("lever") || text.contains("hollow") || text.contains("dragon") || text.hasPrefix("cl.") {
            return .core
        }
        if text.contains("handstand") || text.contains("push") || text.contains("dip") || text.contains("planche") || text.hasPrefix("hs.") || text.hasPrefix("pl.") || text.hasPrefix("cal.") {
            return .press
        }
        if text.contains("jump") || text.contains("clap") || text.contains("explosive") {
            return .explosive
        }
        return .general
    }
}
