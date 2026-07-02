// UNBOUND/Views/Squads/SquadMemberDetailView.swift
//
// A crewmate's profile: identity, build, real training stats, recent
// workouts, and current challenges — flat calm sections, mono numbers,
// no tinted panels. Workout logs come from the parent (fetched via the
// gated squad_member_workout_logs RPC for real squads); the view only
// falls back to the local store for the viewer's own profile.
import SwiftUI

struct SquadMemberDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @ObservedObject private var photoStore = ProfilePhotoStore.shared

    let member: SquadMember
    let roster: [SquadMember]
    /// Logs already fetched by SquadDetailView (RPC-backed for real squads).
    var initialWorkoutLogs: [WorkoutLog] = []

    @State private var userProfile: UserProfile?
    @State private var attributeProfile: AttributeProfile = .empty(userId: "", at: .now)
    @State private var aggregateTier: SkillTier = .initiate
    @State private var workoutLogs: [WorkoutLog] = []
    @State private var activeChallenges: [FriendChallenge] = []
    @State private var sessionXPRecord: SessionXPRecord?
    @State private var challengeStats: FriendChallengeStats = .empty
    @State private var isLoading = true

    private var profileUserId: String {
        if let current = services.auth.currentUserId,
           SquadUserIdentity.uuid(from: current) == member.userId {
            return current
        }
        return member.userId.uuidString
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    heroSection
                    statsSection
                    ProfileBuildCard(profile: attributeProfile)
                    recentWorkoutsSection
                    activeChallengesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: profileUserId) { await load() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 16) {
            CosmeticAvatar(
                tier: RankCosmetics.equippedFrameTier(userId: profileUserId, currentTier: aggregateTier),
                size: 84,
                image: photoStore.image(userId: profileUserId),
                letterFallback: avatarInitial
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(Font.unbound.titleM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                MetaLine([
                    displayHandle,
                    aggregateTier.displayName,
                    "joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))"
                ])

                if let titleId = member.equippedTitle {
                    TitleBadge(titleId: titleId, compact: true)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            if isLoading {
                ProgressView()
                    .tint(Color.unbound.textTertiary)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(alignment: .top, spacing: 0) {
            statColumn(value: "\(weeklySessionCount)", label: "this wk")
            statColumn(value: "\(streakSummary.current)", label: "streak")
            statColumn(value: "\(streakSummary.best)", label: "best")
            statColumn(value: "\(challengeStats.seasonWins)", label: "wins")
            statColumn(value: "\(streakSummary.totalSessions)", label: "sessions")
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Font.unbound.monoM)
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent workouts

    private var recentWorkoutsSection: some View {
        SquadSectionCard(
            title: "LAST WORKOUTS",
            icon: "figure.strengthtraining.traditional",
            tint: Color.unbound.success
        ) {
            if isLoading && workoutLogs.isEmpty {
                Text("Loading…")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 6)
            } else if workoutLogs.isEmpty {
                Text("No recent workouts yet.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(workoutLogs.prefix(5), id: \.id) { log in
                    workoutRow(log)
                }
            }
        }
    }

    private func workoutRow(_ log: WorkoutLog) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.plannedWorkoutName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                MetaLine([
                    (log.completedAt ?? log.startedAt).formatted(date: .abbreviated, time: .omitted),
                    loggedExerciseCount(log) > 0 ? "\(loggedExerciseCount(log)) exercises" : nil,
                    log.durationMinutes.map { "\($0)m" }
                ])
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private func loggedExerciseCount(_ log: WorkoutLog) -> Int {
        log.exerciseEntries.filter { !$0.skipped }.count
    }

    // MARK: - Challenges

    private var activeChallengesSection: some View {
        SquadSectionCard(
            title: "CHALLENGES",
            icon: "bolt.fill",
            tint: Color.unbound.warnOrange
        ) {
            if activeChallenges.isEmpty {
                Text("Not in any challenges right now.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(activeChallenges) { challenge in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.kind.displayName)
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                            MetaLine([challengeOpponentCopy(challenge)])
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                }
            }
        }
    }

    // MARK: - Derived

    private var displayName: String {
        if let name = userProfile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let handle = userProfile?.displayHandle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !handle.isEmpty {
            return handle.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        }
        if isCurrentMember, ["Captain", "You"].contains(member.displayName) {
            return "You"
        }
        return member.displayName
    }

    private var displayHandle: String? {
        guard let handle = userProfile?.displayHandle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !handle.isEmpty
        else { return nil }
        return "@\(handle.trimmingCharacters(in: CharacterSet(charactersIn: "@")))"
    }

    private var avatarInitial: String {
        displayName.first.map { String($0).uppercased() } ?? "U"
    }

    private var isCurrentMember: Bool {
        guard let current = services.auth.currentUserId else { return false }
        return SquadUserIdentity.uuid(from: current) == member.userId
    }

    private var weeklySessionCount: Int {
        streakSummary.weeklyCount
    }

    private var streakSummary: SquadStreakSummary {
        SquadLeaderboardBuilder.streakSummary(logs: workoutLogs, xpRecord: sessionXPRecord)
    }

    private func challengeOpponentCopy(_ challenge: FriendChallenge) -> String {
        let otherId = challenge.challengerId == member.userId ? challenge.challengedId : challenge.challengerId
        let name = roster.first(where: { $0.userId == otherId })?.displayName ?? "Crewmate"
        return challenge.isPending ? "Pending with \(name)" : "Active with \(name)"
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        isLoading = true
        let resolvedUserId = profileUserId

        // Squadmates' logs come from the parent (RPC-backed). Only the
        // viewer's own profile reads the richer local store directly.
        if isCurrentMember {
            let local = await fetchLocalWorkoutLogs(userId: resolvedUserId)
            workoutLogs = local.isEmpty ? initialWorkoutLogs : local
        } else {
            workoutLogs = initialWorkoutLogs
        }

        userProfile = try? await services.user.fetchProfile(userId: resolvedUserId)
        attributeProfile = services.attribute.snapshot(userId: resolvedUserId, asOf: .now)
        aggregateTier = await services.rank.aggregateTier(userId: resolvedUserId)
        activeChallenges = await services.friendChallenge.activeChallenges(userId: member.userId)
        sessionXPRecord = services.sessionXP.record(userId: resolvedUserId)
        let statsByMember = await services.friendChallenge.challengeStats(squadId: member.squadId)
        challengeStats = statsByMember[member.userId] ?? .empty

        isLoading = false
    }

    @MainActor
    private func fetchLocalWorkoutLogs(userId: String) async -> [WorkoutLog] {
        (try? await services.database.query(
            collection: "workoutLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "startedAt",
            descending: true,
            limit: 20
        )) ?? []
    }
}

#Preview {
    NavigationStack {
        SquadMemberDetailView(
            member: SquadMember(
                id: UUID(),
                squadId: UUID(),
                userId: UUID(),
                joinedAt: Date(),
                displayName: "Justin Lin",
                equippedTitle: nil,
                buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
            ),
            roster: []
        )
        .environmentObject(ServiceContainer.mock)
    }
}
