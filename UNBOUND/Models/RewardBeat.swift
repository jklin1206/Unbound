import Foundation

enum RewardBeatKind: String, Codable, Hashable, Sendable {
    case standardCleared
    case prereqCleared
    case skillUnlock
    case rankAdvance
    case newBest
}

struct RewardBeat: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var kind: RewardBeatKind
    var title: String
    var subtitle: String
    var skillId: String?
    var skillTitle: String?
    var tier: SkillTier?
    var sortRank: Int
}

struct RewardTally: Codable, Hashable, Sendable {
    var standardsCleared: Int
    var unlocksGained: Int
    var ranksAdvanced: Int
    var attributesGained: [AttributeKey: Int]
    var newBests: Int

    static let empty = RewardTally(
        standardsCleared: 0,
        unlocksGained: 0,
        ranksAdvanced: 0,
        attributesGained: [:],
        newBests: 0
    )

    var hasAnyReward: Bool {
        standardsCleared > 0
            || unlocksGained > 0
            || ranksAdvanced > 0
            || !attributesGained.isEmpty
            || newBests > 0
    }
}
