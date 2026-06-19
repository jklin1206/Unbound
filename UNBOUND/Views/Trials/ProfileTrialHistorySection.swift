import SwiftUI

// MARK: - ProfileTrialHistorySection
//
// Profile section: the simple list of vows you've cleared, most recent first.
// Just the completed vows — name, lane, and when.

struct ProfileTrialHistorySection: View {
    let trialsState: TrialsState

    private var kept: [KeptVow] {
        trialsState.keptVows.sorted { $0.completedAt > $1.completedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if kept.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(kept) { row($0) }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "seal.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.rankGold)
            Text("VOWS KEPT")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer(minLength: 0)
            if !kept.isEmpty {
                Text("\(kept.count)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
            }
        }
    }

    private func row(_ vow: KeptVow) -> some View {
        let tint = vow.lane.tintColor
        return HStack(spacing: 12) {
            Image(systemName: vow.lane.sealSymbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(vow.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(vow.lane.displayLabel)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(tint)
            Text(relativeDate(vow.completedAt))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.7))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vow.name), \(vow.lane.displayLabel), kept \(relativeDate(vow.completedAt)).")
    }

    private var emptyState: some View {
        Text("No vows kept yet — bind one this week and clear it.")
            .font(Font.unbound.bodyS)
            .foregroundStyle(Color.unbound.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "TODAY" }
        if days == 1 { return "1D AGO" }
        if days < 7 { return "\(days)D AGO" }
        let weeks = days / 7
        return weeks == 1 ? "1W AGO" : "\(weeks)W AGO"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ProfileTrialHistorySection(trialsState: {
            var state = WeeklyVowsState.empty
            state.keptVows = [
                KeptVow(vowId: "v1", name: "Still Water Vow", lane: .recovery, completedAt: Date().addingTimeInterval(-1 * 86_400)),
                KeptVow(vowId: "v2", name: "First Spark Vow", lane: .fuel, completedAt: Date().addingTimeInterval(-4 * 86_400)),
                KeptVow(vowId: "v3", name: "Iron Lungs Vow", lane: .engine, completedAt: Date().addingTimeInterval(-9 * 86_400))
            ]
            return state
        }())
        .padding(20)
    }
}
