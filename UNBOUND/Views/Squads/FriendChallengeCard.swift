// UNBOUND/Views/Squads/FriendChallengeCard.swift
//
// Side-by-side parallel progress bars (own progress vs opponent),
// days remaining, challenge kind label.
// NOT a leaderboard — both players shown equally.
import SwiftUI

struct FriendChallengeCard: View {
    let challenge: FriendChallenge
    let currentUserId: UUID
    let roster: [SquadMember]

    private var isChallenger: Bool { challenge.challengerId == currentUserId }
    private var ownProgress: Int { isChallenger ? challenge.challengerProgress : challenge.challengedProgress }
    private var opponentProgress: Int { isChallenger ? challenge.challengedProgress : challenge.challengerProgress }
    private var opponentId: UUID { isChallenger ? challenge.challengedId : challenge.challengerId }
    private var opponentName: String {
        roster.first(where: { $0.userId == opponentId })?.displayName ?? "Opponent"
    }
    private var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: challenge.expiresAt).day ?? 0)
    }
    private var maxProgress: Int { max(ownProgress, opponentProgress, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: kind + days remaining
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.kind.displayName.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary ?? Color.unbound.textSecondary)
                    Text(challenge.kind.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if challenge.isPending {
                    pendingChip
                } else {
                    daysChip
                }
            }

            // Progress bars
            VStack(spacing: 8) {
                progressRow(label: "You", progress: ownProgress, maxProgress: maxProgress, isOwn: true)
                progressRow(label: opponentName, progress: opponentProgress, maxProgress: maxProgress, isOwn: false)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.accent.opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Progress row

    private func progressRow(label: String, progress: Int, maxProgress: Int, isOwn: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: isOwn ? .semibold : .regular))
                .foregroundStyle(isOwn ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surfaceElevated)
                        .frame(height: 5)
                    Capsule()
                        .fill(isOwn ? Color.unbound.accent : Color.unbound.accent.opacity(0.4))
                        .frame(width: geo.size.width * CGFloat(progress) / CGFloat(maxProgress), height: 5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 5)

            Text("\(progress)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isOwn ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Chips

    private var daysChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(daysRemaining == 1 ? "1 day left" : "\(daysRemaining)d left")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(daysRemaining <= 1 ? Color.orange : Color.unbound.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.unbound.surfaceElevated)
        )
    }

    private var pendingChip: some View {
        Text("PENDING")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.orange.opacity(0.15)))
    }
}

// MARK: - Preview

#Preview("Active Challenge") {
    let challengerId = UUID()
    let challengedId = UUID()
    let squadId = UUID()
    let roster: [SquadMember] = [
        SquadMember(id: UUID(), squadId: squadId, userId: challengerId, joinedAt: .now, displayName: "Toji", equippedTitle: nil, buildIdentity: nil),
        SquadMember(id: UUID(), squadId: squadId, userId: challengedId, joinedAt: .now, displayName: "Gojo", equippedTitle: nil, buildIdentity: nil),
    ]
    let challenge = FriendChallenge(
        id: UUID(),
        challengerId: challengerId,
        challengedId: challengedId,
        squadId: squadId,
        kind: .mostSessions,
        startedAt: .now,
        expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
        acceptedAt: Date(),
        challengerProgress: 4,
        challengedProgress: 3,
        winnerUserId: nil
    )
    FriendChallengeCard(challenge: challenge, currentUserId: challengerId, roster: roster)
        .padding(20)
        .background(Color.unbound.bg)
}
