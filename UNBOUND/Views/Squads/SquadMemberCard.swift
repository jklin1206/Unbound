// UNBOUND/Views/Squads/SquadMemberCard.swift
import SwiftUI

struct SquadMemberCard: View {
    let member: SquadMember
    let presence: SquadPresence?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textPrimary)
                    if let titleId = member.equippedTitle {
                        TitleBadge(titleId: titleId, compact: true)
                    }
                }
                Spacer()
                if let presence, presence.isActive {
                    presenceChip(startedAt: presence.workoutStartedAt)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private var avatar: some View {
        let initials = member.displayName.split(separator: " ").compactMap { $0.first }.prefix(2)
        let initialString = initials.map(String.init).joined()
        return ZStack {
            Circle().fill(Color.unbound.accent.opacity(0.2))
            Text(initialString.uppercased())
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.accent)
        }
        .frame(width: 40, height: 40)
    }

    private func presenceChip(startedAt: Date) -> some View {
        let elapsedMinutes = Int(Date.now.timeIntervalSince(startedAt) / 60)
        return HStack(spacing: 4) {
            Circle().fill(Color.unbound.accent).frame(width: 6, height: 6)
            Text("IN WORKOUT · \(elapsedMinutes)m")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.accent)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SquadMemberCard(
            member: SquadMember(
                id: UUID(),
                squadId: UUID(),
                userId: UUID(),
                joinedAt: Date(),
                displayName: "Justin Lin",
                equippedTitle: nil,
                buildIdentity: nil
            ),
            presence: SquadPresence(
                userId: UUID(),
                squadId: UUID(),
                workoutStartedAt: Date().addingTimeInterval(-23 * 60),
                expiresAt: Date().addingTimeInterval(3600)
            ),
            onTap: {}
        )
        SquadMemberCard(
            member: SquadMember(
                id: UUID(),
                squadId: UUID(),
                userId: UUID(),
                joinedAt: Date(),
                displayName: "Alex Kim",
                equippedTitle: nil,
                buildIdentity: nil
            ),
            presence: nil,
            onTap: {}
        )
    }
    .padding(16)
    .background(Color.unbound.bg)
}
