// UNBOUND/Views/Squads/SquadMemberDetailView.swift
//
// A crewmate's profile, rendered to mirror the owner's own Profile screen:
// equipped banner, avatar with frame + selected border, rank plate, featured
// skill/lift, and the build hex. The cosmetic/showcase/hex values come from the
// member's `flair` (fetched via the gated squad_member_flair_for_squad RPC) —
// they're device-local otherwise. Real training stats + workouts come from the
// gated squad_member_workout_logs RPC via the parent. Falls back to local reads
// only for the viewer's own profile before their flair has published.
import SwiftUI

struct SquadMemberDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @ObservedObject private var photoStore = ProfilePhotoStore.shared

    let member: SquadMember
    let roster: [SquadMember]
    /// Logs already fetched by SquadDetailView (RPC-backed for real squads).
    var initialWorkoutLogs: [WorkoutLog] = []
    /// Cross-user cosmetics/showcase/hex, if the member has published them.
    var flair: SquadMemberFlair? = nil

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

    // MARK: - Flair-resolved cosmetics (prefer published flair; local fallback)

    private var resolvedFrameTier: RankTitle {
        flair?.frameTier ?? RankCosmetics.equippedFrameTierReadOnly(userId: profileUserId, currentTier: aggregateTier)
    }
    private var resolvedBorder: ShopProfileBorderID? {
        flair?.borderId ?? ShopInventoryStore.equippedProfileBorder(userId: profileUserId)
    }
    private var resolvedBannerAsset: String? {
        flair?.backdropAssetName ?? RankCosmetics.profileHeaderBannerAsset(for: resolvedFrameTier)
    }
    private var resolvedTint: Color {
        resolvedBorder?.accent ?? aggregateTier.rewardTint
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    heroSection
                    showcaseSection
                    statsSection
                    ProfileBuildCard(profile: attributeProfile)
                    recentWorkoutsSection
                    activeChallengesSection
                }
                .padding(.bottom, 96)
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: profileUserId) { await load() }
    }

    // MARK: - Hero (banner + bordered avatar + rank plate)

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            UnboundBackdropArt(assetName: resolvedBannerAsset, role: .profileBanner, tint: resolvedTint)
                .frame(height: 168)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.unbound.bg.opacity(0.45), location: 0.55),
                            .init(color: Color.unbound.bg, location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            HStack(alignment: .bottom, spacing: 14) {
                CosmeticAvatar(
                    tier: resolvedFrameTier,
                    size: 84,
                    image: photoStore.image(userId: profileUserId),
                    letterFallback: avatarInitial,
                    shopBorder: resolvedBorder
                )
                .shadow(color: resolvedTint.opacity(0.35), radius: 16, y: 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName)
                        .font(Font.unbound.titleM.weight(.bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    RankTitlePlate(tier: aggregateTier, tint: aggregateTier.rewardTint)

                    if let displayHandle {
                        Text(displayHandle)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .padding(.bottom, 4)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
        .overlay(alignment: .topTrailing) {
            if isLoading {
                ProgressView().tint(Color.unbound.textTertiary).padding()
            }
        }
    }

    // MARK: - Showcase (featured skill + lift), from flair

    @ViewBuilder
    private var showcaseSection: some View {
        if let flair {
            HStack(spacing: 10) {
                TrophyShowcaseRow(
                    label: "SKILL",
                    value: flair.showcaseSkillName.uppercased(),
                    systemImage: "sparkles",
                    badgeTier: flair.showcaseSkillTier
                )
                TrophyShowcaseRow(
                    label: "LIFT",
                    value: flair.showcaseLiftName.uppercased(),
                    systemImage: "dumbbell.fill",
                    badgeTier: flair.showcaseLiftTier
                )
            }
            .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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

        // Cosmetics/hex/rank: prefer the member's published flair (cross-user);
        // fall back to local reads for the viewer's own not-yet-published profile.
        if let flair {
            attributeProfile = flair.attributeProfile
            aggregateTier = flair.rankTier
        } else {
            attributeProfile = services.attribute.snapshot(userId: resolvedUserId, asOf: .now)
            aggregateTier = await services.rank.aggregateTier(userId: resolvedUserId)
        }

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
