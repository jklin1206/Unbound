// UNBOUND/Views/Squads/SquadSeasonTab.swift
import SwiftUI

extension SquadDetailView {
    @ViewBuilder
    func seasonTabContent(squad: Squad) -> some View {
        squadBoardSection
        seasonRewardsSection(squad: squad)
        squadTitlesRow
    }

    var squadBoardSection: some View {
        SquadBoardView(rows: squadBoardRows, season: currentSeason)
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
        let titleName = rewards.first { $0.kind == .individualTitle }?.title ?? currentSeason.winnerTitleName

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    showSeasonRewards.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rosette")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.unbound.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.accent.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("SEASON REWARDS")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text("\(titleName) + \(unlockedCount)/\(progressRewards.count) rewards")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .rotationEffect(.degrees(showSeasonRewards ? 180 : 0))
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.unbound.surface.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if showSeasonRewards {
                SquadSeasonRewardsView(rewards: rewards, season: currentSeason, showsHeader: false)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let earnedSeasonWinnerAward {
                earnedSeasonWinnerBanner(earnedSeasonWinnerAward)
            }
        }
    }

    func earnedSeasonWinnerBanner(_ award: SquadSeasonWinnerTitleAward) -> some View {
        HStack(spacing: 10) {
            if let assetName = award.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .shadow(color: Color.unbound.warnOrange.opacity(0.28), radius: 8)
            } else {
                Image(systemName: "rosette")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.warnOrange)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.warnOrange.opacity(0.12)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(award.titleName.uppercased()) EARNED")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Awarded from last season's squad leaderboard.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.warnOrange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.warnOrange.opacity(0.30), lineWidth: 1)
        )
    }

    @ViewBuilder
    var squadTitlesRow: some View {
        if !state.unlockedSquadTitles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(state.unlockedSquadTitles, id: \.self) { titleId in
                        SquadTitleBadge(titleId: titleId, compact: true)
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}
