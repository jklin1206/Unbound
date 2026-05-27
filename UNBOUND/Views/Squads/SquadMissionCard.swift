// UNBOUND/Views/Squads/SquadMissionCard.swift
//
// Renders the current squad mission: title, shared progress bar, and reward preview.
// Placed near the top of SquadDetailView (after header, before aggregate Build hex).
import SwiftUI

struct SquadMissionCard: View {
    let mission: SquadMission

    private var progress: CGFloat { CGFloat(min(mission.progressFraction, 1.0)) }

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
                    Text("\(mission.currentProgress) / \(mission.target)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.unbound.textSecondary)
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

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surface)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.unbound.accent, Color.unbound.accent.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: progress)
                }
            }
            .frame(height: 6)

            // Reward preview
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.unbound.accent.opacity(0.8))
                Text("Crew XP bonus + squad activity badge")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.unbound.accent.opacity(0.25), lineWidth: 1)
                )
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

#Preview("Active Mission") {
    SquadMissionCard(
        mission: SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W20",
            kind: .alignedSessions,
            target: 12,
            currentProgress: 7,
            completedAt: nil,
            createdAt: .now
        )
    )
    .padding(20)
    .background(Color.unbound.bg)
}

#Preview("Completed Mission") {
    SquadMissionCard(
        mission: SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W20",
            kind: .perfectAttendance,
            target: 5,
            currentProgress: 5,
            completedAt: Date(),
            createdAt: .now
        )
    )
    .padding(20)
    .background(Color.unbound.bg)
}
