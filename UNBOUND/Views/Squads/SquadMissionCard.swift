// UNBOUND/Views/Squads/SquadMissionCard.swift
//
// The weekly co-op mission — the one raised surface on the Mission tab.
// Big mono progress readout, a thin violet bar, facts as a MetaLine, and the
// top contributors as quiet rows. Completed missions switch the readout to
// the success tone.
import SwiftUI

struct SquadMissionCard: View {
    let mission: SquadMission
    var contributions: [(name: String, total: Int)] = []

    private var progress: CGFloat { CGFloat(min(mission.progressFraction, 1.0)) }
    private var progressPercent: Int { Int((progress * 100).rounded()) }

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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mission.kind.displayName)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(mission.kind.subtitle)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
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
                            .fill(mission.isCompleted ? Color.unbound.success : Color.unbound.accent)
                            .frame(width: max(proxy.size.width * progress, progress > 0 ? 6 : 0))
                    }
                }
                .frame(height: 4)

                MetaLine([
                    "\(progressPercent)%",
                    mission.isCompleted ? "cleared" : (weekDaysRemaining <= 1 ? "last day" : "\(weekDaysRemaining) days left"),
                    "\(SquadRewardPolicy.missionArcs) Arcs on clear"
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
                                .foregroundStyle(Color.unbound.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .activeSurface(true, cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mission.kind.displayName), \(progressPercent) percent complete")
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
