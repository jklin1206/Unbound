// UNBOUND/Views/Squads/SquadDetailView.swift
import SwiftUI

struct SquadDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @State var state: SquadState = .empty
    @State private var showInviteSheet = false
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
    @State var seasonMissionsCompleted: Int = 0

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

    // MARK: - Tabbed chrome

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
                    metaItem(icon: "person.2.fill", text: "\(state.roster.count)/\(squad.maxSize)")
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
}
