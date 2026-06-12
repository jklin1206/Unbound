import Foundation
import SwiftUI

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

extension Color {
    static let rewardBlue = Color(.sRGB, red: 0.10, green: 0.56, blue: 1.00, opacity: 1.0)
    static let rewardTeal = Color(.sRGB, red: 0.16, green: 0.86, blue: 0.72, opacity: 1.0)
}
