import Foundation

/// The three tabs of the unified rank-detail screen. The container renders one
/// pane per case; each pane consumes the matching derived data on
/// `RankDetailViewModel`. Order here is the on-screen left-to-right order.
/// History folded into Stats (one rich data tab: PRs + graph + attempts).
enum RankDetailTab: String, CaseIterable, Hashable {
    case overview
    case rank
    case stats

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .rank:     return "Rank"
        case .stats:    return "Stats"
        }
    }
}

// MARK: - Shared display models
//
// Plain value types the four tabs render. The view model owns the (heavier)
// resolution logic and hands the tabs these flat, already-formatted rows so the
// tab views stay dumb and presentational.

/// One labelled stat tile (best / PR / accumulated ledger / last-logged).
struct RankStatItem: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
    var systemImage: String?

    init(id: String, label: String, value: String, systemImage: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }
}
