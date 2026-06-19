import Foundation

/// Per-axis change between two BuildIdentity snapshots. UI filters to
/// positive deltas only — regressions never appear as negative numbers
/// (see project_unbound_scans_never_show_setbacks). The `regressedAxes`
/// list exists so the UI can render quiet "Focus area" pills instead.
struct BuildIdentityDelta: Codable, Equatable {
    let perAxis: [AttributeKey: Int]

    init(perAxis: [AttributeKey: Int]) {
        self.perAxis = perAxis
    }

    var positiveDeltas: [AttributeKey: Int] {
        perAxis.filter { $0.value > 0 }
    }

    var regressedAxes: [AttributeKey] {
        perAxis.filter { $0.value < 0 }.map(\.key)
    }

    var primaryGrowthAxis: AttributeKey? {
        positiveDeltas.max(by: { $0.value < $1.value })?.key
    }
}
