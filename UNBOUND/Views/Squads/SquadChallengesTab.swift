// UNBOUND/Views/Squads/SquadChallengesTab.swift
//
// MISSION tab: the weekly co-op mission (the one raised surface on this
// tab) and the 1v1 challenge list — pending invites with accept/decline,
// then live duels as calm rows.
import SwiftUI

extension SquadDetailView {
    @ViewBuilder
    var challengesTabContent: some View {
        missionSection
        challengesSection
    }

    // MARK: - Mission section

    @ViewBuilder
    private var missionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            CalmSectionHeader(title: "WEEKLY MISSION")
                .padding(.bottom, 6)

            if let mission = currentMissionState {
                let namedContributions: [(name: String, total: Int)] = missionContributions.map { contribution in
                    let name = contribution.userId.map { displayName(for: $0) } ?? "Linked sessions"
                    return (name: name, total: contribution.total)
                }
                SquadMissionCard(mission: mission, contributions: namedContributions)
            } else {
                missionEmptyState(isCaptain: state.currentSquad.map { canEditSquad($0) } ?? false)
            }
        }
    }

    private func missionEmptyState(isCaptain: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCaptain ? "Pick the crew target" : "Waiting on the captain")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)

            Text(isCaptain
                 ? "Choose one co-op goal for this week. Every logged session pushes the bar, and clearing it pays \(SquadRewardPolicy.missionArcs) Arcs."
                 : "The next mission appears here as soon as it is picked or auto-assigned. Clearing it pays \(SquadRewardPolicy.missionArcs) Arcs.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if isCaptain {
                UnboundButton(title: "Choose Mission", variant: .secondary) {
                    showMissionPick = true
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Challenges section

    var challengesSection: some View {
        let seasonWins = challengeStatsByMember.values.map(\.seasonWins).reduce(0, +)
        let pending = activeChallenges.filter(\.isPending)
        let live = activeChallenges.filter { !$0.isPending }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                CalmSectionHeader(
                    title: "CHALLENGES",
                    trailing: seasonWins > 0 ? "\(seasonWins) wins this season" : nil
                )
                Spacer(minLength: 12)
                Button {
                    showChallengeCreate = true
                } label: {
                    Text("New")
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New challenge")
            }
            .padding(.bottom, 6)

            if activeChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No active challenges. Start a 1v1 and put points on the season board.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    UnboundButton(title: "Start a Challenge", variant: .secondary) {
                        showChallengeCreate = true
                    }
                }
                .padding(.vertical, 6)
            } else {
                ForEach(pending) { challenge in
                    FriendChallengeRow(
                        challenge: challenge,
                        roster: state.roster,
                        currentUserId: currentUserId,
                        onAccept: { acceptChallenge(challenge) },
                        onDecline: { declineChallenge(challenge) }
                    )
                }
                ForEach(live) { challenge in
                    FriendChallengeRow(
                        challenge: challenge,
                        roster: state.roster,
                        currentUserId: currentUserId
                    )
                }
            }
        }
    }

    func acceptChallenge(_ challenge: FriendChallenge) {
        Task {
            try? await services.friendChallenge.accept(challenge.id)
            await refreshChallenges()
        }
    }

    func declineChallenge(_ challenge: FriendChallenge) {
        Task {
            try? await services.friendChallenge.decline(challenge.id)
            await refreshChallenges()
        }
    }
}
