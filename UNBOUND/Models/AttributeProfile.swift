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

    /// Per-axis hex fill on the chart's 0...100 scale (`hexFill × 100`).
    var hexChartValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
            (key, value(for: key).hexFill * 100)
        })
    }

    var levelRankTitles: [AttributeKey: RankTitle] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, value(for: $0).rankTitle) })
    }

    mutating func set(_ key: AttributeKey, _ value: AttributeValue) {
        values[key] = value
    }

    /// Axes whose recent value has honestly drifted below their lifetime peak
    /// after a layoff. Drives the per-axis "recalibrating" signal.
    func staleAxes(asOf date: Date) -> [AttributeKey] {
        AttributeKey.allCases.filter { value(for: $0).isStale(asOf: date) }
    }

    /// True when any axis is stale (recent below lifetime peak after a layoff).
    func isStale(asOf date: Date) -> Bool {
        !staleAxes(asOf: date).isEmpty
    }

    var dominant: AttributeKey {
        // Fallback unreachable: AttributeKey.allCases is never empty.
        AttributeKey.allCases.max(by: { level(for: $0) < level(for: $1) }) ?? .power
    }

    var weakest: AttributeKey {
        let active = AttributeKey.allCases.filter { level(for: $0) > 0 }
        let pool = active.isEmpty ? AttributeKey.allCases : active
        // Fallback unreachable: pool is never empty (defaults to allCases).
        return pool.min(by: { level(for: $0) < level(for: $1) }) ?? .mobility
    }

    var isBalanced: Bool {
        let levels = AttributeKey.allCases.map { level(for: $0) }
        guard case let (minL?, maxL?) = (levels.min(), levels.max()) else { return true }
        return (maxL - minL) < 15
    }

    /// Derived athletic identity. Sub-project #2 implementation.
    var buildIdentity: BuildIdentity {
        let sorted = AttributeKey.allCases
            .sorted { level(for: $0) > level(for: $1) }
        let top1 = sorted[0]
        let top2 = sorted[1]
        let top3 = sorted[2]
        let levels = sorted.map { level(for: $0) }
        let spread = (levels.max() ?? 0) - (levels.min() ?? 0)

        if spread < 15 {
            return BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        }

        let gap12 = level(for: top1) - level(for: top2)
        let gap13 = level(for: top1) - level(for: top3)

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
