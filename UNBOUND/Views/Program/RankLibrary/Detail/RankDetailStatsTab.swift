import SwiftUI

/// Stats tab of the unified rank detail — the rich data pane (History folded in).
/// Top to bottom:
///   1. PROGRESSION — a trend line graph over time (1RM / load / reps / hold) with
///      a 30D / 90D / ALL range selector. Only when attempt history exists.
///   2. PERSONAL RECORDS — the bests/PRs + derived numbers (attempts, first
///      logged, accumulated, last logged) as a 2-column tile grid.
///   3. PAST ATTEMPTS — the chronological attempt log, most recent first.
///
/// Before the first log there is no data, so the tab shows a structured first-time
/// state instead — placeholder "—" tiles for the metrics relevant to `vm.logMode`,
/// plus a calm prompt — so the tab always has shape.
struct RankDetailStatsTab: View {
    let vm: RankDetailViewModel

    @State private var selectedRange: ProgramRankRepGraphRange = .all

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var hasData: Bool { !vm.statItems.isEmpty || !vm.history.isEmpty }

    var body: some View {
        Group {
            if hasData {
                VStack(alignment: .leading, spacing: 22) {
                    if !vm.history.isEmpty {
                        progressionSection
                    }
                    recordsSection
                    if !vm.history.isEmpty {
                        attemptsSection
                    }
                }
            } else {
                firstTimeState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1. Progression graph

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PROGRESSION")
            ProgramRankProofHistoryLineGraph(
                entries: vm.history,
                currentValue: currentValue,
                historyValue: historyValue(for:),
                valueFormatter: formatValue(_:),
                selectedRange: $selectedRange,
                tint: vm.tint,
                accessibilityUnit: logMode.accessibilityUnit
            )
        }
    }

    // MARK: - 2. Records + derived tiles

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PERSONAL RECORDS")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(gridStats.enumerated()), id: \.element.id) { index, stat in
                    StatTileView(stat: stat, tint: vm.tint, isLead: index == 0, isPlaceholder: false)
                }
            }
        }
    }

    /// PRs from the view model, plus two numbers derived here from the attempt
    /// history (no extra persistence needed).
    private var gridStats: [RankStatItem] {
        vm.statItems + derivedStats
    }

    private var derivedStats: [RankStatItem] {
        guard !vm.history.isEmpty else { return [] }
        var items: [RankStatItem] = [
            RankStatItem(id: "attempts", label: "Attempts", value: "\(vm.history.count)", systemImage: "number")
        ]
        if let first = vm.history.map(\.occurredAt).min() {
            items.append(RankStatItem(
                id: "first-logged",
                label: "First Logged",
                value: first.formatted(.dateTime.month(.abbreviated).day()),
                systemImage: "calendar.badge.clock"
            ))
        }
        return items
    }

    // MARK: - 3. Attempts list

    private var attemptsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("PAST ATTEMPTS")
                .padding(.bottom, 10)
            VStack(spacing: 0) {
                ForEach(sortedHistory) { entry in
                    HistoryEntryRow(entry: entry, tint: vm.tint)
                    if entry.id != sortedHistory.last?.id {
                        Divider().overlay(Color.unbound.borderSubtle.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - First-time state (no data yet)

    private var firstTimeState: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(placeholderStats.enumerated()), id: \.element.id) { _, stat in
                    StatTileView(stat: stat, tint: vm.tint, isLead: false, isPlaceholder: true)
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

    /// The placeholder tiles to scaffold, keyed off the metric this movement logs.
    /// Always ends with an Accumulated tile so the ledger row is present.
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

    // MARK: - History helpers (graph + list)

    private var logMode: ProgramRankExerciseLogMode {
        guard let definition = vm.movementDefinition else { return .reps }
        return ProgramRankExerciseLogMode.mode(for: definition)
    }

    private var sortedHistory: [ProgramRankExerciseHistoryEntry] {
        vm.history.sorted { $0.occurredAt > $1.occurredAt }
    }

    private func historyValue(for entry: ProgramRankExerciseHistoryEntry) -> Double? {
        switch logMode {
        case .oneRepMax: return entry.oneRepMaxKg
        case .reps:      return entry.reps.map(Double.init)
        case .hold:      return entry.holdSeconds.map(Double.init)
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch logMode {
        case .oneRepMax:
            let unit = WeightPlatePolicy.currentUnit
            return "\(WeightPlatePolicy.formatDisplayValue(unit.displayValue(fromKilograms: value)))\(unit.shortLabel)"
        case .reps:
            return "\(Int(value.rounded())) reps"
        case .hold:
            return ProgramRankExerciseFormatter.seconds(Int(value.rounded()))
        }
    }

    private var currentValue: Double {
        vm.history.compactMap { historyValue(for: $0) }.max() ?? 0
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(0.8)
            .foregroundStyle(Color.unbound.textTertiary)
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

// MARK: - History row

private struct HistoryEntryRow: View {
    let entry: ProgramRankExerciseHistoryEntry
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(entry.dateText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
