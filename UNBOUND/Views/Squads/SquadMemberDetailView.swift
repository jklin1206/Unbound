// UNBOUND/Views/Squads/SquadMemberDetailView.swift
import SwiftUI

struct SquadMemberDetailView: View {
    @EnvironmentObject var services: ServiceContainer
    @ObservedObject private var photoStore = ProfilePhotoStore.shared

    let member: SquadMember
    let roster: [SquadMember]

    @State private var userProfile: UserProfile?
    @State private var attributeProfile: AttributeProfile = .empty(userId: "", at: .now)
    @State private var aggregateTier: SkillTier = .initiate
    @State private var memberActivity: [SquadActivityEntry] = []
    @State private var workoutLogs: [WorkoutLog] = []
    @State private var activeChallenges: [FriendChallenge] = []
    @State private var isLoading = true

    private var profileUserId: String {
        if let current = services.auth.currentUserId,
           SquadUserIdentity.uuid(from: current) == member.userId {
            return current
        }
        return member.userId.uuidString
    }

    private var accountabilityBadge: AccountabilityBadgeState {
        AccountabilityBadgeState(userId: member.userId, clearedCount: challengeClears)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            backdrop

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    ProfileBuildCard(profile: attributeProfile)
                    weeklySessionsSection
                    accountabilitySection
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

    private var backdrop: some View {
        LinearGradient(
            colors: [
                aggregateTier.rewardTint.opacity(0.16),
                Color.unbound.bg.opacity(0.20),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 320)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                CosmeticAvatar(
                    tier: RankCosmetics.equippedFrameTier(userId: profileUserId, currentTier: aggregateTier),
                    size: 92,
                    image: photoStore.image(userId: profileUserId),
                    letterFallback: avatarInitial
                )

                Circle()
                    .fill(presenceTint)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.unbound.bg, lineWidth: 2))
                    .offset(x: -8, y: -8)
            }
            .shadow(color: aggregateTier.rewardTint.opacity(0.24), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(displayName.uppercased())
                    .font(.system(size: 25, weight: .black))
                    .tracking(0.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)

                if let handle = displayHandle {
                    Text(handle)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(aggregateTier.rewardTextTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }

                if let titleId = member.equippedTitle {
                    TitleBadge(titleId: titleId, compact: false)
                } else {
                    Text(attributeProfile.buildName.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .memberPanel(tint: aggregateTier.rewardTint, cornerRadius: 22)
        .overlay(alignment: .topTrailing) {
            if isLoading {
                ProgressView()
                    .tint(Color.unbound.accent)
                    .padding(16)
            }
        }
    }

    private var weeklySessionsSection: some View {
        HStack(spacing: 12) {
            metricBlock(value: "\(weeklySessionCount)", label: "THIS WEEK", tint: Color.unbound.accent)
            metricBlock(value: "\(workoutLogs.count)", label: "LOGS", tint: aggregateTier.rewardTint)
            metricBlock(value: aggregateTier.displayName.uppercased(), label: "TIER", tint: aggregateTier.rewardTint)
        }
    }

    private var accountabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.unbound.accent.opacity(0.16))
                    Circle().strokeBorder(Color.unbound.accent.opacity(0.42), lineWidth: 1)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text(accountabilityBadge.currentTier.roman)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .offset(y: 20)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader("ACCOUNTABILITY")
                    Text(accountabilityBadge.currentTier == .none ? "No badge yet" : "Tier \(accountabilityBadge.currentTier.roman)")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(accountabilityCopy)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            progressBar(value: accountabilityBadge.progressToNextTier, tint: Color.unbound.accent)
        }
        .padding(15)
        .memberPanel(tint: Color.unbound.accent, cornerRadius: 20)
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("LAST WORKOUTS")
            if isLoading {
                loadingRow
            } else if !recentWorkoutRows.isEmpty {
                VStack(spacing: 8) {
                    ForEach(recentWorkoutRows) { row in
                        workoutRow(row)
                    }
                }
            } else {
                emptyRow("No recent workouts yet.", icon: "figure.strengthtraining.traditional")
            }
        }
    }

    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("CURRENTLY IN")
            if activeChallenges.isEmpty {
                emptyRow("No active challenge participation.", icon: "flag.checkered")
            } else {
                VStack(spacing: 8) {
                    ForEach(activeChallenges) { challenge in
                        challengeRow(challenge)
                    }
                }
            }
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView().tint(Color.unbound.accent)
            Text("Loading profile data")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .memberPanel(tint: Color.unbound.textTertiary, cornerRadius: 18)
    }

    private func metricBlock(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.54)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .memberPanel(tint: tint, cornerRadius: 16)
    }

    private func workoutRow(_ row: WorkoutProfileRow) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: row.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(row.tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(row.tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(row.subtitle)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .memberPanel(tint: row.tint, cornerRadius: 18)
    }

    private func challengeRow(_ challenge: FriendChallenge) -> some View {
        HStack(spacing: 11) {
            Image(systemName: challenge.isPending ? "hourglass" : "flag.checkered")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(challenge.isPending ? Color.unbound.warnOrange : Color.unbound.accent)
                .frame(width: 30, height: 30)
                .background(Circle().fill((challenge.isPending ? Color.unbound.warnOrange : Color.unbound.accent).opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.kind.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Text(challengeOpponentCopy(challenge))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .memberPanel(tint: challenge.isPending ? Color.unbound.warnOrange : Color.unbound.accent, cornerRadius: 18)
    }

    private func emptyRow(_ copy: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.78)))
            Text(copy)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .memberPanel(tint: Color.unbound.textTertiary, cornerRadius: 18)
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

    private func progressBar(value: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(min(max(value, 0), 1)))
                    .shadow(color: tint.opacity(0.32), radius: 8)
            }
        }
        .frame(height: 6)
    }

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

    private var presenceTint: Color {
        activeChallenges.isEmpty ? Color.unbound.textTertiary : Color.unbound.accent
    }

    private var weeklySessionCount: Int {
        let interval = currentWeekInterval
        let logged = workoutLogs.filter { log in
            interval.contains(log.completedAt ?? log.startedAt)
        }.count
        let activity = memberActivity.filter { entry in
            entry.kind == .trialCompleted && interval.contains(entry.createdAt)
        }.count
        return max(logged, activity)
    }

    private var challengeClears: Int {
        activeChallenges.filter { $0.winnerUserId == member.userId }.count
    }

    private var recentWorkoutRows: [WorkoutProfileRow] {
        let logRows = workoutLogs.prefix(3).map { log in
            WorkoutProfileRow(
                id: log.id,
                title: log.plannedWorkoutName,
                subtitle: profileDateString(log.completedAt ?? log.startedAt),
                icon: "figure.strengthtraining.traditional",
                tint: Color.unbound.accent
            )
        }
        if !logRows.isEmpty { return Array(logRows) }

        return memberActivity
            .filter { $0.kind == .trialCompleted }
            .prefix(3)
            .map { entry in
                WorkoutProfileRow(
                    id: entry.id.uuidString,
                    title: workoutTitle(for: entry),
                    subtitle: profileDateString(entry.createdAt),
                    icon: "seal.fill",
                    tint: Color.unbound.warnOrange
                )
            }
    }

    private var accountabilityCopy: String {
        guard let target = accountabilityBadge.nextTierTarget else {
            return "\(accountabilityBadge.clearedCount) clears. Max tier earned."
        }
        return "\(accountabilityBadge.clearedCount)/\(target) clears to next tier."
    }

    private var currentWeekInterval: DateInterval {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), duration: 7 * 24 * 60 * 60)
    }

    private func profileDateString(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func workoutTitle(for entry: SquadActivityEntry) -> String {
        if case .trialCompleted(let trialName, _) = entry.payload {
            return trialName
        }
        return "Workout"
    }

    private func challengeOpponentCopy(_ challenge: FriendChallenge) -> String {
        let otherId = challenge.challengerId == member.userId ? challenge.challengedId : challenge.challengerId
        let name = roster.first(where: { $0.userId == otherId })?.displayName ?? "Crewmate"
        return challenge.isPending ? "Pending with \(name)" : "Active with \(name)"
    }

    @MainActor
    private func load() async {
        isLoading = true
        let resolvedUserId = profileUserId

        userProfile = try? await services.user.fetchProfile(userId: resolvedUserId)
        attributeProfile = services.attribute.snapshot(userId: resolvedUserId, asOf: .now)
        aggregateTier = await services.rank.aggregateTier(userId: resolvedUserId)
        workoutLogs = await fetchWorkoutLogs(userId: resolvedUserId)
        activeChallenges = await services.friendChallenge.activeChallenges(userId: member.userId)

        if let viewerId = services.auth.currentUserId {
            let all = (try? await services.squadActivity.fetchRecent(userId: viewerId)) ?? []
            memberActivity = all.filter { $0.userId == member.userId }
        } else {
            memberActivity = []
        }

        isLoading = false
    }

    @MainActor
    private func fetchWorkoutLogs(userId: String) async -> [WorkoutLog] {
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

private struct WorkoutProfileRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
}

private struct SquadMemberPanelStyle: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.10),
                                Color.unbound.surface.opacity(0.90),
                                Color.unbound.bg.opacity(0.62)
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
                                tint.opacity(0.25),
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
    func memberPanel(tint: Color, cornerRadius: CGFloat) -> some View {
        modifier(SquadMemberPanelStyle(tint: tint, cornerRadius: cornerRadius))
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
