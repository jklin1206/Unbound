// UNBOUND/Views/Squads/SquadDetailView.swift
import SwiftUI

struct SquadDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var state: SquadState = .empty
    @State private var showInviteSheet = false
    @State private var memberDetailTarget: SquadMember?
    @State private var showLeaveConfirm = false
    @State private var leaveError: String?
    @State private var showChat = false
    @State private var showChallengeCreate = false
    @State private var activeChallenges: [FriendChallenge] = []
    @State private var messages: [SquadMessage] = []
    @State private var memberProfiles: [UUID: UserProfile] = [:]
    @State private var memberFrameTiers: [UUID: RankTitle] = [:]

    private var currentUserId: UUID? {
        services.auth.currentUserId.flatMap(SquadUserIdentity.uuid(from:))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            squadBackdrop

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if let squad = state.currentSquad {
                        headerCard(squad: squad)
                        crewStreakBadge(squad: squad)
                        crewSection
                        challengesSection
                        recentSection
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
        .sheet(isPresented: $showChat) {
            if let squad = state.currentSquad {
                NavigationStack {
                    SquadChatView(
                        squad: squad,
                        roster: state.roster,
                        initialMessages: messages,
                        currentUserId: currentUserId,
                        onMessagesChanged: { updated in
                            messages = updated
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showChallengeCreate) {
            if let squad = state.currentSquad {
                FriendChallengeCreateSheet(
                    squadId: squad.id,
                    roster: state.roster,
                    onCreated: { challenge in
                        activeChallenges.append(challenge)
                        messages.insert(
                            SquadMessage(
                                id: UUID(),
                                squadId: squad.id,
                                authorUserId: currentUserId,
                                kind: .challengeEvent(.init(
                                    title: "Co-op challenge created",
                                    detail: "\(displayName(for: challenge.challengerId)) invited \(displayName(for: challenge.challengedId))",
                                    challengeId: challenge.id
                                )),
                                reactions: [],
                                createdAt: Date()
                            ),
                            at: 0
                        )
                    }
                )
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
        rebuildMessages()
        await refreshMessages()
    }

    @MainActor
    private func refreshState() async {
        guard let userId = services.auth.currentUserId else { return }
        state = services.squads.state(userId: userId)
        await refreshMemberProfiles()
        await refreshMemberFrameTiers()
        rebuildMessages()
        await refreshMessages()
    }

    @MainActor
    private func refreshChallenges() async {
        if let me = currentUserId {
            activeChallenges = await services.friendChallenge.activeChallenges(userId: me)
        }
    }

    @MainActor
    private func refreshMessages() async {
        guard let squad = state.currentSquad else {
            messages = []
            return
        }
        messages = await SquadMessageService.shared.fetchRecent(
            squadId: squad.id,
            fallbackMessages: messages,
            limit: 80
        )
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

    private func headerCard(squad: Squad) -> some View {
        ZStack(alignment: .topTrailing) {
            SquadConsoleBackground(tint: Color.unbound.accent)

            Image("SquadCrest")
                .resizable()
                .scaledToFit()
                .frame(width: 164, height: 164)
                .opacity(0.13)
                .blendMode(.screen)
                .offset(x: 36, y: -34)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    crestMark(size: 66)

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

                    Text("Crew chat, linked sessions, and weekly heat live here.")
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
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showChat = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("OPEN CHAT")
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.2)
                            Image(systemName: "bubble.left.and.bubble.right.fill")
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

    private func crewStreakBadge(squad: Squad) -> some View {
        let badge = CrewStreakBadgeState(
            squadId: squad.id,
            consecutiveWeeks: squad.squadStreakWeeks,
            weekIsoLast: nil
        )
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 13) {
                badgeMedallion(tier: badge.currentTier, systemImage: "flame.fill", tint: Color.unbound.warnOrange)

                VStack(alignment: .leading, spacing: 5) {
                    sectionHeader("CREW STREAK")
                    Text(badge.currentTier == .none ? "No badge yet" : "Tier \(badge.currentTier.roman)")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(streakProgressCopy(badge))
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text("\(badge.consecutiveWeeks)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.92))
                    .monospacedDigit()
            }

            squadProgressBar(value: badge.progressToNextTier, tint: Color.unbound.warnOrange)
        }
        .padding(16)
        .squadPanel(cornerRadius: 20, tint: Color.unbound.warnOrange)
    }

    private var crewSection: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let presenceMap = Dictionary(uniqueKeysWithValues: state.activeRosterPresence.map { ($0.userId, $0) })
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("CREW")
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
                emptySlab("No active challenges. Start a co-op pair challenge with a crewmate.", icon: "flag.checkered")
            } else {
                VStack(spacing: 10) {
                    ForEach(activeChallenges) { challenge in
                        ChallengeDashboardRow(challenge: challenge, roster: state.roster, currentUserId: currentUserId)
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("RECENT")
                Spacer()
                Button {
                    showChat = true
                } label: {
                    HStack(spacing: 4) {
                        Text("SEE ALL")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.accent)
                }
                .buttonStyle(.plain)
            }

            let recent = messages.prefix(3)
            if recent.isEmpty {
                emptySlab("The crew chat is quiet. Workouts and challenge moments will appear here.", icon: "bubble.left.and.bubble.right.fill")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recent)) { message in
                        SquadMessagePreviewRow(message: message, authorName: displayName(for: message.authorUserId))
                    }
                }
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
            crestMark(size: 82)
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

    private func badgeMedallion(tier: SquadBadgeTier, systemImage: String, tint: Color) -> some View {
        ZStack {
            Circle().fill(tint.opacity(0.14))
            Circle().strokeBorder(tint.opacity(0.48), lineWidth: 1)
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text(tier.roman)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .offset(y: 20)
        }
        .frame(width: 54, height: 54)
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

    private func crestMark(size: CGFloat) -> some View {
        Image("SquadCrest")
            .resizable()
            .scaledToFit()
            .padding(size * 0.15)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.54))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
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

    private func squadProgressBar(value: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(min(max(value, 0), 1)))
                    .shadow(color: tint.opacity(0.34), radius: 8)
            }
        }
        .frame(height: 6)
    }

    private func streakProgressCopy(_ badge: CrewStreakBadgeState) -> String {
        guard let target = badge.nextTierTarget else { return "\(badge.consecutiveWeeks) consecutive weeks. Max tier earned." }
        let remaining = max(0, target - badge.consecutiveWeeks)
        return "\(badge.consecutiveWeeks)/\(target) weeks. \(remaining) to next tier."
    }

    private func accountabilityBadge(for userId: UUID) -> AccountabilityBadgeState {
        AccountabilityBadgeState(userId: userId, clearedCount: state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count)
    }

    private func weeklySessionCount(for userId: UUID) -> Int {
        state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count
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

    private func rebuildMessages() {
        guard let squad = state.currentSquad else {
            messages = []
            return
        }
        let activityMessages = state.recentActivity.map { entry in
            SquadMessage(
                id: entry.id,
                squadId: entry.squadId,
                authorUserId: entry.userId,
                kind: entry.messageKind,
                reactions: [],
                createdAt: entry.createdAt
            )
        }
        let migration = SquadMessage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID(),
            squadId: squad.id,
            authorUserId: nil,
            kind: .system(.init(body: "Squads moved to one crew chat. Active missions, honors, affinity, and squad titles have been reset.")),
            reactions: [],
            createdAt: squad.createdAt.addingTimeInterval(1)
        )
        messages = ([migration] + activityMessages).sorted { $0.createdAt > $1.createdAt }
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
}

private struct SquadConsoleBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surfaceElevated,
                            Color.unbound.surface,
                            Color.unbound.bg.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            SquadSignalLines()
                .stroke(Color.white.opacity(0.035), lineWidth: 1)

            SquadDiagonalAccentShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.30),
                            tint.opacity(0.08),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 218)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct SquadDiagonalAccentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.34, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SquadSignalLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 34
        var x = -rect.height
        while x < rect.width + rect.height {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}

private struct SquadPanelStyle: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.surfaceElevated.opacity(0.92),
                                Color.unbound.surface.opacity(0.86),
                                Color.unbound.bg.opacity(0.64)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                tint.opacity(0.24),
                                Color.unbound.borderSubtle
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

private extension View {
    func squadPanel(cornerRadius: CGFloat = 18, tint: Color = Color.unbound.accent) -> some View {
        modifier(SquadPanelStyle(cornerRadius: cornerRadius, tint: tint))
    }
}

private extension SquadActivityEntry {
    var messageKind: SquadMessage.Kind {
        switch payload {
        case .trialCompleted(let trialName, _):
            return .workout(.init(title: trialName, durationMinutes: nil))
        case .titleUnlocked(let titleId):
            return .pr(.init(title: "Title unlocked", detail: titleId.displayName))
        case .linkedSession(let participantUserIds, let durationMinutes):
            return .workout(.init(title: "\(participantUserIds.count) crewmates trained together", durationMinutes: durationMinutes))
        case .memberJoined(let memberDisplayName):
            return .system(.init(body: "\(memberDisplayName) joined the crew."))
        case .affinityChanged:
            return .system(.init(body: "Crew affinity was retired in the Squads v1 redesign."))
        case .squadStreakExtended(let weeks):
            return .challengeEvent(.init(title: "Crew streak extended", detail: "\(weeks) weeks", challengeId: nil))
        }
    }
}

#Preview {
    NavigationStack {
        SquadDetailView()
            .environmentObject(ServiceContainer.mock)
    }
}
