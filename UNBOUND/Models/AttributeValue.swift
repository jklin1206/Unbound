import Foundation

enum AttributeLevelCurve {
    static let attrBase: Double = 100
    static let exponent: Double = 1.5
    static let softCapLevel: Int = 100
    static let cappedXPPerLevel: Double = 1_500
    /// Transitional bridge for existing 0...100 profiles until raw AP fans into attribute XP directly.
    static let legacyScoreXPScale: Double = 50

    static func level(forXP xp: Double) -> Int {
        guard xp > 0 else { return 0 }
        let softCapXP = xpRequiredForUncappedLevel(softCapLevel)
        guard xp >= softCapXP else {
            return max(0, Int(floor(pow(xp / attrBase, 1.0 / exponent) + 1e-9)))
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

    static func hexDisplayValue(level: Int, progress: Double) -> Double {
        let effectiveLevel = max(0, Double(level) + min(1, max(0, progress)))
        let prePrestigeLevel = min(effectiveLevel, Double(softCapLevel))
        let base = 92 * pow(prePrestigeLevel / Double(softCapLevel), 0.9)

        guard effectiveLevel > Double(softCapLevel) else { return base }

        let postSoftCap = effectiveLevel - Double(softCapLevel)
        let prestigePush = 8 * (1 - exp(-postSoftCap / 75))
        return min(99.9, base + prestigePush)
    }

    static func hexPrestigeGlow(level: Int, progress: Double) -> Double {
        let effectiveLevel = max(0, Double(level) + min(1, max(0, progress)))
        guard effectiveLevel > Double(softCapLevel) else { return 0 }
        return min(1, 1 - exp(-(effectiveLevel - Double(softCapLevel)) / 75))
    }

    private static func xpRequiredForUncappedLevel(_ level: Int) -> Double {
        attrBase * pow(Double(max(0, level)), exponent)
    }

    static func xpAwarded(forScoreDelta delta: Double) -> Double {
        max(0, delta) * legacyScoreXPScale
    }

    static func legacyXP(forScore score: Double) -> Double {
        max(0, score) * legacyScoreXPScale
    }
}

struct AttributeValue: Codable, Sendable, Equatable {
    var peak: Double
    /// Callers must clamp to 0...100 — `AttributeIngest` and `AttributeDrift` enforce this invariant.
    var current: Double
    /// Permanent attribute XP. Unlike `current`, this never decays or caps.
    var xp: Double
    var lastContributionAt: Date

    init(peak: Double, current: Double, xp: Double? = nil, lastContributionAt: Date) {
        self.peak = peak
        self.current = current
        self.xp = xp ?? AttributeLevelCurve.legacyXP(forScore: max(peak, current))
        self.lastContributionAt = lastContributionAt
    }

    static func zero(at date: Date) -> AttributeValue {
        AttributeValue(peak: 0, current: 0, xp: 0, lastContributionAt: date)
    }

    /// Decay floor — `AttributeDrift` clamps `current` to this minimum after 37d idle (peak × 70%).
    var floor: Double { peak * 0.70 }

    var subRank: SubRank {
        SubRank.nearest(for: current / 100.0 * 17.0)
    }

    var rankTitle: RankTitle { subRank.title }

    var peakSubRank: SubRank {
        SubRank.nearest(for: peak / 100.0 * 17.0)
    }

    var peakRankTitle: RankTitle { peakSubRank.title }

    var level: Int { AttributeLevelCurve.level(forXP: xp) }

    var nextLevelXP: Double {
        AttributeLevelCurve.xpRequired(forLevel: level + 1)
    }

    var xpToNextLevel: Double {
        max(0, nextLevelXP - xp)
    }

    enum CodingKeys: String, CodingKey {
        case peak, current, xp, lastContributionAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        peak = try container.decode(Double.self, forKey: .peak)
        current = try container.decode(Double.self, forKey: .current)
        xp = try container.decodeIfPresent(Double.self, forKey: .xp)
            ?? AttributeLevelCurve.legacyXP(forScore: max(peak, current))
        lastContributionAt = try container.decode(Date.self, forKey: .lastContributionAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(peak, forKey: .peak)
        try container.encode(current, forKey: .current)
        try container.encode(xp, forKey: .xp)
        try container.encode(lastContributionAt, forKey: .lastContributionAt)
    }
}
