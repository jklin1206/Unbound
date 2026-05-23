// UNBOUND/Views/Squads/SquadDetailView.swift
//
// 11-section squad detail view.
// Sections: Header, Mission, AggregateBuild, Affinity, Streak, Roster,
//           WeeklyHonors, ActivityFeed, SquadTitles, FriendChallenges, Footer.
import SwiftUI

struct SquadDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var state: SquadState = .empty
    @State private var showAffinityPicker = false
    @State private var showInviteSheet = false
    @State private var memberDetailTarget: SquadMember?
    @State private var showLeaveConfirm = false
    @State private var leaveError: String?

    // New sections (Phases 9-14)
    @State private var currentMission: SquadMission? = nil
    @State private var weeklyHonors: [WeeklyHonor] = []
    @State private var activeChallenges: [FriendChallenge] = []
    @State private var showChallengeCreate = false

    private var currentUserId: UUID? {
        services.auth.currentUserId.flatMap(UUID.init)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let squad = state.currentSquad {
                    // 1. Header card
                    headerCard(squad: squad)
                    // 2. Squad Mission card (NEW)
                    if let mission = currentMission {
                        SquadMissionCard(mission: mission)
                    }
                    // 3. Aggregate Build hex
                    aggregateBuildCard
                    // 4. Affinity card
                    affinityCard(squad: squad)
                    // 5. Squad streak row
                    streakRow(squad: squad)
                    // 6. Roster grid
                    rosterGrid
                    // 7. Weekly Honors strip (NEW)
                    WeeklyHonorsStrip(honors: weeklyHonors, roster: state.roster)
                    // 8. Activity feed
                    activityFeedSection
                    // 9. Squad Titles
                    squadTitlesRow
                    // 10. Friend Challenges (NEW)
                    friendChallengesSection
                    // 11. Footer — Leave button
                    footerSection
                } else {
                    emptyStateView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Squad")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAffinityPicker) {
            AffinityPickerSheet(currentAxis: state.currentSquad?.affinityAxis)
        }
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
        .task {
            await loadAll()
        }
        .onDisappear {
            Task { await services.squadPresence.unsubscribeFromSquadPresence() }
        }
        // Core squad state changes
        .onReceive(NotificationCenter.default.publisher(for: .squadStateChanged)) { _ in
            Task { await refreshState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadPresenceChanged)) { _ in
            Task { await refreshState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadActivityRecorded)) { _ in
            Task { await refreshState() }
        }
        // New section refresh triggers
        .onReceive(NotificationCenter.default.publisher(for: .squadMissionCompleted)) { _ in
            Task {
                if let squad = state.currentSquad {
                    currentMission = await services.squadMission.currentMission(squadId: squad.id)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyHonorReceived)) { _ in
            Task {
                if let squad = state.currentSquad {
                    weeklyHonors = await services.squadHonors.currentHonors(squadId: squad.id)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendChallengeExpired)) { _ in
            Task {
                if let me = currentUserId {
                    activeChallenges = await services.friendChallenge.activeChallenges(userId: me)
                }
            }
        }
        .friendChallengeOutcomeToast()
        .confirmationDialog("Leave this squad?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave Squad", role: .destructive) {
                Task { await leaveSquad() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can rejoin later with an invite code.")
        }
    }

    // MARK: - Load helpers

    @MainActor
    private func loadAll() async {
        guard let userId = services.auth.currentUserId else { return }
        await services.squads.loadCurrentSquad(userId: userId)
        state = services.squads.state(userId: userId)
        if let squadId = state.currentSquad?.id {
            await services.squadPresence.subscribeToSquadPresence(squadId: squadId)
            currentMission = await services.squadMission.currentMission(squadId: squadId)
            weeklyHonors = await services.squadHonors.currentHonors(squadId: squadId)
        }
        if let me = currentUserId {
            activeChallenges = await services.friendChallenge.activeChallenges(userId: me)
        }
    }

    @MainActor
    private func refreshState() async {
        guard let userId = services.auth.currentUserId else { return }
        state = services.squads.state(userId: userId)
    }

    // MARK: - Section 1: Header card

    private func headerCard(squad: Squad) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(squad.name)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text("\(state.roster.count) member\(state.roster.count == 1 ? "" : "s")")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    Spacer()
                    if let inviteURL = squad.inviteURL {
                        ShareLink(item: inviteURL) {
                            Label("Invite", systemImage: "person.badge.plus")
                                .font(Font.unbound.bodyMStrong)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(Color.unbound.accent.opacity(0.15))
                                )
                                .foregroundStyle(Color.unbound.accent)
                        }
                    }
                }
                .padding(16)
            )
            .frame(height: 80)
    }

    // MARK: - Section 3: Aggregate Build hex

    private var aggregateBuildCard: some View {
        let hexValues = services.squads.aggregateBuildHexValues(userId: services.auth.currentUserId ?? "")
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                VStack(alignment: .leading, spacing: 12) {
                    Text("AGGREGATE BUILD")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)

                    // TODO(squads-impl, Phase 16+): Replace with real hex chart
                    // component once AttributeProfile per-member snapshots are available.
                    // For now: axis bars showing relative collective strength.
                    VStack(spacing: 8) {
                        ForEach(AttributeKey.allCases, id: \.self) { axis in
                            let value = hexValues[axis] ?? 30
                            let pct = (value - 30) / 50  // 0–1
                            HStack(spacing: 8) {
                                Text(axis.shortCode)
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Color.unbound.textSecondary)
                                    .frame(width: 30, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.unbound.bg)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.unbound.accent.opacity(0.6 + pct * 0.4))
                                            .frame(width: max(8, geo.size.width * pct), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                Text("\(Int(value))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.unbound.textTertiary)
                                    .frame(width: 28, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(16)
            )
    }

    // MARK: - Section 4: Affinity card

    private func affinityCard(squad: Squad) -> some View {
        let isCaptain = currentUserId == squad.captainId

        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AFFINITY")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.textTertiary)
                        if let axis = squad.affinityAxis {
                            Text(axis.displayName)
                                .font(Font.unbound.titleS)
                                .foregroundStyle(Color.unbound.accent)
                            Text(axis.trainsCopy)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                        } else {
                            Text("No affinity set")
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }
                    }
                    Spacer()
                    if isCaptain {
                        Button { showAffinityPicker = true } label: {
                            Text("Edit")
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(Color.unbound.accent.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            )
    }

    // MARK: - Section 5: Squad streak row

    private func streakRow(squad: Squad) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.unbound.warnOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SQUAD STREAK")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text("\(squad.squadStreakWeeks) week\(squad.squadStreakWeeks == 1 ? "" : "s")")
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                    Spacer()
                }
                .padding(14)
            )
            .frame(height: 64)
    }

    // MARK: - Section 6: Roster grid

    private var rosterGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        let presenceMap: [UUID: SquadPresence] = Dictionary(
            uniqueKeysWithValues: state.activeRosterPresence.map { ($0.userId, $0) }
        )
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("CREW")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(state.roster) { member in
                    SquadMemberCard(
                        member: member,
                        presence: presenceMap[member.userId],
                        onTap: { memberDetailTarget = member }
                    )
                }
            }
        }
    }

    // MARK: - Section 8: Activity feed

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ACTIVITY")
            if state.recentActivity.isEmpty {
                Text("No activity yet.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(state.recentActivity.prefix(50)) { entry in
                        ActivityFeedRow(entry: entry, roster: state.roster)
                        if entry.id != state.recentActivity.prefix(50).last?.id {
                            Divider()
                                .overlay(Color.unbound.borderSubtle)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - Section 9: Squad Titles row

    private var squadTitlesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SQUAD TITLES")
            if state.unlockedSquadTitles.isEmpty {
                Text("No titles earned yet. Keep grinding.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(state.unlockedSquadTitles, id: \.self) { titleId in
                            SquadTitleBadge(titleId: titleId)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Section 10: Friend Challenges

    private var friendChallengesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("CHALLENGES")
                Spacer()
                Button {
                    showChallengeCreate = true
                } label: {
                    Label("New challenge", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                .buttonStyle(.plain)
            }

            if activeChallenges.isEmpty {
                Text("No active challenges. Start one with a crewmate.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(activeChallenges) { challenge in
                        FriendChallengeCard(
                            challenge: challenge,
                            currentUserId: currentUserId ?? UUID(),
                            roster: state.roster
                        )
                    }
                }
            }
        }
    }

    // MARK: - Section 11: Footer

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
                Text("Leave Squad")
                    .font(Font.unbound.bodyMStrong)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.alert.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.alert.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundStyle(Color.unbound.alert)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "figure.2")
                .font(.system(size: 40))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("You're not in a squad.")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.unbound.textTertiary)
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

#Preview {
    NavigationStack {
        SquadDetailView()
            .environmentObject(ServiceContainer.mock)
    }
}
