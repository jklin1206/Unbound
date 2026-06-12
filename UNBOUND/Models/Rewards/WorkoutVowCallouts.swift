import Foundation
import SwiftUI

struct WeeklyVowCompletionBonus: Codable, Equatable, Sendable {
    var overallLevelXP: Int
    var badgeProgress: WeeklyVowProgressDescriptor
    var cosmeticProgress: WeeklyVowProgressDescriptor
    var shareCard: WeeklyVowShareCardDescriptor?
    var baseOverallLevelXP: Int?
    var penaltyAppliedXP: Int?

    init(
        overallLevelXP: Int,
        badgeProgress: WeeklyVowProgressDescriptor,
        cosmeticProgress: WeeklyVowProgressDescriptor,
        shareCard: WeeklyVowShareCardDescriptor?,
        baseOverallLevelXP: Int? = nil,
        penaltyAppliedXP: Int? = nil
    ) {
        self.overallLevelXP = overallLevelXP
        self.badgeProgress = badgeProgress
        self.cosmeticProgress = cosmeticProgress
        self.shareCard = shareCard
        self.baseOverallLevelXP = baseOverallLevelXP
        self.penaltyAppliedXP = penaltyAppliedXP
    }

    private enum CodingKeys: String, CodingKey {
        case overallLevelXP
        case badgeProgress
        case cosmeticProgress
        case shareCard
        case baseOverallLevelXP
        case penaltyAppliedXP
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overallLevelXP = try container.decode(Int.self, forKey: .overallLevelXP)
        badgeProgress = try container.decode(WeeklyVowProgressDescriptor.self, forKey: .badgeProgress)
        cosmeticProgress = try container.decode(WeeklyVowProgressDescriptor.self, forKey: .cosmeticProgress)
        shareCard = try container.decodeIfPresent(WeeklyVowShareCardDescriptor.self, forKey: .shareCard)
        baseOverallLevelXP = try container.decodeIfPresent(Int.self, forKey: .baseOverallLevelXP)
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
    var cardKind: WeeklyVowKind
    var theme: WeeklyVowTheme
    var title: String
    var subtitle: String
    var proofName: String
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
