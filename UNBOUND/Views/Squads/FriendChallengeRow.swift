// UNBOUND/Views/Squads/FriendChallengeRow.swift
//
// One 1v1 challenge as a calm list row. Pending invites show quiet
// Accept / Decline actions (or Withdraw for the challenger); live duels show
// both scores and a thin comparative bar — the viewer's share in violet.
import SwiftUI

struct FriendChallengeRow: View {
    let challenge: FriendChallenge
    let roster: [SquadMember]
    let currentUserId: UUID?
    var onAccept: (() -> Void)? = nil
    var onDecline: (() -> Void)? = nil

    private var isChallenger: Bool { challenge.challengerId == currentUserId }
    private var opponentId: UUID { isChallenger ? challenge.challengedId : challenge.challengerId }
    private var myProgress: Int { isChallenger ? challenge.challengerProgress : challenge.challengedProgress }
    private var opponentProgress: Int { isChallenger ? challenge.challengedProgress : challenge.challengerProgress }

    private var daysLeft: Int {
        max(0, Int(ceil(challenge.expiresAt.timeIntervalSinceNow / 86_400)))
    }

    private var title: String {
        if let exercise = challenge.exerciseName {
            return "\(challenge.kind.displayName) · \(exercise)"
        }
        return challenge.kind.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(challenge.isPending ? "Invite" : (daysLeft <= 1 ? "Last day" : "\(daysLeft)d left"))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            if challenge.isPending {
                pendingContent
            } else {
                duelContent
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Pending

    @ViewBuilder
    private var pendingContent: some View {
        if isChallenger {
            HStack(spacing: 10) {
                MetaLine(["Waiting for \(displayName(for: opponentId)) to accept"])
                Spacer(minLength: 8)
                if let onDecline {
                    quietAction("Withdraw", action: onDecline)
                }
            }
        } else {
            HStack(spacing: 10) {
                MetaLine(["\(displayName(for: challenge.challengerId)) challenged you"])
                Spacer(minLength: 8)
                if let onDecline {
                    quietAction("Decline", action: onDecline)
                }
                if let onAccept {
                    quietAction("Accept", emphasized: true, action: onAccept)
                }
            }
        }
    }

    // MARK: - Live duel

    private var duelContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            comparativeBar
            MetaLine(
                [
                    "You: \(challenge.kind.progressLabel(for: myProgress))",
                    "\(displayName(for: opponentId)): \(challenge.kind.progressLabel(for: opponentProgress))"
                ],
                emphasized: true
            )
        }
    }

    private var comparativeBar: some View {
        GeometryReader { proxy in
            let total = max(myProgress + opponentProgress, 1)
            let mine = CGFloat(myProgress) / CGFloat(total)
            HStack(spacing: 2) {
                Capsule()
                    .fill(Color.unbound.accent)
                    .frame(width: max(proxy.size.width * mine - 1, myProgress > 0 ? 8 : 0))
                Capsule()
                    .fill(Color.unbound.coachCyan.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 4)
        .accessibilityLabel("Your score \(myProgress) in violet, opponent \(opponentProgress) in cyan")
    }

    private func quietAction(_ label: String, emphasized: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(emphasized ? Color.unbound.accent : Color.unbound.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
    }

    private func displayName(for userId: UUID) -> String {
        roster.first(where: { $0.userId == userId })?.displayName ?? "Crewmate"
    }
}

#Preview {
    let squadId = UUID()
    let me = UUID()
    let opp = UUID()
    let roster = [
        SquadMember(id: UUID(), squadId: squadId, userId: me, joinedAt: .now, displayName: "You", equippedTitle: nil, buildIdentity: nil),
        SquadMember(id: UUID(), squadId: squadId, userId: opp, joinedAt: .now, displayName: "Mara", equippedTitle: nil, buildIdentity: nil)
    ]
    VStack(spacing: 0) {
        FriendChallengeRow(
            challenge: FriendChallenge(id: UUID(), challengerId: opp, challengedId: me, squadId: squadId, kind: .mostSessions, exerciseName: nil, startedAt: .now, expiresAt: Date().addingTimeInterval(6 * 86_400), acceptedAt: nil, challengerProgress: 0, challengedProgress: 0, winnerUserId: nil),
            roster: roster,
            currentUserId: me,
            onAccept: {},
            onDecline: {}
        )
        FriendChallengeRow(
            challenge: FriendChallenge(id: UUID(), challengerId: me, challengedId: opp, squadId: squadId, kind: .heaviestLift, exerciseName: "Bench Press", startedAt: .now, expiresAt: Date().addingTimeInterval(3 * 86_400), acceptedAt: .now, challengerProgress: 92, challengedProgress: 85, winnerUserId: nil),
            roster: roster,
            currentUserId: me
        )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
