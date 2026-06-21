import SwiftUI

/// Stats tab of the unified rank detail: the user's numbers - bests/PRs, total
/// AP, last logged. Only movement-relevant stats appear (no empty distance /
/// calories on a pull-up).
///
/// Renders `vm.statItems` as a 2-column fill-only raised-surface tile grid.
/// Each tile: small uppercase mono label + mono value readout + optional icon.
/// Before the first log there are no stats, so the tab shows a structured
/// first-time state instead — placeholder "—" tiles for the metrics relevant to
/// `vm.logMode`, plus a calm prompt — so the tab always has shape.
struct RankDetailStatsTab: View {
    let vm: RankDetailViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        Group {
            if vm.statItems.isEmpty {
                firstTimeState
            } else {
                tileGrid
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tile grid (has data)

    private var tileGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(vm.statItems.enumerated()), id: \.element.id) { index, stat in
                StatTileView(
                    stat: stat,
                    tint: vm.tint,
                    isLead: index == 0,
                    isPlaceholder: false
                )
            }
        }
    }

    // MARK: - First-time state (no data yet)

    private var firstTimeState: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(placeholderStats.enumerated()), id: \.element.id) { _, stat in
                    StatTileView(
                        stat: stat,
                        tint: vm.tint,
                        isLead: false,
                        isPlaceholder: true
                    )
                }
            }

            HStack(spacing: 9) {
                if vm.isLoading {
                    ProgressView()
                        .tint(Color.unbound.textTertiary)
                        .scaleEffect(0.8)
                    Text("Loading\u{2026}")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textTertiary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(vm.tint)
                    Text("Log your first set to start tracking.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
    }

    /// The placeholder tiles to scaffold, keyed off the metric this movement
    /// logs. Always ends with an Accumulated tile so the ledger row is present.
    private var placeholderStats: [RankStatItem] {
        var items: [RankStatItem]
        switch vm.logMode {
        case .reps:
            items = [RankStatItem(id: "ph-reps", label: "Best Reps", value: "\u{2014}", systemImage: "repeat")]
        case .hold:
            items = [RankStatItem(id: "ph-hold", label: "Best Hold", value: "\u{2014}", systemImage: "timer")]
        case .oneRepMax:
            items = [
                RankStatItem(id: "ph-1rm", label: "Best 1RM", value: "\u{2014}", systemImage: "trophy.fill"),
                RankStatItem(id: "ph-load", label: "Best Load", value: "\u{2014}", systemImage: "scalemass.fill")
            ]
        }
        items.append(RankStatItem(id: "ph-ap", label: "Accumulated", value: "\u{2014}", systemImage: "bolt.fill"))
        return items
    }
}

// MARK: - Stat tile

private struct StatTileView: View {
    let stat: RankStatItem
    let tint: Color
    let isLead: Bool
    let isPlaceholder: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 5) {
                if let icon = stat.systemImage {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(stat.label.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }

            Text(stat.value)
                .font(isLead ? Font.unbound.monoL.weight(.black) : Font.unbound.monoM.weight(.bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(tileBackground)
        .opacity(isPlaceholder ? 0.72 : 1)
    }

    private var iconColor: Color {
        isPlaceholder ? Color.unbound.textTertiary : (isLead ? tint : Color.unbound.textTertiary)
    }

    private var valueColor: Color {
        if isPlaceholder { return Color.unbound.textTertiary }
        return isLead ? tint : Color.unbound.textPrimary
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.unbound.surface)
    }
}
