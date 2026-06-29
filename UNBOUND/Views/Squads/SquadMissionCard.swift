// UNBOUND/Views/Squads/SquadMissionCard.swift
//
// Renders the current squad mission: status, progress, reward line,
// and an optional per-member contribution strip.
import SwiftUI

struct SquadMissionCard: View {
    let mission: SquadMission
    var contributions: [(name: String, total: Int)] = []

    private var progress: CGFloat { CGFloat(min(mission.progressFraction, 1.0)) }
    private var progressPercent: Int { Int((progress * 100).rounded()) }
    private var maxContribution: Int {
        max(contributions.map(\.total).max() ?? 1, 1)
    }
    private var sortedContributions: [(name: String, total: Int)] {
        contributions.sorted { lhs, rhs in
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    private var visibleContributions: [(name: String, total: Int)] {
        Array(sortedContributions.prefix(5))
    }
    private var weekDaysRemaining: Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let now = Date()
        let end = calendar.dateInterval(of: .weekOfYear, for: now)?.end
            ?? calendar.date(byAdding: .day, value: 7, to: now)
            ?? now
        return max(
            0,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: end)
            ).day ?? 0
        )
    }
    private var tint: Color {
        mission.isCompleted ? Color.unbound.success : Color.unbound.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Image(systemName: "flag.2.crossed.fill")
                            .foregroundStyle(tint)
                            .font(.system(size: 13, weight: .black))
                        Text("WEEKLY MISSION")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }

                    Text(mission.kind.displayName)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                statusBadge
            }

            Text(mission.kind.subtitle)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(progressPercent)%")
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                    Text("complete")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer(minLength: 0)
                    Text("\(mission.kind.progressText(mission.currentProgress)) / \(mission.kind.progressText(mission.target))")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.unbound.bg.opacity(0.58))
                        Capsule()
                            .fill(tint)
                            .frame(width: progress <= 0 ? 0 : max(8, geo.size.width * progress))
                            .shadow(color: tint.opacity(0.26), radius: 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: progress)
                    }
                }
                .frame(height: 10)
            }

            HStack(spacing: 8) {
                missionMetric(value: mission.kind.progressText(mission.currentProgress), label: "DONE")
                missionMetric(value: mission.kind.progressText(mission.target), label: "TARGET")
                missionMetric(value: "\(weekDaysRemaining)D", label: "LEFT")
            }

            HStack(spacing: 9) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(tint.opacity(0.12)))
                Text("\(SquadRewardPolicy.missionArcs) Arcs each when the crew clears it")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.bg.opacity(0.34)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))

            if !visibleContributions.isEmpty {
                Divider()
                    .background(Color.unbound.surfaceElevated)

                VStack(alignment: .leading, spacing: 9) {
                    Text("CREW CONTRIBUTION")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)

                    ForEach(Array(visibleContributions.enumerated()), id: \.offset) { _, row in
                        contributionRow(row)
                    }

                    if sortedContributions.count > visibleContributions.count {
                        Text("+\(sortedContributions.count - visibleContributions.count) more contributors")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.12),
                            Color.unbound.surface.opacity(0.92),
                            Color.unbound.bg.opacity(0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            tint.opacity(0.32),
                            Color.unbound.borderSubtle
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "bolt.fill")
                .font(.system(size: 12))
            Text(mission.isCompleted ? "DONE" : "ACTIVE")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.3)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(tint.opacity(0.15))
        )
    }

    private func missionMetric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.54)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Capsule().fill(tint.opacity(0.10)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1))
    }

    private func contributionRow(_ row: (name: String, total: Int)) -> some View {
        GeometryReader { geo in
            HStack(spacing: 8) {
                Text(row.name)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 104, alignment: .leading)
                    .lineLimit(1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.bg.opacity(0.58))
                    Capsule()
                        .fill(tint)
                        .frame(
                            width: max(
                                4,
                                max(0, geo.size.width - 104 - 8 - 76) * CGFloat(row.total) / CGFloat(maxContribution)
                            )
                        )
                }
                .frame(height: 5)

                Text(mission.kind.progressText(row.total))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .frame(width: 76, alignment: .trailing)
            }
        }
        .frame(height: 18)
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
