import Foundation

enum OverallLevelCurve {
    /// Overall LVL uses the same concave shape as attribute levels, but a
    /// larger pool so it represents total time-in-game instead of one axis.
    static let lvBase: Double = 250
    static let exponent: Double = AttributeLevelCurve.exponent
    static let softCapLevel: Int = 100
    static let cappedXPPerLevel: Double = 3_750

    static func level(forXP xp: Double) -> Int {
        guard xp > 0 else { return 0 }
        let softCapXP = xpRequiredForUncappedLevel(softCapLevel)
        guard xp >= softCapXP else {
            return max(0, Int(floor(pow(xp / lvBase, 1.0 / exponent) + 1e-9)))
        }
        return softCapLevel + Int(floor((xp - softCapXP) / cappedXPPerLevel + 1e-9))
    }

    static func xpRequired(forLevel level: Int) -> Double {
        guard level > 0 else { return 0 }
        guard level > softCapLevel else {
            return xpRequiredForUncappedLevel(level)
        }
        return xpRequiredForUncappedLevel(softCapLevel)
            + Double(level - softCapLevel) * cappedXPPerLevel
    }

    static func progressFraction(forXP xp: Double) -> Double {
        let level = level(forXP: xp)
        let floorXP = xpRequired(forLevel: level)
        let nextXP = xpRequired(forLevel: level + 1)
        guard nextXP > floorXP else { return 0 }
        return min(1, max(0, (xp - floorXP) / (nextXP - floorXP)))
    }

    private static func xpRequiredForUncappedLevel(_ level: Int) -> Double {
        lvBase * pow(Double(max(0, level)), exponent)
    }
}

struct OverallLevelProgress: Codable, Identifiable, Hashable, Sendable {
    var id: String { userId }

    let userId: String
    var totalXP: Double
    var lastGainedXP: Double
    var processedSourceLogIds: [String]
    var processedSourceRewards: [String: OverallLevelReward]
    var updatedAt: Date

    init(
        userId: String,
        totalXP: Double = 0,
        lastGainedXP: Double = 0,
        processedSourceLogIds: [String] = [],
        processedSourceRewards: [String: OverallLevelReward] = [:],
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.totalXP = totalXP
        self.lastGainedXP = lastGainedXP
        self.processedSourceLogIds = processedSourceLogIds
        self.processedSourceRewards = processedSourceRewards
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case userId, totalXP, lastGainedXP, processedSourceLogIds, processedSourceRewards, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        totalXP = try c.decode(Double.self, forKey: .totalXP)
        lastGainedXP = try c.decode(Double.self, forKey: .lastGainedXP)
        processedSourceLogIds = try c.decodeIfPresent([String].self, forKey: .processedSourceLogIds) ?? []
        processedSourceRewards = try c.decodeIfPresent([String: OverallLevelReward].self, forKey: .processedSourceRewards) ?? [:]
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(totalXP, forKey: .totalXP)
        try c.encode(lastGainedXP, forKey: .lastGainedXP)
        try c.encode(processedSourceLogIds, forKey: .processedSourceLogIds)
        try c.encode(processedSourceRewards, forKey: .processedSourceRewards)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    var level: Int {
        OverallLevelCurve.level(forXP: totalXP)
    }

    var progressToNextLevel: Double {
        OverallLevelCurve.progressFraction(forXP: totalXP)
    }

    mutating func apply(xpGained: Double, sourceLogId: String, at date: Date) {
        totalXP += max(0, xpGained)
        lastGainedXP = max(0, xpGained)
        if !processedSourceLogIds.contains(sourceLogId) {
            processedSourceLogIds.append(sourceLogId)
        }
        if processedSourceLogIds.count > 250 {
            let overflow = processedSourceLogIds.count - 250
            let removed = processedSourceLogIds.prefix(overflow)
            processedSourceLogIds.removeFirst(overflow)
            for source in removed {
                processedSourceRewards.removeValue(forKey: source)
            }
        }
        updatedAt = date
    }
}

struct OverallLevelReward: Codable, Hashable, Sendable {
    var xpGained: Double
    var noveltyMultiplier: Double
    var previousXP: Double
    var currentXP: Double
    var previousLevel: Int
    var currentLevel: Int
    var previousProgressToNextLevel: Double
    var currentProgressToNextLevel: Double
    /// Earned XP siphoned to pay down broken-vow debt this event (spec §5).
    var xpWithheldToVowDebt: Double = 0

    var didLevelUp: Bool {
        currentLevel > previousLevel
    }

    private enum CodingKeys: String, CodingKey {
        case xpGained, noveltyMultiplier, previousXP, currentXP
        case previousLevel, currentLevel
        case previousProgressToNextLevel, currentProgressToNextLevel
        case xpWithheldToVowDebt
    }
}

extension OverallLevelReward {
    /// Tolerant decode: `xpWithheldToVowDebt` was added with the vow-debt garnish
    /// feature, so rewards persisted before it lack the key. Decode it optionally
    /// (defaulting to 0) so existing `OverallLevelProgress` / replay documents keep
    /// loading instead of throwing and resetting the user to fresh progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            xpGained: try c.decode(Double.self, forKey: .xpGained),
            noveltyMultiplier: try c.decode(Double.self, forKey: .noveltyMultiplier),
            previousXP: try c.decode(Double.self, forKey: .previousXP),
            currentXP: try c.decode(Double.self, forKey: .currentXP),
            previousLevel: try c.decode(Int.self, forKey: .previousLevel),
            currentLevel: try c.decode(Int.self, forKey: .currentLevel),
            previousProgressToNextLevel: try c.decode(Double.self, forKey: .previousProgressToNextLevel),
            currentProgressToNextLevel: try c.decode(Double.self, forKey: .currentProgressToNextLevel),
            xpWithheldToVowDebt: try c.decodeIfPresent(Double.self, forKey: .xpWithheldToVowDebt) ?? 0
        )
    }
}
