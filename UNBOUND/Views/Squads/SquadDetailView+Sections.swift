// UNBOUND/Views/Squads/SquadDetailView+Sections.swift
import SwiftUI

extension SquadDetailView {
    var crewSection: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let presenceMap = Dictionary(uniqueKeysWithValues: state.activeRosterPresence.map { ($0.userId, $0) })
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("CREW RANKS")
                Spacer()
                if !state.activeRosterPresence.isEmpty {
                    Text("\(state.activeRosterPresence.count) LIVE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(state.roster) { member in
                    SquadMemberCard(
                        member: member,
                        presence: presenceMap[member.userId],
                        weeklySessionCount: weeklySessionCount(for: member.userId),
                        accountabilityBadge: accountabilityBadge(for: member.userId),
                        displayNameOverride: displayName(for: member),
                        profileUserId: resolvedProfileUserId(for: member),
                        cosmeticTier: frameTier(for: member),
                        onTap: { memberDetailTarget = member }
                    )
                }
            }
        }
    }

    var squadBoardSection: some View {
        SquadBoardView(rows: squadBoardRows, season: currentSeason)
    }

    func seasonRewardsSection(squad: Squad) -> some View {
        let rewards = SquadSeasonRewardsBuilder.makeRewards(
            squad: squad,
            rows: squadBoardRows,
            season: currentSeason
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

    private func earnedSeasonWinnerBanner(_ award: SquadSeasonWinnerTitleAward) -> some View {
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

    func squadStreakSection(squad: Squad) -> some View {
        SquadStreakHeroView(squad: squad, rows: squadBoardRows, season: currentSeason)
    }

    var routineDropsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("ROUTINE DROPS")
                Spacer()
                Text("\(routineDrops.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.warnOrange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.unbound.warnOrange.opacity(0.12)))
            }

            if let routineDropStatus {
                Text(routineDropStatus)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if routineDrops.isEmpty {
                emptySlab("No routines shared yet. Drop a Saved Workout from the Program tab.", icon: "square.and.arrow.up.fill")
            } else {
                VStack(spacing: 10) {
                    ForEach(routineDrops.prefix(5)) { drop in
                        SquadRoutineDropCard(
                            drop: drop,
                            authorName: displayName(for: drop.authorUserId),
                            isMine: drop.authorUserId == currentUserId,
                            onSave: { saveRoutineDrop(drop) },
                            onUseToday: { useRoutineDropToday(drop) }
                        )
                    }
                }
            }
        }
    }

    var challengesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("CHALLENGES")
                Spacer()
                Button {
                    showChallengeCreate = true
                } label: {
                    Label("NEW", systemImage: "plus")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            if activeChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.unbound.warnOrange.opacity(0.14))
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(Color.unbound.warnOrange)
                        }
                        .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("NO ACTIVE CHALLENGES")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("Start a 1v1 and put points on the season board.")
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }

                    Button {
                        showChallengeCreate = true
                    } label: {
                        Label("START CHALLENGE", systemImage: "bolt.fill")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.unbound.warnOrange.opacity(0.82))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .squadPanel(cornerRadius: 20, tint: Color.unbound.warnOrange)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        challengeMetric(value: "\(activeChallenges.count)", label: "ACTIVE")
                        challengeMetric(value: "\(challengeStatsByMember.values.map(\.seasonWins).reduce(0, +))", label: "SEASON WINS")
                        Spacer(minLength: 0)
                    }
                    ForEach(Array(activeChallenges.prefix(3))) { challenge in
                        ChallengeDashboardRow(challenge: challenge, roster: state.roster, currentUserId: currentUserId)
                    }
                    if activeChallenges.count > 3 {
                        Text("+\(activeChallenges.count - 3) more active")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(14)
                .squadPanel(cornerRadius: 20, tint: Color.unbound.warnOrange)
            }
        }
    }

    var footerSection: some View {
        VStack(spacing: 12) {
            if let error = leaveError {
                Text(error)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.alert)
                    .multilineTextAlignment(.center)
            }
            Button(role: .destructive) {
                showLeaveConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .bold))
                    Text("LEAVE SQUAD")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.2)
                }
                .font(Font.unbound.bodyMStrong)
                .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(Color.unbound.alert.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(Color.unbound.alert.opacity(0.38), lineWidth: 1))
                    .foregroundStyle(Color.unbound.alert)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func emptySlab(_ copy: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.78)))

            Text(copy)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .squadPanel(cornerRadius: 18, tint: Color.unbound.textTertiary)
    }

    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.unbound.accent.opacity(0.9))
                .frame(width: 3, height: 13)
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private func challengeMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(minWidth: 82)
        .frame(height: 42)
        .background(Capsule().fill(Color.unbound.warnOrange.opacity(0.11)))
        .overlay(Capsule().strokeBorder(Color.unbound.warnOrange.opacity(0.24), lineWidth: 1))
    }
}
