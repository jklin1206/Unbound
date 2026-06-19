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

    /// When set, the final beat offers an opt-in "Add a photo" button that
    /// tags the captured photo with this workout. Only the program
    /// training-completion path populates this; other reward presenters
    /// leave it nil (no photo button).
    var workoutPhotoContext: WorkoutPhotoSummary? = nil

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

/// Day-streak reward: the streak after this session, and whether the session
/// extended it (vs a same-day session that holds the streak).
struct StreakReward: Hashable {
    var dayCount: Int
    var didExtend: Bool
}

// MARK: - Unified per-exercise rank card

/// One movement's rank outcome for a session — the macro reward (the rank badge
/// they're at, and whether they ranked up) plus the micro reward (how close they
/// are to the next rank) plus any PR. Works for both bodyweight skills and
/// loaded lifts so the RANKS beat renders them identically.
struct ExerciseRankReward: Identifiable, Hashable {
    var id: String
    var exerciseName: String
    var skillId: String?          // nil for loaded lifts
    var rank: RankTitle           // current rank — the badge to show
    var didRankUp: Bool
    var fromRank: RankTitle?      // prior rank, for the reveal animation
    var progressToNext: Double    // 0…1 toward the next rank (1.0 if maxed)
    var nextRank: RankTitle?      // nil = at peak
    var nextThresholdText: String?  // micro target, e.g. "5 reps to Veteran"
    var personalBestText: String?   // e.g. "New best · 75s"
    var family: LiftRewardFamily

    /// Tier-band badge art for the current rank.
    var badgeAssetName: String { rank.assetName }
    var tint: Color { family.tint }
    var isMaxed: Bool { nextRank == nil }
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
    var previousTier: RankTitle
    var currentTier: RankTitle

    var didAdvanceTier: Bool { currentTier.ordinal > previousTier.ordinal }
    var didIncreaseLevel: Bool { currentLevel > previousLevel }
    var tint: Color { key.rewardTint }
    var levelFloorXP: Double { AttributeLevelCurve.xpRequired(forLevel: currentLevel) }
    var nextLevelXP: Double { AttributeLevelCurve.xpRequired(forLevel: currentLevel + 1) }
    var xpIntoCurrentLevel: Double { max(0, currentXP - levelFloorXP) }
    var xpNeededForCurrentLevel: Double { max(1, nextLevelXP - levelFloorXP) }
    var xpRemainingInLevel: Double { max(0, nextLevelXP - currentXP) }
    var levelProgressStart: Double { didIncreaseLevel ? 0 : previousProgress }

    /// Reward hex fill on the component's 0...100 axis (`hexFill × 100`).
    var previousHexChartValue: Double {
        AttributeLevelCurve.hexFill(forLevel: previousLevel) * 100
    }

    var currentHexChartValue: Double {
        AttributeLevelCurve.hexFill(forLevel: currentLevel) * 100
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

struct WeeklyVowCompletionBonus: Codable, Equatable, Sendable {
    var overallLevelXP: Int
    var badgeProgress: WeeklyVowProgressDescriptor
    var shareCard: WeeklyVowShareCardDescriptor?
    var penaltyAppliedXP: Int?

    init(
        overallLevelXP: Int,
        badgeProgress: WeeklyVowProgressDescriptor,
        shareCard: WeeklyVowShareCardDescriptor? = nil,
        penaltyAppliedXP: Int? = nil
    ) {
        self.overallLevelXP = overallLevelXP
        self.badgeProgress = badgeProgress
        self.shareCard = shareCard
        self.penaltyAppliedXP = penaltyAppliedXP
    }

    private enum CodingKeys: String, CodingKey {
        case overallLevelXP
        case badgeProgress
        case shareCard
        case penaltyAppliedXP
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overallLevelXP = try container.decode(Int.self, forKey: .overallLevelXP)
        badgeProgress = try container.decode(WeeklyVowProgressDescriptor.self, forKey: .badgeProgress)
        shareCard = try container.decodeIfPresent(WeeklyVowShareCardDescriptor.self, forKey: .shareCard)
        penaltyAppliedXP = try container.decodeIfPresent(Int.self, forKey: .penaltyAppliedXP)
    }
}

struct WeeklyVowProgressDescriptor: Codable, Equatable, Sendable {
    var title: String
    var current: Int
    var target: Int

    var displayText: String {
        "\(title) \(current)/\(target)"
    }
}

struct WeeklyVowShareCardDescriptor: Codable, Equatable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var metadata: [String: String]
}

struct WeeklyVowRewardCallout: Identifiable, Equatable, Sendable {
    let id: String
    var vowId: String
    var performanceLogId: String
    var lane: VowLane
    var bet: VowBet
    var title: String
    var subtitle: String
    var receiptLine: String
    var shareTitle: String
    var shareSubtitle: String
    var completedAt: Date
    var completionBonus: WeeklyVowCompletionBonus? = nil
}

struct RankTrialRewardCallout: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var subtitle: String
    var statusLine: String
    var detailLine: String
    var receiptLine: String
    var passed: Bool
}

extension AttributeKey {
    var rewardTint: Color {
        switch self {
        case .power: return Color.unbound.ember
        case .vitality: return Color.unbound.rankGold
        case .control: return Color.unbound.success
        case .endurance: return Color.unbound.coachCyan
        case .mobility: return Color.rewardTeal
        case .explosiveness: return Color.unbound.impact
        }
    }
}

extension Color {
    static let rewardBlue = Color(.sRGB, red: 0.10, green: 0.56, blue: 1.00, opacity: 1.0)
    static let rewardTeal = Color(.sRGB, red: 0.16, green: 0.86, blue: 0.72, opacity: 1.0)
}
