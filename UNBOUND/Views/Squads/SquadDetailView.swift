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
}
