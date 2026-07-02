// UNBOUND/Views/Squads/SquadMissionCard.swift
//
// The weekly co-op mission content: emblem art, mono progress readout, a
// tinted bar, and top contributors. Rendered inside the Mission section card
// (the parent owns the box).
import SwiftUI

struct SquadMissionCard: View {
    let mission: SquadMission
    var contributions: [(name: String, total: Int)] = []

    private var progress: CGFloat { CGFloat(min(mission.progressFraction, 1.0)) }
    private var progressPercent: Int { Int((progress * 100).rounded()) }
    private var tint: Color { mission.isCompleted ? Color.unbound.success : mission.kind.tint }

    private var sortedContributions: [(name: String, total: Int)] {
        contributions.sorted { $0.total > $1.total }
    }

    private var visibleContributions: [(name: String, total: Int)] {
        Array(sortedContributions.prefix(3))
    }

    private var weekDaysRemaining: Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let now = Date()
        guard let end = calendar.dateInterval(of: .weekOfYear, for: now)?.end else { return 0 }
        return max(0, calendar.dateComponents([.day], from: now, to: end).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                emblem

                VStack(alignment: .leading, spacing: 3) {
                    Text(mission.kind.displayName)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(mission.kind.subtitle)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if mission.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.unbound.success)
                        .accessibilityLabel("Mission complete")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(mission.currentProgress.formatted(.number))
                        .font(Font.unbound.monoL)
                        .foregroundStyle(mission.isCompleted ? Color.unbound.success : Color.unbound.textPrimary)
                        .monospacedDigit()
                    Text("/ \(mission.kind.progressText(mission.target))")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.unbound.border)
                        Capsule()
                            .fill(tint)
                            .frame(width: max(proxy.size.width * progress, progress > 0 ? 6 : 0))
                    }
                }
                .frame(height: 5)

                MetaLine([
                    "\(progressPercent)%",
                    mission.isCompleted ? "cleared" : (weekDaysRemaining <= 1 ? "last day" : "\(weekDaysRemaining) days left")
                ])
            }

            if !visibleContributions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(visibleContributions.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(row.name)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            Text(mission.kind.progressText(row.total))
                                .font(Font.unbound.monoS)
                                .foregroundStyle(tint)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mission.kind.displayName), \(progressPercent) percent complete")
    }

    @ViewBuilder
    private var emblem: some View {
        if UIImage(named: mission.kind.emblemAssetName) != nil {
            Image(mission.kind.emblemAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
        } else {
            ZStack {
                Circle().fill(tint.opacity(0.16))
                Image(systemName: mission.kind.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 56, height: 56)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SquadMissionCard(
            mission: SquadMission(
                id: UUID(),
                squadId: UUID(),
                weekIso: "2026-W27",
                kind: .totalWeight,
                target: 32000,
                currentProgress: 18750,
                completedAt: nil,
                createdAt: .now
            ),
            contributions: [("You", 8200), ("Mara", 6100), ("Kenji", 4450)]
        )
        SquadMissionCard(
            mission: SquadMission(
                id: UUID(),
                squadId: UUID(),
                weekIso: "2026-W27",
                kind: .crewCoverage,
                target: 4,
                currentProgress: 4,
                completedAt: .now,
                createdAt: .now
            )
        )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
