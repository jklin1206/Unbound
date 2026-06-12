// UNBOUND/Views/Squads/SquadMissionCard.swift
//
// Renders the current squad mission: title, flat progress bar, reward line,
// and an optional per-member contribution strip (sorted desc, up to 4 rows).
import SwiftUI

struct SquadMissionCard: View {
    let mission: SquadMission
    var contributions: [(name: String, total: Int)] = []

    private var progress: CGFloat { CGFloat(min(mission.progressFraction, 1.0)) }
    private var maxContribution: Int {
        max(contributions.map(\.total).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "flag.2.crossed.fill")
                    .foregroundStyle(Color.unbound.accent)
                    .font(.system(size: 14, weight: .semibold))
                Text("SQUAD MISSION")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                if mission.isCompleted {
                    completedBadge
                } else {
                    Text(mission.kind.progressText(mission.currentProgress) + " / " + mission.kind.progressText(mission.target))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                }
            }

            // Mission title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(mission.kind.displayName)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(mission.kind.subtitle)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }

            // Progress bar — flat accent fill, no gradient
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surfaceElevated)
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.unbound.accent)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: progress)
                }
            }
            .frame(height: 6)

            // Reward line
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.unbound.accent.opacity(0.8))
                Text("\(SquadRewardPolicy.missionArcs) Arcs each on completion")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            // Contribution strip — up to 4 members, sorted desc
            if !contributions.isEmpty {
                Divider()
                    .background(Color.unbound.surfaceElevated)

                VStack(spacing: 8) {
                    ForEach(Array(contributions.sorted { $0.total > $1.total }.prefix(4)), id: \.name) { row in
                        GeometryReader { geo in
                            HStack(spacing: 8) {
                                Text(row.name)
                                    .font(Font.unbound.captionS)
                                    .foregroundStyle(Color.unbound.textSecondary)
                                    .frame(width: 88, alignment: .leading)
                                    .lineLimit(1)

                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.unbound.surfaceElevated)
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.unbound.accent)
                                        .frame(
                                            width: max(4, (geo.size.width - 88 - 8 - 60) * CGFloat(row.total) / CGFloat(maxContribution)),
                                            height: 4
                                        )
                                }

                                Text(mission.kind.progressText(row.total))
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Color.unbound.textTertiary)
                                    .monospacedDigit()
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                        .frame(height: 16)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    // MARK: - Subviews

    private var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.green)
            Text("DONE")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.green.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview("Active Mission — no contributions") {
    SquadMissionCard(
        mission: SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W24",
            kind: .totalWeight,
            target: 32000,
            currentProgress: 18750,
            completedAt: nil,
            createdAt: .now
        )
    )
    .padding(20)
    .background(Color.unbound.bg)
}

#Preview("Active Mission — with contributions") {
    SquadMissionCard(
        mission: SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W24",
            kind: .totalWeight,
            target: 32000,
            currentProgress: 18750,
            completedAt: nil,
            createdAt: .now
        ),
        contributions: [
            (name: "Marcus", total: 8200),
            (name: "You", total: 6100),
            (name: "Linked sessions", total: 4450),
        ]
    )
    .padding(20)
    .background(Color.unbound.bg)
}

#Preview("Completed Mission") {
    SquadMissionCard(
        mission: SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W24",
            kind: .crewCoverage,
            target: 4,
            currentProgress: 4,
            completedAt: Date(),
            createdAt: .now
        ),
        contributions: [
            (name: "Marcus", total: 4),
            (name: "You", total: 3),
            (name: "Kenji", total: 3),
            (name: "Ava", total: 3),
        ]
    )
    .padding(20)
    .background(Color.unbound.bg)
}
