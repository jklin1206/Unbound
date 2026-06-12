// UNBOUND/Views/Squads/SquadDetailView+Sections.swift
import SwiftUI

extension SquadDetailView {

    // MARK: - Header Card

    func headerCard(squad: Squad) -> some View {
        ZStack(alignment: .topTrailing) {
            SquadConsoleBackground(tint: Color.unbound.accent)

            SquadLogoMarkView(logoId: squad.logoId, size: 164, showsBorder: false)
                .opacity(0.13)
                .blendMode(.screen)
                .offset(x: 36, y: -34)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    editableCrestMark(squad: squad, size: 92)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(state.roster.count)")
                            .font(Font.unbound.monoM.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .monospacedDigit()
                        Text(state.roster.count == 1 ? "MEMBER" : "MEMBERS")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text(squad.name)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text("Protect the streak, win challenges, climb the season.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        squadMetaPill(
                            icon: "person.2.fill",
                            value: "\(state.roster.count)/8",
                            label: "CREW",
                            tint: Color.unbound.accent
                        )
                        squadMetaPill(
                            icon: "flame.fill",
                            value: "\(squad.squadStreakWeeks)W",
                            label: "STREAK",
                            tint: Color.unbound.warnOrange
                        )
                        squadMetaPill(
                            icon: "trophy.fill",
                            value: currentSeason.title,
                            label: "SEASON",
                            tint: Color.unbound.accent
                        )
                    }

                    squadTitlesRow
                }

                HStack(spacing: 10) {
                    Button {
                        showChallengeCreate = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("NEW CHALLENGE")
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.2)
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.unbound.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: Color.unbound.accent.opacity(0.24), radius: 18, y: 8)
                    }
                    .buttonStyle(.plain)

                    if let inviteURL = squad.inviteURL {
                        ShareLink(item: inviteURL) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.unbound.bg.opacity(0.52))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.unbound.accent.opacity(0.32),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 14)
    }

    // MARK: - Crew Section

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

    // MARK: - Challenges Section

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

    // MARK: - Squad Board Section

    var squadBoardSection: some View {
        SquadBoardView(rows: squadBoardRows, season: currentSeason)
    }

    // MARK: - Season Rewards Section

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

    // MARK: - Routine Drops Section

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

    // MARK: - Streak Section

    func squadStreakSection(squad: Squad) -> some View {
        SquadStreakHeroView(squad: squad, rows: squadBoardRows, season: currentSeason)
    }

    // MARK: - Footer Section

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

    // MARK: - Empty State

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            crestMark(size: 82, logoId: nil)
            Text("You're not in a squad.")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
