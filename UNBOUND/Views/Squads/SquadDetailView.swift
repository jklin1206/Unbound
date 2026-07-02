// UNBOUND/Views/Squads/SquadDetailView.swift
//
// The squad home: flat calm-list container with a compact identity header
// and three underline tabs (Crew / Mission / Season). All content sits
// directly on the page background — the tabs' own files decide which single
// object earns a raised surface.
import SwiftUI

struct SquadDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @State var state: SquadState = .empty
    @State private var showInviteSheet = false
    @State var memberDetailTarget: SquadMember?
    @State var showLeaveConfirm = false
    @State var showLogoEditor = false
    @State var showAffinityPicker = false
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
    @State var weeklyHonors: [WeeklyHonor] = []
    @State var showMissionPick = false
    @State var celebratedMission: SquadMission?
    @State var seasonMissionsCompleted: Int = 0

    enum SquadTab: String, CaseIterable {
        case crew
        case mission
        case season

        var title: String {
            switch self {
            case .crew: return "Crew"
            case .mission: return "Mission"
            case .season: return "Season"
            }
        }
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

            if let squad = state.currentSquad {
                VStack(spacing: 0) {
                    compactHeader(squad: squad)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    UnderlineTabBar(
                        tabs: SquadTab.allCases,
                        title: \.title,
                        selection: $selectedTab
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            switch selectedTab {
                            case .crew: crewTabContent(squad: squad)
                            case .mission: challengesTabContent
                            case .season: seasonTabContent(squad: squad)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
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
                SquadMemberDetailView(
                    member: member,
                    roster: state.roster,
                    initialWorkoutLogs: memberWorkoutLogs[member.userId] ?? []
                )
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
        .sheet(isPresented: $showAffinityPicker) {
            if let squad = state.currentSquad {
                AffinityPickerSheet(initialAxis: squad.affinityAxis) { axis in
                    Task { await setSquadAffinity(axis) }
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
        .onReceive(NotificationCenter.default.publisher(for: .friendChallengeDeclined)) { _ in
            Task { await refreshChallenges() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendChallengeAccepted)) { _ in
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

    // MARK: - Header

    private func compactHeader(squad: Squad) -> some View {
        HStack(spacing: 12) {
            editableCrestMark(squad: squad, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(squad.name)
                    .font(Font.unbound.titleM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                MetaLine([
                    "\(state.roster.count)/\(squad.maxSize) crew",
                    squad.squadStreakWeeks > 0 ? "\(squad.squadStreakWeeks)-wk streak" : nil,
                    currentSeason.title
                ])
            }

            Spacer(minLength: 0)

            if let inviteURL = squad.inviteURL {
                ShareLink(item: inviteURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Share invite link")
            }

            Menu {
                if canEditSquad(squad) {
                    Button {
                        showLogoEditor = true
                    } label: {
                        Label("Change Crest", systemImage: "shield.lefthalf.filled")
                    }
                    Button {
                        showAffinityPicker = true
                    } label: {
                        Label("Squad Affinity", systemImage: "scope")
                    }
                }
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label("Leave Squad", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Squad options")
        }
    }
}
