import Foundation

struct AttributeProfile: Codable, Sendable, Equatable {
    let userId: String
    var values: [AttributeKey: AttributeValue]
    var computedAt: Date

    static func empty(userId: String, at date: Date) -> AttributeProfile {
        let v = AttributeValue.zero(at: date)
        let dict = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, v) })
        return AttributeProfile(userId: userId, values: dict, computedAt: date)
    }

    func value(for key: AttributeKey) -> AttributeValue {
        values[key] ?? AttributeValue.zero(at: computedAt)
    }

    func level(for key: AttributeKey) -> Int {
        value(for: key).level
    }

    var levels: [AttributeKey: Int] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, level(for: $0)) })
    }

    var rankTitles: [AttributeKey: RankTitle] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, value(for: $0).rankTitle) })
    }

    mutating func set(_ key: AttributeKey, _ value: AttributeValue) {
        values[key] = value
    }

    var dominant: AttributeKey {
        // Fallback unreachable: AttributeKey.allCases is never empty.
        AttributeKey.allCases.max(by: { value(for: $0).peak < value(for: $1).peak }) ?? .power
    }

    var weakest: AttributeKey {
        let active = AttributeKey.allCases.filter { value(for: $0).peak > 0 }
        let pool = active.isEmpty ? AttributeKey.allCases : active
        // Fallback unreachable: pool is never empty (defaults to allCases).
        return pool.min(by: { value(for: $0).peak < value(for: $1).peak }) ?? .mobility
    }

    var isBalanced: Bool {
        let peaks = AttributeKey.allCases.map { value(for: $0).peak }
        guard case let (minP?, maxP?) = (peaks.min(), peaks.max()) else { return true }
        return (maxP - minP) < 15
    }

    /// Derived athletic identity. Sub-project #2 implementation.
    var buildIdentity: BuildIdentity {
        let sorted = AttributeKey.allCases
            .sorted { value(for: $0).peak > value(for: $1).peak }
        let top1 = sorted[0]
        let top2 = sorted[1]
        let top3 = sorted[2]
        let peaks = sorted.map { value(for: $0).peak }
        let spread = (peaks.max() ?? 0) - (peaks.min() ?? 0)

        if spread < 15 {
            return BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        }

        let gap12 = value(for: top1).peak - value(for: top2).peak
        let gap13 = value(for: top1).peak - value(for: top3).peak

        if gap12 > 25 {
            return BuildIdentity(primary: top1, secondary: nil, shape: .specialist)
        }
        if gap12 < 10 && gap13 < 10 {
            return BuildIdentity(primary: nil, secondary: nil, shape: .hybridAthlete)
        }
        if gap12 < 10 {
            return BuildIdentity(primary: top1, secondary: top2, shape: .hybrid)
        }
        return BuildIdentity(primary: top1, secondary: nil, shape: .lean)
    }

    /// Backward-compat alias. Phases 2b–2f gradually migrate consumers to
    /// `buildIdentity` directly; this alias keeps existing call sites
    /// working in the meantime.
    var buildName: String { buildIdentity.displayName }
}
