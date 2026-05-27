// UNBOUND/Views/Squads/WeeklyHonorsStrip.swift
//
// Horizontal strip of 3 honor cards for the current week.
// Placed between roster grid and activity feed in SquadDetailView.
import SwiftUI

struct WeeklyHonorsStrip: View {
    let honors: [WeeklyHonor]
    let roster: [SquadMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text("WEEKLY HONORS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(honors.first?.weekIso ?? "")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.unbound.textSecondary.opacity(0.6))
            }

            if honors.isEmpty {
                emptyState
            } else {
                // Horizontal scroll of honor cards — 3 per week
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(honors) { honor in
                            HonorCard(
                                honor: honor,
                                recipientName: displayName(for: honor.recipientUserId)
                            )
                        }
                    }
                    .padding(.horizontal, 1) // prevent clip
                }
            }
        }
    }

    // MARK: - Helpers

    private func displayName(for userId: UUID) -> String {
        roster.first(where: { $0.userId == userId })?.displayName ?? "Member"
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.unbound.textSecondary.opacity(0.5))
            Text("Honors drop Sunday night")
                .font(.system(size: 13))
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - HonorCard

private struct HonorCard: View {
    let honor: WeeklyHonor
    let recipientName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: honor.kind.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }

            // Kind name
            Text(honor.kind.displayName.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)

            // Recipient
            Text(recipientName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)

            // Reason
            Text(honor.kind.reason)
                .font(.system(size: 10))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.accent.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview("3 Honors") {
    let squadId = UUID()
    let userId1 = UUID()
    let userId2 = UUID()
    let userId3 = UUID()

    let roster: [SquadMember] = [
        SquadMember(id: UUID(), squadId: squadId, userId: userId1, joinedAt: .now, displayName: "Gojo", equippedTitle: nil, buildIdentity: nil),
        SquadMember(id: UUID(), squadId: squadId, userId: userId2, joinedAt: .now, displayName: "Toji", equippedTitle: nil, buildIdentity: nil),
        SquadMember(id: UUID(), squadId: squadId, userId: userId3, joinedAt: .now, displayName: "Megumi", equippedTitle: nil, buildIdentity: nil),
    ]
    let honors: [WeeklyHonor] = [
        WeeklyHonor(id: UUID(), squadId: squadId, weekIso: "2026-W20", kind: .mostConsistent, recipientUserId: userId1, awardedAt: .now),
        WeeklyHonor(id: UUID(), squadId: squadId, weekIso: "2026-W20", kind: .ironWill, recipientUserId: userId2, awardedAt: .now),
        WeeklyHonor(id: UUID(), squadId: squadId, weekIso: "2026-W20", kind: .vowFinisher, recipientUserId: userId3, awardedAt: .now),
    ]

    WeeklyHonorsStrip(honors: honors, roster: roster)
        .padding(20)
        .background(Color.unbound.bg)
}

#Preview("Empty") {
    WeeklyHonorsStrip(honors: [], roster: [])
        .padding(20)
        .background(Color.unbound.bg)
}
