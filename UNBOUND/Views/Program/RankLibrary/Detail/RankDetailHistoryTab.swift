import SwiftUI

/// History tab of the unified rank detail screen.
///
/// A `ProgramRankProofHistoryLineGraph` trend chart (with range selector) above a
/// chronological list of logged attempts, most recent first. Content flows in the
/// parent scroll; the container owns the horizontal inset.
struct RankDetailHistoryTab: View {
    let vm: RankDetailViewModel

    @State private var selectedRange: ProgramRankRepGraphRange = .all

    // MARK: - Derived helpers

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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.isLoading {
                loadingState
            } else if vm.history.isEmpty {
                emptyState
            } else {
                chartSection
                Divider()
                    .overlay(Color.unbound.borderSubtle)
                    .padding(.vertical, 16)
                listSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TREND")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)

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

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAST ATTEMPTS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
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

    // MARK: - Empty / loading

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Color.unbound.accent)
            Text("Loading history")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            VStack(spacing: 6) {
                Text("No attempts yet")
                    .font(Font.unbound.titleS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Log a set and it will appear here.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
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
