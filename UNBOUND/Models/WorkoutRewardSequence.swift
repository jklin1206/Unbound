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
    var attributePreviousPrestigeGlow: [AttributeKey: Double] = [:]
    var attributeCurrentPrestigeGlow: [AttributeKey: Double] = [:]
    var attributePreviousLevels: [AttributeKey: Int] = [:]
    var attributeLevels: [AttributeKey: Int] = [:]
    var attributePreviousTiers: [AttributeKey: RankTitle] = [:]
    var attributeTiers: [AttributeKey: RankTitle] = [:]
    var personalRecords: [PersonalRecordReward]
    var badges: [BadgeUnlock]
    var arcProgress: ArcProgressReward
    var cosmeticUnlock: CosmeticUnlockReward?
    var progression: ProgressionReceipt? = nil

    var hasShareableMoment: Bool {
        !personalRecords.isEmpty || !badges.isEmpty || liftProgress.contains(where: \.didAdvanceTier) || arcProgress.didCompleteArc
    }
}

struct XPReward {
    var total: Int
    var previousLevel: Int
    var newLevel: Int
    var previousProgress: Double
    var newProgress: Double
    var previousXP: Double = 0
    var currentXP: Double = 0
    var levelFloorXP: Double = 0
    var nextLevelXP: Double = 100
    var breakdown: [XPBreakdownLine]

    var didIncreaseLevel: Bool { newLevel > previousLevel }
    var xpIntoCurrentLevel: Double { max(0, currentXP - levelFloorXP) }
    var xpNeededForCurrentLevel: Double { max(1, nextLevelXP - levelFloorXP) }
    var xpRemainingInLevel: Double { max(0, nextLevelXP - currentXP) }
}

struct XPBreakdownLine: Identifiable {
    let id = UUID()
    var label: String
    var amount: Int
}

struct LiftProgressReward: Identifiable {
    let id = UUID()
    var liftName: String
    var family: LiftRewardFamily
    var fromTier: RankTitle
    var toTier: RankTitle
    var fromProgress: Double
    var toProgress: Double
    var xpGained: Int

    /// Current rank after this completed workout. Tier-band sigils should
    /// always render this rank, not a generic achievement badge.
    var currentTier: RankTitle { toTier }

    var didAdvanceTier: Bool { currentTier.ordinal > fromTier.ordinal }
    var nextTierName: String { currentTier.next?.displayName ?? "Maxed" }
}

enum LiftRewardFamily: String, CaseIterable {
    case press, pull, legs, core, mobility, explosive, general

    var displayName: String { rawValue.uppercased() }

    var tint: Color {
        switch self {
        case .press: return Color.unbound.emberGlow
        case .pull: return Color.unbound.coachCyan
        case .legs: return Color.unbound.ember
        case .core: return Color.unbound.success
        case .mobility: return Color.rewardTeal
        case .explosive: return Color.unbound.impact
        case .general: return Color.unbound.textSecondary
        }
    }

    var originOrnamentAssetName: String {
        switch self {
        case .press, .legs, .explosive: return "reward_ornament_origin_ember"
        case .core: return "reward_ornament_origin_green"
        case .pull, .mobility, .general: return "reward_ornament_origin_blue"
        }
    }

    var endpointOrnamentAssetName: String {
        switch self {
        case .press, .legs, .explosive: return "reward_ornament_endpoint_orange"
        case .mobility, .core: return "reward_ornament_endpoint_teal"
        case .pull, .general: return "reward_ornament_endpoint_blue"
        }
    }

    var tickOrnamentAssetName: String {
        switch self {
        case .explosive: return "reward_ornament_tick_violet"
        case .press, .legs: return "reward_ornament_tick_gold"
        default: return "reward_ornament_tick_bone"
        }
    }
}

struct AttributeDeltaReward: Identifiable {
    let id = UUID()
    var key: AttributeKey
    var xpGained: Double = 0
    var previousXP: Double = 0
    var currentXP: Double = 0
    var previousLevel: Int = 0
    var currentLevel: Int = 0
    var previousProgress: Double = 0
    var currentProgress: Double = 0
    var previous: Double
    var current: Double
    var previousTier: RankTitle
    var currentTier: RankTitle

    var delta: Double { current - previous }
    var didAdvanceTier: Bool { currentTier.ordinal > previousTier.ordinal }
    var didIncreaseLevel: Bool { currentLevel > previousLevel }
    var tint: Color { key.rewardTint }
    var levelFloorXP: Double { AttributeLevelCurve.xpRequired(forLevel: currentLevel) }
    var nextLevelXP: Double { AttributeLevelCurve.xpRequired(forLevel: currentLevel + 1) }
    var xpIntoCurrentLevel: Double { max(0, currentXP - levelFloorXP) }
    var xpNeededForCurrentLevel: Double { max(1, nextLevelXP - levelFloorXP) }
    var xpRemainingInLevel: Double { max(0, nextLevelXP - currentXP) }
    var levelProgressStart: Double { didIncreaseLevel ? 0 : previousProgress }

    /// Reward hex display value on the component's 0...100 axis.
    /// Uses permanent LVL + progress through the shared compressed display curve.
    var previousHexChartValue: Double {
        AttributeLevelCurve.hexDisplayValue(level: previousLevel, progress: previousProgress)
    }

    var currentHexChartValue: Double {
        AttributeLevelCurve.hexDisplayValue(level: currentLevel, progress: currentProgress)
    }

    var previousPrestigeGlow: Double {
        AttributeLevelCurve.hexPrestigeGlow(level: previousLevel, progress: previousProgress)
    }

    var currentPrestigeGlow: Double {
        AttributeLevelCurve.hexPrestigeGlow(level: currentLevel, progress: currentProgress)
    }
}

struct PersonalRecordReward: Identifiable {
    let id = UUID()
    var liftName: String
    var valueText: String
    var deltaText: String
    var family: LiftRewardFamily
}

struct ArcProgressReward {
    var arcName: String
    var week: Int
    var totalWeeks: Int
    var completedSessions: Int
    var totalSessions: Int
    var didCompleteWeek: Bool
    var didCompleteArc: Bool
    var bonusXP: Int

    var progress: Double {
        guard totalSessions > 0 else { return 0 }
        return min(1, max(0, Double(completedSessions) / Double(totalSessions)))
    }
}

struct CosmeticUnlockReward {
    var title: String
    var subtitle: String
    var tint: Color
}

extension AttributeKey {
    var rewardTint: Color {
        switch self {
        case .power: return Color.unbound.ember
        case .agility: return Color.unbound.rankGold
        case .control: return Color.unbound.success
        case .endurance: return Color.unbound.coachCyan
        case .mobility: return Color.rewardTeal
        case .explosiveness: return Color.unbound.impact
        }
    }
}

extension WorkoutRewardSequenceSummary {
    static func trainingReceipt(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult? = nil,
        rewardSummary: RewardSummary? = nil,
        fallbackXP: Int = 0,
        sourceName: String? = nil
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

        return WorkoutRewardSequenceSummary(
            workoutName: performanceLog.title,
            durationMinutes: durationMinutes,
            workSets: workSets,
            volumeKg: volumeKg,
            rpe: averageRPE,
            xp: sequenceXP,
            liftProgress: liftProgress(from: rewardSummary, fallbackXP: sequenceXP.total),
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
            attributePreviousPrestigeGlow: attributePrestigeGlow(
                profile: completionResult?.attributeProfileBefore,
                fallbackDeltas: attributeDeltas,
                useCurrent: false
            ),
            attributeCurrentPrestigeGlow: attributePrestigeGlow(
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
            progression: progression
        )
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
        badges: [BadgeUnlock] = []
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
        let overallXP = Int((progression?.overallLevelXPGained ?? 0).rounded())
        let skillXP = rewardSummary?.xpGained ?? (overallXP > 0 ? (completionResult?.skillXPGained ?? 0) : 0)

        if skillXP > 0 {
            breakdown.append(XPBreakdownLine(label: "Skill XP", amount: skillXP))
        }
        if overallXP > 0 {
            breakdown.append(XPBreakdownLine(label: "Level XP", amount: overallXP))
        }
        if fallbackXP > 0 && breakdown.isEmpty {
            breakdown.append(XPBreakdownLine(label: "\(sourceName) logged", amount: fallbackXP))
        }

        let totalXP = max(
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

    private static func liftProgress(from rewardSummary: RewardSummary?, fallbackXP: Int) -> [LiftProgressReward] {
        guard let rankUp = rewardSummary?.rankUp else { return [] }
        let fromTier = rankUp.fromTier ?? previousTier(before: rankUp.toTier)
        return [
            LiftProgressReward(
                liftName: rankUp.skillTitle,
                family: family(for: rankUp.skillTitle, skillId: rankUp.skillId),
                fromTier: fromTier,
                toTier: rankUp.toTier,
                fromProgress: rankUp.toTier.ordinal > fromTier.ordinal ? 0.86 : 0.42,
                toProgress: rankUp.toTier.ordinal > fromTier.ordinal ? 0.12 : 1.0,
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
                        previous: $0.previousScore,
                        current: $0.currentScore,
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
                    previous: Double($0.levelBefore),
                    current: Double($0.levelAfter),
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
            return profile.rankTitles
        }

        return Dictionary(uniqueKeysWithValues: deltas.map { ($0.key, $0.previousTier) })
    }

    private static func attributeTiers(
        from completionResult: TrainingCompletionResult?,
        deltas: [AttributeDeltaReward]
    ) -> [AttributeKey: RankTitle] {
        if let profile = completionResult?.attributeProfileAfter {
            return profile.rankTitles
        }

        return Dictionary(uniqueKeysWithValues: deltas.map { ($0.key, $0.currentTier) })
    }

    private static func attributeHexValues(
        profile: AttributeProfile?,
        fallbackDeltas: [AttributeDeltaReward],
        useCurrent: Bool
    ) -> [AttributeKey: Double] {
        if let profile {
            return Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
                let value = profile.value(for: key)
                return (
                    key,
                    AttributeLevelCurve.hexDisplayValue(
                        level: value.level,
                        progress: AttributeLevelCurve.progressFraction(forXP: value.xp)
                    )
                )
            })
        }

        return Dictionary(uniqueKeysWithValues: fallbackDeltas.map {
            ($0.key, useCurrent ? $0.currentHexChartValue : $0.previousHexChartValue)
        })
    }

    private static func attributePrestigeGlow(
        profile: AttributeProfile?,
        fallbackDeltas: [AttributeDeltaReward],
        useCurrent: Bool
    ) -> [AttributeKey: Double] {
        if let profile {
            return Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
                let value = profile.value(for: key)
                return (
                    key,
                    AttributeLevelCurve.hexPrestigeGlow(
                        level: value.level,
                        progress: AttributeLevelCurve.progressFraction(forXP: value.xp)
                    )
                )
            })
        }

        return Dictionary(uniqueKeysWithValues: fallbackDeltas.map {
            ($0.key, useCurrent ? $0.currentPrestigeGlow : $0.previousPrestigeGlow)
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
                AttributeDeltaReward(key: .power, previous: 42, current: 44.4, previousTier: .forged, currentTier: .forged),
                AttributeDeltaReward(key: .control, previous: 36, current: 37.1, previousTier: .apprentice, currentTier: .apprentice),
                AttributeDeltaReward(key: .endurance, previous: 31, current: 31.8, previousTier: .apprentice, currentTier: .apprentice),
                AttributeDeltaReward(key: .explosiveness, previous: 28, current: 28.5, previousTier: .novice, currentTier: .novice)
            ],
            personalRecords: [
                PersonalRecordReward(liftName: "Bench Press", valueText: "82.5 kg", deltaText: "+5 kg over best", family: .press)
            ],
            badges: [
                BadgeUnlock(id: "pr.session", title: "PR Feat", subtitle: "Set a new best lift.", assetName: "badge_art_pr_session")
            ],
            arcProgress: ArcProgressReward(arcName: "Arc 1 · Foundation", week: 2, totalWeeks: 4, completedSessions: 3, totalSessions: 4, didCompleteWeek: false, didCompleteArc: false, bonusXP: 500),
            cosmeticUnlock: CosmeticUnlockReward(title: "PR Frame · Ember", subtitle: "Available for major lift share cards.", tint: Color.unbound.emberGlow)
        )
    }
}

extension Color {
    static let rewardBlue = Color(.sRGB, red: 0.10, green: 0.56, blue: 1.00, opacity: 1.0)
    static let rewardTeal = Color(.sRGB, red: 0.16, green: 0.86, blue: 0.72, opacity: 1.0)
}
