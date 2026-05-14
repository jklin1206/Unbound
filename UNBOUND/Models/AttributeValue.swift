import Foundation

struct AttributeValue: Codable, Sendable, Equatable {
    var peak: Double
    /// Callers must clamp to 0...100 — `AttributeIngest` and `AttributeDrift` enforce this invariant.
    var current: Double
    var lastContributionAt: Date

    static func zero(at date: Date) -> AttributeValue {
        AttributeValue(peak: 0, current: 0, lastContributionAt: date)
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
}
