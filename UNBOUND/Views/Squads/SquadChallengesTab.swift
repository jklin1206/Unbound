// UNBOUND/Views/Squads/SquadChallengesTab.swift
//
// MISSION tab: the weekly co-op mission (violet card with its emblem) and
// the 1v1 challenge list (orange card) — pending invites with
// accept/decline, then live duels.
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
        SquadSectionCard(
            title: "WEEKLY MISSION",
            icon: "flag.2.crossed.fill",
            tint: Color.unbound.accent,
            trailing: currentMissionState == nil ? nil : "\(SquadRewardPolicy.missionArcs) Arcs on clear"
        ) {
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
        .padding(.vertical, 4)
    }

    // MARK: - Challenges section

    var challengesSection: some View {
        let seasonWins = challengeStatsByMember.values.map(\.seasonWins).reduce(0, +)
        let pending = activeChallenges.filter(\.isPending)
        let live = activeChallenges.filter { !$0.isPending }

        return SquadSectionCard(
            title: "1V1 CHALLENGES",
            icon: "bolt.fill",
            tint: Color.unbound.warnOrange,
            trailing: seasonWins > 0 ? "\(seasonWins) wins this season" : nil
        ) {
            VStack(alignment: .leading, spacing: 2) {
                if activeChallenges.isEmpty {
                    Text("No active challenges. Start a 1v1 and put points on the season board.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)

                    UnboundButton(title: "Start a Challenge", variant: .secondary) {
                        showChallengeCreate = true
                    }
                    .padding(.top, 8)
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

                    Button {
                        showChallengeCreate = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("New challenge")
                                .font(Font.unbound.bodyS.weight(.semibold))
                        }
                        .foregroundStyle(Color.unbound.warnOrange)
                        .padding(.top, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New challenge")
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
