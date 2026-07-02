// UNBOUND/Views/Squads/SquadSeasonTab.swift
//
// SEASON tab: the leaderboard, this week's honors, season rewards, and any
// earned winner title — all flat calm sections.
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
            VStack(alignment: .leading, spacing: 4) {
                CalmSectionHeader(title: "THIS WEEK'S HONORS")
                    .padding(.bottom, 6)
                ForEach(weeklyHonors) { honor in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.unbound.surfaceElevated)
                            Image(systemName: "laurel.leading")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.unbound.rankGold)
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
                    .padding(.vertical, 9)
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

        return VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    showSeasonRewards.toggle()
                }
            } label: {
                HStack {
                    CalmSectionHeader(
                        title: "SEASON REWARDS",
                        trailing: "\(unlockedCount)/\(progressRewards.count) unlocked"
                    )
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .rotationEffect(.degrees(showSeasonRewards ? 180 : 0))
                        .padding(.leading, 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Season rewards, \(unlockedCount) of \(progressRewards.count) unlocked")
            .padding(.bottom, 6)

            if showSeasonRewards {
                SquadSeasonRewardsView(rewards: rewards, season: currentSeason, showsHeader: false)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let earnedSeasonWinnerAward {
                earnedSeasonWinnerRow(earnedSeasonWinnerAward)
                    .padding(.top, 8)
            }
        }
    }

    func earnedSeasonWinnerRow(_ award: SquadSeasonWinnerTitleAward) -> some View {
        HStack(spacing: 12) {
            if let assetName = award.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ZStack {
                    Circle().fill(Color.unbound.surfaceElevated)
                    Image(systemName: "rosette")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.unbound.rankGold)
                }
                .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(award.titleName) earned")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                MetaLine(["From last season's squad board"])
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    @ViewBuilder
    var squadTitlesRow: some View {
        if !state.unlockedSquadTitles.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                CalmSectionHeader(title: "SQUAD TITLES")
                    .padding(.bottom, 6)
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
