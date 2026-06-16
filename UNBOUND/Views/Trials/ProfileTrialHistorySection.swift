import SwiftUI

// MARK: - ProfileTrialHistorySection
//
// Profile section that shows:
//   - Equipped title (if any)
//   - This week's active Binding Vow (if any)
//   - Lifetime completion counters from WeeklyVowsState
//
// NOTE: Full multi-week history is not persisted in v1 (WeeklyVowsState only
// holds the current week). This section surfaces what we have.

struct ProfileTrialHistorySection: View {
    let trialsState: TrialsState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            if let trial = trialsState.currentTrial {
                currentTrialRow(trial: trial)
            }

            completionStats

            if !trialsState.unlockedTitles.isEmpty {
                titlesRow
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

    // MARK: - Sub-views

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.2.crossed.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("BINDING VOWS")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)

            Spacer(minLength: 0)

            if let title = trialsState.equippedTitle {
                equippedTitleChip(title)
            }
        }
    }

    private func currentTrialRow(trial: Trial) -> some View {
        let tint = trial.chosenCard.lane.tintColor

        return HStack(spacing: 12) {
            WeeklyVowProofAsset(lane: trial.chosenCard.lane, tint: tint, compact: true)
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(trial.chosenCard.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(trial.chosenCard.lane.displayLabel)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(tint)
                    Text("·")
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(trial.capstoneState.label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(capstoneStateTint(trial.capstoneState))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var completionStats: some View {
        let totalCompletions = trialsState.completionsByLane.values.reduce(0, +)
        let recoveryCount = trialsState.completionsByLane[.recovery] ?? 0
        let fuelCount = trialsState.completionsByLane[.fuel] ?? 0
        let engineCount = trialsState.completionsByLane[.engine] ?? 0

        return HStack(spacing: 0) {
            statCell(value: "\(totalCompletions)", label: "COMPLETED")
            statDivider
            statCell(value: "\(recoveryCount)", label: "RECOVERY")
            statDivider
            statCell(value: "\(fuelCount)", label: "FUEL")
            statDivider
            statCell(value: "\(engineCount)", label: "ENGINE")
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle)
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }

    private var titlesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TITLES (\(trialsState.unlockedTitles.count))")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trialsState.unlockedTitles, id: \.self) { titleId in
                        titleChip(titleId, isEquipped: titleId == trialsState.equippedTitle)
                    }
                }
            }
        }
    }

    private func titleChip(_ titleId: TitleID, isEquipped: Bool) -> some View {
        let tint: Color = isEquipped ? Color.unbound.accent : Color.unbound.textTertiary
        return Text(TitleCatalog.displayName(for: titleId))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.13)))
            .overlay(Capsule().strokeBorder(tint.opacity(isEquipped ? 0.45 : 0.22), lineWidth: 1))
    }

    private func equippedTitleChip(_ titleId: TitleID) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.unbound.rankGold)
            Text(TitleCatalog.displayName(for: titleId))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.rankGold)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.unbound.rankGold.opacity(0.13)))
    }

    // MARK: - Helpers

    private func capstoneStateTint(_ state: CapstoneState) -> Color {
        switch state {
        case .pending:    return Color.unbound.textTertiary
        case .windowOpen: return Color.unbound.warnOrange
        case .completed:  return Color.unbound.success
        case .missed:     return Color.unbound.textTertiary
        }
    }
}

// MARK: - CapstoneState display helper

extension CapstoneState {
    fileprivate var label: String {
        switch self {
        case .pending:    return "ACTIVE"
        case .windowOpen: return "VOW READY"
        case .completed:  return "COMPLETE"
        case .missed:     return "MISSED"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ProfileTrialHistorySection(trialsState: TrialsState(
            currentWeekStart: Date(),
            currentWeekCards: [],
            currentTrial: Trial(
                id: "weekly-vow-W20-ember",
                userId: "preview",
                weekStart: Date(),
                chosenCard: TrialCard(
                    id: "weekly-vow-W20-recovery",
                    lane: .recovery,
                    bet: .small,
                    displayName: "Iron Reset",
                    blurb: "A low-day reset for clean recovery.",
                    target: VowTarget(count: 1, noun: "recovery reset")
                ),
                capstoneState: .windowOpen
            ),
            completionsByLane: [.recovery: 3, .fuel: 1, .engine: 0],
            unlockedTitles: [],
            equippedTitle: nil,
            skippedCurrentWeek: false
        ))
        .padding(20)
    }
}
