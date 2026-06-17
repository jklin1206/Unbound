import SwiftUI

// MARK: - ProfileTrialHistorySection
//
// Profile section that shows the evolving Vow Sigil, the badge-track progress
// line, and a calm row of the three lane seals (lit/dim by lifetime keeps).
// Equipped + unlocked Titles still surface here when present.
//
// NOTE: Full multi-week history is not persisted in v1 (WeeklyVowsState only
// holds the current week's vow). This section surfaces lifetime counters.

struct ProfileTrialHistorySection: View {
    let trialsState: TrialsState

    private var sigil: VowSigil {
        VowSigil(
            keptVows: VowBadgeTrack.totalKept(trialsState.completionsByLane),
            breakKeptSnapshots: trialsState.weeklyVowPenaltyLedger.map { $0.keptAtBreak ?? 0 }
        )
    }

    private var badgeProgress: VowBadgeTrack.Progress {
        VowBadgeTrack.progress(totalKept: sigil.sealedSegments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            sigilRow

            laneSealRow

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

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "seal.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.rankGold)
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

    // MARK: - Sigil + progress line

    private var sigilRow: some View {
        HStack(spacing: 16) {
            VowSigilView(sigil: sigil)
                .accessibilityHidden(false)

            VStack(alignment: .leading, spacing: 8) {
                progressStat(
                    label: "VOWS KEPT",
                    value: "\(badgeProgress.current)"
                )
                if let next = badgeProgress.nextThreshold {
                    progressStat(label: "NEXT", value: "\(next)")
                } else {
                    progressStat(label: "MILESTONES", value: "PEAK")
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func progressStat(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
    }

    // MARK: - Lane seals

    private var laneSealRow: some View {
        HStack(spacing: 8) {
            ForEach(VowLane.allCases, id: \.self) { lane in
                laneSeal(lane)
            }
        }
    }

    private func laneSeal(_ lane: VowLane) -> some View {
        let count = trialsState.completionsByLane[lane] ?? 0
        let isLit = count > 0
        let tint = lane.tintColor
        return VStack(spacing: 6) {
            Image(systemName: lane.sealSymbolName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isLit ? tint : Color.unbound.textTertiary)
                .opacity(isLit ? 1 : 0.55)
            Text(lane.displayLabel)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text("\(count)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(isLit ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(isLit ? 0.9 : 0.5))
        )
    }

    // MARK: - Titles

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
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ProfileTrialHistorySection(trialsState: TrialsState(
            currentWeekStart: Date(),
            currentWeekCards: [],
            currentTrial: nil,
            completionsByLane: [.recovery: 3, .fuel: 4, .engine: 0],
            unlockedTitles: [],
            equippedTitle: nil,
            skippedCurrentWeek: false
        ))
        .padding(20)
    }
}
