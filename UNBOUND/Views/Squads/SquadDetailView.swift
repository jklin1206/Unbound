// UNBOUND/Views/Squads/SquadDetailView.swift
import SwiftUI

struct SquadDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var state: SquadState = .empty
    @State private var showInviteSheet = false
    @State private var memberDetailTarget: SquadMember?
    @State private var showLeaveConfirm = false
    @State private var showLogoEditor = false
    @State private var leaveError: String?
    @State private var showChallengeCreate = false
    @State private var showSeasonRewards = false
    @State private var activeChallenges: [FriendChallenge] = []
    @State private var routineDrops: [SquadRoutineDrop] = []
    @State private var routineDropStatus: String?
    @State private var memberProfiles: [UUID: UserProfile] = [:]
    @State private var memberFrameTiers: [UUID: RankTitle] = [:]
    @State private var memberWorkoutLogs: [UUID: [WorkoutLog]] = [:]
    @State private var memberSessionRecords: [UUID: SessionXPRecord] = [:]
    @State private var challengeStatsByMember: [UUID: FriendChallengeStats] = [:]
    @State private var earnedSeasonWinnerAward: SquadSeasonWinnerTitleAward?

    private var currentUserId: UUID? {
        services.auth.currentUserId.flatMap(SquadUserIdentity.uuid(from:))
    }

    private var currentSeason: SquadSeason {
        SquadSeason.current()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            squadBackdrop

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if let squad = state.currentSquad {
                        headerCard(squad: squad)
                        squadStreakSection(squad: squad)
                        crewSection
                        challengesSection
                        squadBoardSection
                        seasonRewardsSection(squad: squad)
                        routineDropsSection
                        footerSection
                    } else {
                        emptyStateView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 118)
            }
        }
        .navigationTitle("Squad")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $memberDetailTarget) { member in
            NavigationStack {
                SquadMemberDetailView(member: member, roster: state.roster)
            }
        }
        .sheet(isPresented: $showChallengeCreate) {
            if let squad = state.currentSquad {
                FriendChallengeCreateSheet(
                    squadId: squad.id,
                    roster: state.roster,
                    onCreated: { challenge in
                        activeChallenges.append(challenge)
                    }
                )
            }
        }
        .sheet(isPresented: $showLogoEditor) {
            if let squad = state.currentSquad {
                SquadLogoEditSheet(initialLogoId: squad.logoId) { logoId in
                    Task { await setSquadLogo(logoId) }
                }
            }
        }
        .task {
            await loadAll()
        }
        .onDisappear {
            Task { await services.squadPresence.unsubscribeFromSquadPresence() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadStateChanged)) { _ in
            Task { await refreshState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadPresenceChanged)) { _ in
            Task { await refreshState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadActivityRecorded)) { _ in
            Task { await refreshState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadRoutineDropShared)) { _ in
            Task { await refreshRoutineDrops() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadTitleUnlocked)) { _ in
            Task { await refreshState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendChallengeExpired)) { _ in
            Task { await refreshChallenges() }
        }
        .confirmationDialog("Leave this squad?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave Squad", role: .destructive) {
                Task { await leaveSquad() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can rejoin later with an invite code.")
        }
    }

    @MainActor
    private func loadAll() async {
        guard let userId = services.auth.currentUserId else { return }
        await services.squads.loadCurrentSquad(userId: userId)
        state = services.squads.state(userId: userId)
        if let squadId = state.currentSquad?.id {
            await services.squadPresence.subscribeToSquadPresence(squadId: squadId)
        }
        await refreshMemberProfiles()
        await refreshMemberFrameTiers()
        await refreshChallenges()
        await refreshLeaderboardData()
        await awardEndedSeasonWinnerIfEligible()
        await refreshRoutineDrops()
    }

    @MainActor
    private func refreshState() async {
        guard let userId = services.auth.currentUserId else { return }
        state = services.squads.state(userId: userId)
        await refreshMemberProfiles()
        await refreshMemberFrameTiers()
        await refreshLeaderboardData()
        await awardEndedSeasonWinnerIfEligible()
        await refreshRoutineDrops()
    }

    @MainActor
    private func refreshRoutineDrops() async {
        guard let squadId = state.currentSquad?.id else {
            routineDrops = []
            return
        }
        routineDrops = await SquadRoutineDropService.shared.fetchRecent(squadId: squadId, limit: 12)
    }

    @MainActor
    private func refreshChallenges() async {
        if let me = currentUserId {
            activeChallenges = await services.friendChallenge.activeChallenges(userId: me)
        }
        if let squadId = state.currentSquad?.id {
            challengeStatsByMember = await services.friendChallenge.challengeStats(squadId: squadId)
        }
    }

    @MainActor
    private func refreshMemberProfiles() async {
        let roster = state.roster
        var profiles: [UUID: UserProfile] = [:]
        for member in roster {
            let profileUserId = resolvedProfileUserId(for: member)
            if let profile = try? await services.user.fetchProfile(userId: profileUserId) {
                profiles[member.userId] = profile
            }
        }
        memberProfiles = profiles
    }

    @MainActor
    private func refreshMemberFrameTiers() async {
        var tiers: [UUID: RankTitle] = [:]
        for member in state.roster {
            let profileUserId = resolvedProfileUserId(for: member)
            let aggregateTier = await services.rank.aggregateTier(userId: profileUserId)
            tiers[member.userId] = RankCosmetics.equippedFrameTier(
                userId: profileUserId,
                currentTier: aggregateTier
            )
        }
        memberFrameTiers = tiers
    }

    @MainActor
    private func refreshLeaderboardData() async {
        let roster = state.roster
        var logsByMember: [UUID: [WorkoutLog]] = [:]
        var recordsByMember: [UUID: SessionXPRecord] = [:]

        for member in roster {
            let profileUserId = resolvedProfileUserId(for: member)
            logsByMember[member.userId] = await fetchWorkoutLogs(userId: profileUserId, limit: 120)
            recordsByMember[member.userId] = services.sessionXP.record(userId: profileUserId)
        }

        memberWorkoutLogs = logsByMember
        memberSessionRecords = recordsByMember

        if let squadId = state.currentSquad?.id {
            challengeStatsByMember = await services.friendChallenge.challengeStats(squadId: squadId)
        } else {
            challengeStatsByMember = [:]
        }
    }

    private var squadBackdrop: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color.unbound.accent.opacity(0.17),
                        Color.unbound.warnOrange.opacity(0.07),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 340)

                Image("SquadCrest")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(proxy.size.width * 0.74, 320))
                    .opacity(0.11)
                    .blendMode(.screen)
                    .offset(x: 78, y: -58)

                LinearGradient(
                    stops: [
                        .init(color: Color.unbound.bg.opacity(0.02), location: 0),
                        .init(color: Color.unbound.bg.opacity(0.72), location: 0.72),
                        .init(color: Color.unbound.bg, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 360)
            }
            .frame(width: proxy.size.width, height: 360, alignment: .top)
        }
        .frame(height: 360)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var squadTitlesRow: some View {
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

    private func headerCard(squad: Squad) -> some View {
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
                            value: "\(state.roster.count)/\(squad.maxSize)",
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

    private var crewSection: some View {
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

    private var squadBoardSection: some View {
        SquadBoardView(
            rows: squadBoardRows,
            season: currentSeason,
            capacity: state.currentSquad?.maxSize ?? 10,
            inviteURL: state.currentSquad?.inviteURL
        )
    }

    private func seasonRewardsSection(squad: Squad) -> some View {
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

    private func squadStreakSection(squad: Squad) -> some View {
        SquadStreakHeroView(squad: squad, rows: squadBoardRows, season: currentSeason)
    }

    private var routineDropsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("LOADOUT DROPS")
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
                emptySlab("No loadouts shared yet. Drop a Loadout from the Quest Board.", icon: "square.and.arrow.up.fill")
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

    private var challengesSection: some View {
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

    private var footerSection: some View {
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

    private var emptyStateView: some View {
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

    private func crestMark(size: CGFloat, logoId: String?) -> some View {
        SquadLogoMarkView(logoId: logoId, size: size)
    }

    @ViewBuilder
    private func editableCrestMark(squad: Squad, size: CGFloat) -> some View {
        if canEditSquad(squad) {
            Button {
                showLogoEditor = true
            } label: {
                crestMark(size: size, logoId: squad.logoId)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.unbound.bg)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.unbound.accent))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 1))
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(.plain)
        } else {
            crestMark(size: size, logoId: squad.logoId)
        }
    }

    private func squadMetaPill(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.unbound.bg.opacity(0.46)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
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

    private func accountabilityBadge(for userId: UUID) -> AccountabilityBadgeState {
        AccountabilityBadgeState(userId: userId, clearedCount: state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count)
    }

    private func weeklySessionCount(for userId: UUID) -> Int {
        if let row = squadBoardRows.first(where: { $0.member.userId == userId }) {
            return row.weeklySessions
        }
        return state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count
    }

    private func displayName(for userId: UUID?) -> String {
        guard let userId else { return "UNBOUND" }
        if let member = state.roster.first(where: { $0.userId == userId }) {
            return displayName(for: member)
        }
        return "Crewmate"
    }

    private func displayName(for member: SquadMember) -> String {
        if let profile = memberProfiles[member.userId] {
            if let name = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return name
            }
            if let handle = profile.displayHandle?.trimmingCharacters(in: .whitespacesAndNewlines),
               !handle.isEmpty {
                return "@\(handle.trimmingCharacters(in: CharacterSet(charactersIn: "@")))"
            }
        }
        if isCurrentMember(member), ["Captain", "You"].contains(member.displayName) {
            return "You"
        }
        return member.displayName
    }

    private func resolvedProfileUserId(for member: SquadMember) -> String {
        if let current = services.auth.currentUserId,
           SquadUserIdentity.uuid(from: current) == member.userId {
            return current
        }
        return member.userId.uuidString
    }

    private func frameTier(for member: SquadMember) -> RankTitle {
        memberFrameTiers[member.userId] ?? .initiate
    }

    private func isCurrentMember(_ member: SquadMember) -> Bool {
        guard let current = services.auth.currentUserId else { return false }
        return SquadUserIdentity.uuid(from: current) == member.userId
    }

    private func canEditSquad(_ squad: Squad) -> Bool {
        guard let currentUserId else { return false }
        return squad.captainId == currentUserId
    }

    private var squadBoardRows: [SquadBoardRow] {
        SquadLeaderboardBuilder.makeBoardRows(
            roster: state.roster,
            displayNames: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, displayName(for: $0)) }),
            profileUserIds: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, resolvedProfileUserId(for: $0)) }),
            workoutLogs: memberWorkoutLogs,
            sessionRecords: memberSessionRecords,
            challengeStats: challengeStatsByMember,
            season: currentSeason
        )
    }

    @MainActor
    private func awardEndedSeasonWinnerIfEligible(now: Date = Date()) async {
        guard let userId = services.auth.currentUserId,
              let memberUserId = currentUserId,
              let squad = state.currentSquad
        else { return }

        let endedSeason = SquadSeason.previous(endingBefore: now)
        let challengeStats = await services.friendChallenge.challengeStats(squadId: squad.id, season: endedSeason)
        let rows = SquadLeaderboardBuilder.makeBoardRows(
            roster: state.roster,
            displayNames: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, displayName(for: $0)) }),
            profileUserIds: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, resolvedProfileUserId(for: $0)) }),
            workoutLogs: memberWorkoutLogs,
            sessionRecords: memberSessionRecords,
            challengeStats: challengeStats,
            season: endedSeason
        )
        guard let award = SquadLeaderboardBuilder.claimableWinnerTitleAward(
            rows: rows,
            season: endedSeason,
            currentUserId: userId,
            currentMemberUserId: memberUserId,
            now: now
        ) else { return }

        services.trials.unlockTitle(award.titleId, userId: userId)
        earnedSeasonWinnerAward = award
    }

    @MainActor
    private func fetchWorkoutLogs(userId: String, limit: Int) async -> [WorkoutLog] {
        (try? await services.database.query(
            collection: "workoutLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "startedAt",
            descending: true,
            limit: limit
        )) ?? []
    }

    @MainActor
    private func leaveSquad() async {
        guard let userId = services.auth.currentUserId else { return }
        do {
            try await services.squads.leaveSquad(userId: userId)
            state = services.squads.state(userId: userId)
        } catch {
            leaveError = "Couldn't leave squad. Try again."
        }
    }

    @MainActor
    private func setSquadLogo(_ logoId: String) async {
        guard let userId = services.auth.currentUserId else { return }
        do {
            try await services.squads.setLogo(logoId, userId: userId)
            state = services.squads.state(userId: userId)
        } catch {
            services.logging.log("SquadDetailView.setSquadLogo failed: \(error)", level: .warning)
        }
    }

    @MainActor
    private func saveRoutineDrop(_ drop: SquadRoutineDrop) {
        let saved = drop.savedWorkoutCopy()
        SavedWorkoutStore.shared.save(saved)
        routineDropStatus = "Saved \(drop.title) to your Loadouts."
    }

    @MainActor
    private func useRoutineDropToday(_ drop: SquadRoutineDrop) {
        let saved = drop.savedWorkoutCopy()
        SavedWorkoutStore.shared.save(saved)
        routineDropStatus = "Saved \(drop.title) and sent it to today's Daily Quest."
        NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            NotificationCenter.default.post(name: .savedWorkoutScheduleTodayRequested, object: saved)
        }
    }
}
