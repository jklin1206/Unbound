// UNBOUND/Views/Squads/SquadDetailView.swift
import SwiftUI

struct SquadDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @State var state: SquadState = .empty
    @State var showInviteSheet = false
    @State var memberDetailTarget: SquadMember?
    @State var showLeaveConfirm = false
    @State var showLogoEditor = false
    @State var leaveError: String?
    @State var showChallengeCreate = false
    @State var showSeasonRewards = false
    @State var activeChallenges: [FriendChallenge] = []
    @State var routineDrops: [SquadRoutineDrop] = []
    @State var routineDropStatus: String?
    @State var memberProfiles: [UUID: UserProfile] = [:]
    @State var memberFrameTiers: [UUID: RankTitle] = [:]
    @State var memberWorkoutLogs: [UUID: [WorkoutLog]] = [:]
    @State var memberSessionRecords: [UUID: SessionXPRecord] = [:]
    @State var challengeStatsByMember: [UUID: FriendChallengeStats] = [:]
    @State var earnedSeasonWinnerAward: SquadSeasonWinnerTitleAward?
    @State var currentMissionState: SquadMission?
    @State var missionContributions: [MissionContribution] = []
    @State var showMissionPick = false
    @State var celebratedMission: SquadMission?

    enum SquadTab: String, CaseIterable {
        case crew = "CREW"
        case challenges = "CHALLENGES"
        case season = "SEASON"
    }
    @State var selectedTab: SquadTab = .crew

    var currentUserId: UUID? {
        services.auth.currentUserId.flatMap(SquadUserIdentity.uuid(from:))
    }

    var currentSeason: SquadSeason {
        SquadSeason.current()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            squadBackdrop

            if let squad = state.currentSquad {
                VStack(spacing: 0) {
                    compactHeader(squad: squad)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    tabPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            switch selectedTab {
                            case .crew: crewTabContent(squad: squad)
                            case .challenges: challengesTabContent
                            case .season: seasonTabContent(squad: squad)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 118)
                    }
                    .id(selectedTab)
                }
            } else {
                emptyStateView
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
        .sheet(isPresented: $showMissionPick) {
            SquadMissionPickSheet(
                memberCount: max(state.roster.count, 2)
            ) { kind in
                Task {
                    if let mission = try? await services.squadMission.pickMission(squadId: state.currentSquad?.id ?? UUID(), kind: kind) {
                        currentMissionState = mission
                    }
                }
            }
        }
        .fullScreenCover(item: $celebratedMission) { mission in
            let namedContributions: [(name: String, total: Int)] = missionContributions.map { contribution in
                let name = contribution.userId.map { displayName(for: $0) } ?? "Linked sessions"
                return (name: name, total: contribution.total)
            }
            SquadMissionCelebrationView(
                mission: mission,
                contributions: namedContributions,
                onClaim: { claimMissionReward(mission) }
            )
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
        .onReceive(NotificationCenter.default.publisher(for: .squadMissionCompleted)) { _ in
            Task { await refreshMissionState() }
        }
        .confirmationDialog("Leave this squad?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave Squad", role: .destructive) {
                Task { await leaveSquad() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can rejoin later with an invite code.")
        }
        .alert(
            "Couldn't leave squad",
            isPresented: Binding(
                get: { leaveError != nil },
                set: { if !$0 { leaveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(leaveError ?? "Try again.")
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
        await refreshMissionState()
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
        await refreshMissionState()
    }

    @MainActor
    private func refreshMissionState() async {
        guard let squadId = state.currentSquad?.id else {
            currentMissionState = nil
            missionContributions = []
            return
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--unbound-demo-squad-mission") {
            selectedTab = .challenges
            let demoId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID()
            currentMissionState = SquadMission(
                id: demoId,
                squadId: squadId,
                weekIso: SquadMissionService.currentWeekIso(),
                kind: .totalWeight,
                target: 32000,
                currentProgress: 18750,
                completedAt: nil,
                createdAt: .now
            )
            missionContributions = [
                MissionContribution(userId: nil, total: 8200),
                MissionContribution(userId: nil, total: 6100),
                MissionContribution(userId: nil, total: 4450),
            ]
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--unbound-demo-mission-celebration") {
            selectedTab = .challenges
            let demoId = UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-AAAAAAAAAAAA") ?? UUID()
            let completedMission = SquadMission(
                id: demoId,
                squadId: squadId,
                weekIso: SquadMissionService.currentWeekIso(),
                kind: .totalWeight,
                target: 32000,
                currentProgress: 33400,
                completedAt: Date(),
                createdAt: .now
            )
            currentMissionState = completedMission
            missionContributions = [
                MissionContribution(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"), total: 14200),
                MissionContribution(userId: UUID(uuidString: "22222222-2222-2222-2222-222222222222"), total: 11800),
                MissionContribution(userId: UUID(uuidString: "33333333-3333-3333-3333-333333333333"), total: 7400),
            ]
            celebratedMission = completedMission
            return
        }
        #endif
        currentMissionState = await services.squadMission.latestMission(squadId: squadId)
        if let mission = currentMissionState {
            if let contributions = try? await services.squadMission.fetchMissionContributions(missionId: mission.id) {
                missionContributions = contributions
            } else {
                missionContributions = []
            }
        } else {
            missionContributions = []
        }
        // Trigger celebration for completed missions not yet claimed
        if let mission = currentMissionState, mission.isCompleted {
            if let userId = services.auth.currentUserId {
                CurrencyWalletStore.shared.bind(userId: userId)
            }
            let sourceId = SquadRewardPolicy.missionSourceId(mission.id)
            if !CurrencyWalletStore.shared.hasGranted(sourceId: sourceId) {
                celebratedMission = mission
            }
        }
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

    private func compactHeader(squad: Squad) -> some View {
        HStack(spacing: 12) {
            editableCrestMark(squad: squad, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(squad.name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 10) {
                    metaItem(icon: "person.2.fill", text: "\(state.roster.count)/8")
                    metaItem(icon: "flame.fill", text: "\(squad.squadStreakWeeks)W")
                    metaItem(icon: "trophy.fill", text: currentSeason.title)
                }
            }

            Spacer(minLength: 0)

            if let inviteURL = squad.inviteURL {
                ShareLink(item: inviteURL) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.unbound.surface))
                }
            }

            Menu {
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label("Leave Squad", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.surface))
            }
        }
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(SquadTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(selectedTab == tab ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selectedTab == tab ? Color.unbound.surfaceElevated : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
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

    func sectionHeader(_ label: String) -> some View {
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

    func accountabilityBadge(for userId: UUID) -> AccountabilityBadgeState {
        AccountabilityBadgeState(userId: userId, clearedCount: state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count)
    }

    func weeklySessionCount(for userId: UUID) -> Int {
        if let row = squadBoardRows.first(where: { $0.member.userId == userId }) {
            return row.weeklySessions
        }
        return state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count
    }

    func displayName(for userId: UUID?) -> String {
        guard let userId else { return "UNBOUND" }
        if let member = state.roster.first(where: { $0.userId == userId }) {
            return displayName(for: member)
        }
        return "Crewmate"
    }

    func displayName(for member: SquadMember) -> String {
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

    func resolvedProfileUserId(for member: SquadMember) -> String {
        if let current = services.auth.currentUserId,
           SquadUserIdentity.uuid(from: current) == member.userId {
            return current
        }
        return member.userId.uuidString
    }

    func frameTier(for member: SquadMember) -> RankTitle {
        memberFrameTiers[member.userId] ?? .initiate
    }

    private func isCurrentMember(_ member: SquadMember) -> Bool {
        guard let current = services.auth.currentUserId else { return false }
        return SquadUserIdentity.uuid(from: current) == member.userId
    }

    func canEditSquad(_ squad: Squad) -> Bool {
        guard let currentUserId else { return false }
        return squad.captainId == currentUserId
    }

    var squadBoardRows: [SquadBoardRow] {
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
            leaveError = "Try again."
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

    func claimMissionReward(_ mission: SquadMission) {
        if let userId = services.auth.currentUserId {
            CurrencyWalletStore.shared.bind(userId: userId)
        }
        CurrencyWalletStore.shared.grant(
            SquadRewardPolicy.missionArcs,
            sourceId: SquadRewardPolicy.missionSourceId(mission.id)
        )
    }

}
