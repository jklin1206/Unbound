// UNBOUND/Views/Squads/SquadSeasonTab.swift
//
// SEASON tab: the quarterly leaderboard (gold), this week's honors (amber),
// and the season rewards (violet) — each its own tinted section card with
// plain-language explainers.
import SwiftUI

extension SquadDetailView {
    @ViewBuilder
    func seasonTabContent(squad: Squad) -> some View {
        squadBoardSection
        honorsSection
        seasonRewardsSection(squad: squad)
        squadTitlesRow
    }

    var squadBoardSection: some View {
        SquadBoardView(
            rows: squadBoardRows,
            season: currentSeason,
            capacity: state.currentSquad?.maxSize ?? 10,
            inviteURL: state.currentSquad?.inviteURL,
            currentMemberUserId: currentUserId
        )
    }

    @ViewBuilder
    var honorsSection: some View {
        if !weeklyHonors.isEmpty {
            SquadSectionCard(
                title: "THIS WEEK'S HONORS",
                icon: "laurel.leading",
                tint: Color.unbound.rankAmber
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(weeklyHonors) { honor in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.unbound.rankAmber.opacity(0.16))
                                Image(systemName: "laurel.leading")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.unbound.rankAmber)
                            }
                            .frame(width: 34, height: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(honor.kind.displayName)
                                    .font(Font.unbound.bodyMStrong)
                                    .foregroundStyle(Color.unbound.textPrimary)
                                MetaLine([displayName(for: honor.recipientUserId)])
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    func seasonRewardsSection(squad: Squad) -> some View {
        let rewards = SquadSeasonRewardsBuilder.makeRewards(
            squad: squad,
            rows: squadBoardRows,
            season: currentSeason,
            missionsCompleted: seasonMissionsCompleted
        )
        let progressRewards = rewards.filter(\.usesProgress)
        let unlockedCount = progressRewards.filter(\.isUnlocked).count

        return SquadSectionCard(
            title: "SEASON REWARDS",
            icon: "gift.fill",
            tint: Color.unbound.impact,
            trailing: "\(unlockedCount)/\(progressRewards.count) unlocked"
        ) {
            VStack(alignment: .leading, spacing: 2) {
                SquadSeasonRewardsView(rewards: rewards, season: currentSeason, showsHeader: false)

                if let earnedSeasonWinnerAward {
                    earnedSeasonWinnerRow(earnedSeasonWinnerAward)
                }
            }
        }
    }

    func earnedSeasonWinnerRow(_ award: SquadSeasonWinnerTitleAward) -> some View {
        HStack(spacing: 12) {
            if let assetName = award.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                ZStack {
                    Circle().fill(Color.unbound.rankGold.opacity(0.16))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.rankGold)
                        .shadow(color: Color.unbound.rankGold.opacity(0.5), radius: 5)
                }
                .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(award.titleName) earned")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.rankGold)
                MetaLine(["From last season's squad board"])
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    @ViewBuilder
    var squadTitlesRow: some View {
        if !state.unlockedSquadTitles.isEmpty {
            SquadSectionCard(
                title: "SQUAD TITLES",
                icon: "medal.fill",
                tint: Color.unbound.rankGold
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.unlockedSquadTitles, id: \.self) { titleId in
                            SquadTitleBadge(titleId: titleId, compact: true)
                        }
                    }
                }
            }
        }
    }
}
