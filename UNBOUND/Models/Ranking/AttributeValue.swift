import Foundation

enum AttributeLevelCurve {
    /// Clean, reachable ceiling — no soft-cap tail. L100 == a true "maxed it".
    static let maxLevel: Int = 100
    /// Cheap first levels → tiny visible slivers for new users. base=16 tunes
    /// the horizon to ~3yr balanced / ~6yr focused for a heavy trainer.
    static let base: Double = 16
    /// Quadratic steepening → a real top cliff (last level ≈ 200× the first).
    static let exponent: Double = 2.0

    /// Cumulative XP required to *reach* `level`. Clamped at `maxLevel`.
    static func xpRequired(forLevel level: Int) -> Double {
        let clamped = min(max(0, level), maxLevel)
        return base * pow(Double(clamped), exponent)
    }

    /// Permanent XP → level. Floors, clamps to `maxLevel`.
    static func level(forXP xp: Double) -> Int {
        guard xp > 0 else { return 0 }
        let raw = Int(floor(pow(xp / base, 1.0 / exponent) + 1e-9))
        return min(maxLevel, max(0, raw))
    }

    /// Hex fill 0…1. Linear and honest: `level / maxLevel`. No display trick.
    static func hexFill(forLevel level: Int) -> Double {
        Double(min(max(0, level), maxLevel)) / Double(maxLevel)
    }

    /// Fractional progress through the current level toward the next.
    static func progressFraction(forXP xp: Double) -> Double {
        let level = level(forXP: xp)
        guard level < maxLevel else { return 0 }
        let floorXP = xpRequired(forLevel: level)
        let nextXP = xpRequired(forLevel: level + 1)
        guard nextXP > floorXP else { return 0 }
        return min(1, max(0, (xp - floorXP) / (nextXP - floorXP)))
    }

    static func rankTitle(forLevel level: Int) -> RankTitle {
        rankThresholds
            .last(where: { level >= $0.level })?
            .title ?? .initiate
    }

    private static let rankThresholds: [(title: RankTitle, level: Int)] = [
        (.initiate, 0),
        (.novice, 3),
        (.apprentice, 6),
        (.forged, 10),
        (.veteran, 15),
        (.master, 25),
        (.vessel, 40),
        (.unbound, 65),
        (.ascendant, maxLevel)
    ]
}

struct AttributeValue: Codable, Sendable, Equatable {
    /// Permanent attribute XP — the single source of truth per axis. Never
    /// decays or caps below `maxLevel`. `level`, `rankTitle`, `hexFill`, and
    /// `progressToNextLevel` all derive from this.
    var xp: Double
    var lastContributionAt: Date

    init(xp: Double, lastContributionAt: Date) {
        self.xp = xp
        self.lastContributionAt = lastContributionAt
    }

    static func zero(at date: Date) -> AttributeValue {
        AttributeValue(xp: 0, lastContributionAt: date)
    }

    /// Honest-signal: the axis has gone idle past the recency grace window.
    /// `xp` and the derived `level`/`rankTitle` are unaffected — rank is never
    /// lost, the axis is only flagged as not-recently-trained.
    func isStale(asOf date: Date) -> Bool {
        let daysIdle = date.timeIntervalSince(lastContributionAt) / 86_400.0
        return daysIdle > AttributeDrift.graceDays
    }

    var level: Int { AttributeLevelCurve.level(forXP: xp) }

    var rankTitle: RankTitle {
        AttributeLevelCurve.rankTitle(forLevel: level)
    }

    /// 0…1 hex fill for this axis.
    var hexFill: Double {
        AttributeLevelCurve.hexFill(forLevel: level)
    }

    var nextLevelXP: Double {
        AttributeLevelCurve.xpRequired(forLevel: level + 1)
    }

    var xpToNextLevel: Double {
        max(0, nextLevelXP - xp)
    }

    enum CodingKeys: String, CodingKey {
        case xp, lastContributionAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        xp = try container.decode(Double.self, forKey: .xp)
        lastContributionAt = try container.decode(Date.self, forKey: .lastContributionAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(xp, forKey: .xp)
        try container.encode(lastContributionAt, forKey: .lastContributionAt)
    }
}
