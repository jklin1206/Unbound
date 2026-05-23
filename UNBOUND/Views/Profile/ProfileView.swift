import SwiftUI
import PhotosUI

// MARK: - ProfileView
//
// The ARCHIVE counterpart to Home. Home is LIVE (what's happening today);
// Profile is identity, lifetime state, collection, and settings. Per the
// `project_unbound_home_vs_profile_boundary` memory:
//
//   Home  — today's mission, live rank, live streak, today's stats
//   Profile — who you've become: avatar, rank journey, badges grid,
//             photo library, stats history, settings
//
// This first-pass profile surfaces what we already compute on home at
// rest (rank, stats, badges, body map) and nests the existing
// SettingsView as a push destination for account/preferences.
//
// Deferred to future passes:
//   - Real scan photo library (grid of ProgressPhoto)
//   - Stats history charts (weekly/monthly trend)
//   - Rank journey timeline (when you crossed D → C → B)
//   - Titles collection (separate from badges, per rank memory)

struct ProfileView: View {
    @EnvironmentObject var services: ServiceContainer

    @State private var profile: UserProfile?
    @State private var aggregateRank: SubRank = .eMinus
    @State private var aggregateTier: SkillTier = .initiate
    @State private var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)
    @State private var unlockedBadges: [Badge] = []
    @State private var totalBadgeCount: Int = 0
    @State private var totalWorkouts: Int = 0
    @State private var bestSkillName: String = "None yet"
    @State private var bestSkillTier: SkillTier = .initiate
    @State private var bestLiftName: String = "None yet"
    @State private var bestLiftTier: SkillTier = .initiate
    @State private var equippedFrameTier: RankTitle = .initiate
    @State private var equippedBackgroundTier: RankTitle = .initiate
    @State private var equippedProfileColorTier: RankTitle = .initiate
    @State private var sessionXP: SessionXPRecord?
    @State private var manualPhotoCount: Int = 0
    @State private var scanPhotoCount: Int = 0
    @State private var beforePhoto: ProgressPhoto?
    @State private var afterPhoto: ProgressPhoto?
    @State private var isLoading = true
    @State private var trialsState: TrialsState = .empty
    @State private var overallRankTrialReadiness: OverallRankTrialReadiness?
    @State private var activeOverallRankTrialDraft: TrainingSessionDraft?

    @ObservedObject private var photoStore = ProfilePhotoStore.shared
    @State private var showPhotoOptions = false
    @State private var showEditProfile = false
    @State private var showRankInfo = false
    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem?
    private var photoUserId: String { services.auth.currentUserId ?? "" }

    @AppStorage("unbound.gains") private var gains: Int = 0
    private let xpPerLevel: Int = 250

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()

            // Rank-tier cosmetic backdrop behind the header.
            CosmeticBackdrop(tier: equippedBackgroundTier, colorTier: equippedProfileColorTier, maxHeight: 360)
                .ignoresSafeArea(edges: .top)

            if isLoading {
                ProgressView().tint(Color.unbound.accent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        trophyHeader
                        ProfileBuildCard(profile: attributeProfile)
                        if let overallRankTrialReadiness {
                            OverallRankTrialReadinessCard(readiness: overallRankTrialReadiness) { definition in
                                startOverallRankTrial(definition)
                            }
                        }
                        if let beforePhoto, let afterPhoto {
                            ProgressJourneyCard(dayZero: beforePhoto, now: afterPhoto)
                        }
                        PhotoCalendarView().environmentObject(services)
                        ProfileTrialHistorySection(trialsState: trialsState)
                            .padding(.horizontal, 0)
                        badgesCard
                        settingsLink
                        Spacer().frame(height: 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarHidden(true)
        .task { await load() }
        .confirmationDialog("Profile picture",
                            isPresented: $showPhotoOptions,
                            titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            PhotosPicker("Choose from Library",
                         selection: $pickedItem, matching: .images)
            if photoStore.image(userId: photoUserId) != nil {
                Button("Remove Photo", role: .destructive) {
                    photoStore.remove(userId: photoUserId)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(
                displayName: profile?.displayName ?? "",
                displayHandle: profile?.displayHandle ?? "",
                save: saveProfileIdentity
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRankInfo) {
            RankInfoSheet(currentTier: aggregateTier)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                photoStore.set(image, userId: photoUserId)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $activeOverallRankTrialDraft, onDismiss: {
            Task { await load() }
        }) { draft in
            WorkoutReadyView(draft: draft)
                .environmentObject(services)
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    photoStore.set(img, userId: photoUserId)
                }
                pickedItem = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { _ in
            if let userId = services.auth.currentUserId {
                Task {
                    attributeProfile = services.attribute.profile(userId: userId)
                }
            }
        }
        .attributeRankUpToast()
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        services.badges.bind(userId: userId)

        do {
            profile = try await services.user.fetchProfile(userId: userId)
        } catch {
            profile = nil
        }

        aggregateRank = await services.rank.aggregateRank(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
        _ = RankCosmetics.unlockedTiers(userId: userId, currentTier: aggregateTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: aggregateTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: aggregateTier)
        equippedProfileColorTier = RankCosmetics.equippedProfileColorTier(userId: userId, currentTier: aggregateTier)
        attributeProfile = services.attribute.profile(userId: userId)

        unlockedBadges = services.badges.unlockedBadges(userId: userId)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        totalBadgeCount = BadgeCatalog.all.count
        sessionXP = services.sessionXP.record(userId: userId)

        let photos: [ProgressPhoto] = (try? await services.database.query(
            collection: "progressPhotos",
            field: "userId",
            isEqualTo: userId,
            orderBy: "capturedAt",
            descending: true,
            limit: 500
        )) ?? []
        manualPhotoCount = photos.filter { $0.source == .manual }.count
        scanPhotoCount = photos.filter { $0.source == .scan }.count
        let orderedPhotos = photos.sorted { $0.capturedAt < $1.capturedAt }
        beforePhoto = orderedPhotos.first
        afterPhoto = orderedPhotos.last

        let workoutLogs: [WorkoutLog] = (try? await services.database.query(
            collection: "workoutLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "startedAt",
            descending: true,
            limit: nil
        )) ?? []
        totalWorkouts = max(workoutLogs.count, sessionXP?.totalSessions ?? 0)
        resolveBestSkillAndLift(userId: userId, workoutLogs: workoutLogs)

        // Load trials state
        trialsState = services.trials.state(userId: userId)
        overallRankTrialReadiness = await TrialReadinessService.shared.readiness(userId: userId, services: services)

        isLoading = false
    }

    private func startOverallRankTrial(_ definition: OverallRankTrialDefinition) {
        let userId = services.auth.currentUserId ?? "anonymous"
        activeOverallRankTrialDraft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: userId
        )
    }

    @MainActor
    private func saveProfileIdentity(displayName: String, displayHandle: String) async throws {
        let userId = services.auth.currentUserId ?? "anonymous"
        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedHandle = displayHandle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))

        try await services.user.updateProfile(
            userId: userId,
            fields: [
                "displayName": cleanedName.isEmpty ? NSNull() : cleanedName,
                "displayHandle": cleanedHandle.isEmpty ? NSNull() : cleanedHandle
            ]
        )

        if var profile {
            profile.displayName = cleanedName.isEmpty ? nil : cleanedName
            profile.displayHandle = cleanedHandle.isEmpty ? nil : cleanedHandle
            self.profile = profile
        }
    }

    // MARK: - Header card

    private var trophyHeader: some View {
        let level = (gains / xpPerLevel) + 1
        let levelProgress = Double(gains % xpPerLevel) / Double(xpPerLevel)
        let currentXP = gains % xpPerLevel
        let rankColor = aggregateTier.rewardTint
        let rankTextColor = aggregateTier.rewardTextTint
        let profileColor = equippedProfileColorTier.rewardTint
        let profileGlowColors = equippedProfileColorTier.rewardGlowColors

        return VStack(alignment: .leading, spacing: 18) {
            profileTopBar

            HStack(alignment: .center, spacing: 12) {
                heroAvatar(level: level, tint: rankColor)
                identityStack(
                    level: level,
                    currentXP: currentXP,
                    levelProgress: levelProgress,
                    rankColor: rankColor,
                    rankTextColor: rankTextColor
                )
            }

            LazyVGrid(columns: profileMetricColumns, spacing: 8) {
                TrophyMetricTile(
                    label: "STREAK",
                    value: "\(sessionXP?.longestStreak ?? 0)D",
                    tint: Color.unbound.ember,
                    systemImage: "flame.fill"
                )
                TrophyMetricTile(
                    label: "SESSIONS",
                    value: "\(totalWorkouts)",
                    tint: Color.unbound.coachCyan,
                    systemImage: "bolt.fill"
                )
                TrophyMetricTile(
                    label: "BEST SKILL",
                    value: bestSkillName.uppercased(),
                    tint: Color.unbound.textSecondary,
                    systemImage: "sparkles",
                    badgeTier: bestSkillTier
                )
                TrophyMetricTile(
                    label: "BEST LIFT",
                    value: bestLiftName.uppercased(),
                    tint: Color.unbound.textSecondary,
                    systemImage: "dumbbell.fill",
                    badgeTier: bestLiftTier
                )
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.62))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.64))
                if let asset = RankCosmetics.profileBackgroundAsset(for: equippedBackgroundTier),
                   let ui = UIImage(named: asset) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .clipped()
                        .saturation(1.08)
                        .contrast(1.04)
                        .opacity(0.22)
                        .blendMode(.screen)
                }
                RadialGradient(
                    colors: profileGlowColors.map { $0.opacity(0.22) } + [.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                DossierLinework(color: profileColor)
                    .opacity(0.28)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: profileGlowColors.map { $0.opacity(0.70) } + [Color.unbound.borderSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: profileColor.opacity(0.18), radius: 18, y: 10)
    }

    private var profileTopBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UNBOUND")
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.impact)
                Text("PROFILE")
                    .font(Font.unbound.titleM)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            Spacer()
            NavigationLink(destination: SettingsView(services: services)) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.bg.opacity(0.78)))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func heroAvatar(level: Int, tint: Color) -> some View {
        Button {
            showPhotoOptions = true
        } label: {
            ProfileHeroAvatar(
                cosmeticTier: equippedFrameTier,
                profileColorTier: equippedProfileColorTier,
                skillTier: aggregateTier,
                level: level,
                tint: tint,
                image: photoStore.image(userId: photoUserId),
                letterFallback: avatarInitial
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile picture. Tap to change.")
    }

    private var profileMetricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6)
        ]
    }

    private func identityStack(
        level: Int,
        currentXP: Int,
        levelProgress: Double,
        rankColor: Color,
        rankTextColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showEditProfile = true
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(displayName.uppercased())
                            .font(.system(size: 22, weight: .black))
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.56)
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                    }

                    Text(playerHandle)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(rankTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                        .truncationMode(.tail)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile name and handle")

            Button {
                showRankInfo = true
            } label: {
                RankTitlePlate(tier: aggregateTier, tint: rankColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current tier details")
            .frame(maxWidth: .infinity)

            LevelProgressPlate(
                currentXP: currentXP,
                xpPerLevel: xpPerLevel,
                progress: levelProgress,
                tint: rankColor,
                detail: "XP"
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var displayName: String {
        if let name = profile?.displayName, !name.isEmpty { return name }
        return "UNBOUND"
    }

    private var avatarInitial: String {
        if let name = profile?.displayName, let first = name.first {
            return String(first).uppercased()
        }
        return "U"
    }

    private var playerHandle: String {
        if let handle = profile?.displayHandle, !handle.isEmpty {
            return "@\(handle.uppercased())"
        }
        if let name = profile?.displayName, !name.isEmpty {
            return "@\(name.replacingOccurrences(of: " ", with: "").uppercased())"
        }
        return "@PLAYER"
    }

    private func resolveBestSkillAndLift(userId: String, workoutLogs: [WorkoutLog]) {
        let skillTiers = UserSkillTierStore.shared.load(userId: userId).perSkill
        let nodeStates = SkillProgressService.shared.nodeStates
        let clearedSkills = SkillGraph.shared.nodes.compactMap { node -> (node: SkillNode, state: NodeState)? in
            guard let state = nodeStates[node.id], state == .achieved || state == .mastered else { return nil }
            return (node, state)
        }

        if let bestSkill = clearedSkills.max(by: { lhs, rhs in
            if lhs.node.rank != rhs.node.rank {
                return lhs.node.rank.difficultyOrder < rhs.node.rank.difficultyOrder
            }
            if lhs.node.tier != rhs.node.tier {
                return lhs.node.tier < rhs.node.tier
            }
            return Self.masteryOrder(lhs.state) < Self.masteryOrder(rhs.state)
        }) {
            bestSkillName = bestSkill.node.title
            bestSkillTier = skillTiers[bestSkill.node.id] ?? .initiate
        } else {
            bestSkillName = "None yet"
            bestSkillTier = .initiate
        }

        let liftCandidates = Self.profileLiftNames.map { lift -> (key: String, name: String, tier: SkillTier, pr: LiftPR?) in
            let pr = Self.bestLiftPR(lift: lift, logs: workoutLogs)
            let tier = Self.liftTier(for: lift, weightKg: pr?.weightKg ?? 0)
            return (lift, Self.displayLiftName(lift), tier, pr)
        }

        if let bestLift = liftCandidates.max(by: { lhs, rhs in
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            return (lhs.pr?.weightKg ?? 0) < (rhs.pr?.weightKg ?? 0)
        }), bestLift.pr != nil {
            bestLiftName = bestLift.name
            bestLiftTier = bestLift.tier
        } else {
            bestLiftName = "None yet"
            bestLiftTier = .initiate
        }
    }

    private static let profileLiftNames = [
        "bench press",
        "back squat",
        "deadlift",
        "overhead press"
    ]

    private static func displayLiftName(_ lift: String) -> String {
        lift.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private struct LiftPR {
        let weightKg: Double
        let reps: Int
    }

    private static func bestLiftPR(lift: String, logs: [WorkoutLog]) -> LiftPR? {
        let normalized = lift.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let sets = logs
            .flatMap(\.exerciseEntries)
            .filter { $0.exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }

        return sets.compactMap { set -> LiftPR? in
            guard let weight = set.weightKg, weight > 0 else { return nil }
            return LiftPR(weightKg: weight, reps: set.reps)
        }
        .max { lhs, rhs in
            if lhs.weightKg != rhs.weightKg { return lhs.weightKg < rhs.weightKg }
            return lhs.reps < rhs.reps
        }
    }

    private static func liftTier(for lift: String, weightKg: Double) -> SkillTier {
        guard let criteria = LiftTierCriteria.table[lift] else { return .initiate }
        return SkillTier.allCases.reversed().first { tier in
            guard case .weightKg(let target)? = criteria[tier] else { return false }
            return weightKg >= target
        } ?? .initiate
    }

    private static func masteryOrder(_ state: NodeState) -> Int {
        state == .mastered ? 1 : 0
    }

    private func rankTitle(for tier: SkillTier) -> RankTitle {
        tier.rankTitle
    }

    // MARK: - Badges card

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BADGES")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("\(unlockedBadges.count) / \(totalBadgeCount) UNLOCKED")
                        .font(Font.unbound.titleS)
                        .tracking(0.7)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }
                Spacer()
                NavigationLink(destination: BadgeGalleryView().environmentObject(services)) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.unbound.bg.opacity(0.75)))
                        .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if unlockedBadges.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "seal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Earn your first badge by logging a session.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(unlockedBadges.prefix(10))) { b in
                            badgeTile(b)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func badgeTile(_ badge: Badge) -> some View {
        VStack(spacing: 6) {
            BadgeEmblemView(badge: badge, size: 58, isUnlocked: true)
            Text(badge.displayName.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 68)
    }

    // MARK: - Settings link

    private var settingsLink: some View {
        NavigationLink(destination: SettingsView(services: services)) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("SETTINGS")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }

}

private struct EditProfileSheet: View {
    @State private var name: String
    @State private var handle: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    @Environment(\.dismiss) private var dismiss

    let save: (String, String) async throws -> Void

    init(
        displayName: String,
        displayHandle: String,
        save: @escaping (String, String) async throws -> Void
    ) {
        _name = State(initialValue: displayName)
        _handle = State(initialValue: displayHandle)
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EDIT PROFILE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Identity")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                profileField(label: "NAME", text: $name, prompt: "Display name")
                profileField(label: "HANDLE", text: $handle, prompt: "@handle")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.alert)
            }

            Button {
                Task { await saveTapped() }
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView().tint(Color.unbound.textPrimary)
                    } else {
                        Text("SAVE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.6)
                    }
                    Spacer()
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.unbound.bg)
    }

    private func profileField(label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            TextField(prompt, text: text)
                .textInputAutocapitalization(label == "HANDLE" ? .never : .words)
                .autocorrectionDisabled(label == "HANDLE")
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
    }

    private func saveTapped() async {
        isSaving = true
        errorMessage = nil
        do {
            try await save(name, handle)
            dismiss()
        } catch {
            errorMessage = "Could not save profile."
        }
        isSaving = false
    }
}

private struct RankInfoSheet: View {
    let currentTier: SkillTier

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT TIER")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(currentTier.displayName)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                RankInfoRow(
                    icon: "shield.fill",
                    tint: Color.unbound.accent,
                    title: "What this is",
                    copy: "Your profile tier is the highest named tier you have reached across tracked skills and key strength lifts. It is separate from account level and LV XP."
                )
                RankInfoRow(
                    icon: "arrow.up.forward",
                    tint: Color.unbound.rankGold,
                    title: "How it unlocks",
                    copy: "After you log a workout, UNBOUND checks your full training history against each skill's tier standard: reps, holds, load, bodyweight ratios, and movement requirements."
                )
                RankInfoRow(
                    icon: "clock.arrow.circlepath",
                    tint: Color.unbound.coachCyan,
                    title: "Current vs previous",
                    copy: "Current tier is what your profile shows now. Previous tier only appears during a rank-up moment, as the tier you moved from before the new unlock."
                )
            }

            Text("Main tracked lift tiers currently include bench press, back squat, deadlift, and overhead press. Skill tiers come from the skill graph criteria.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.unbound.bg)
    }
}

private struct RankInfoRow: View {
    let icon: String
    let tint: Color
    let title: String
    let copy: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.14)))
                .overlay(Circle().strokeBorder(tint.opacity(0.34), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(copy)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

private struct ProfileHeroAvatar: View {
    let cosmeticTier: RankTitle
    let profileColorTier: RankTitle
    let skillTier: SkillTier
    let level: Int
    let tint: Color
    let image: UIImage?
    let letterFallback: String

    var body: some View {
        let profileTint = profileColorTier.rewardTint

        ZStack {
            Circle()
                .fill(profileTint.opacity(0.14))
                .frame(width: 190, height: 190)
                .blur(radius: 26)

            CosmeticAvatar(
                tier: cosmeticTier,
                size: 176,
                image: image,
                letterFallback: letterFallback
            )
            .shadow(color: profileTint.opacity(frameGlowOpacity), radius: frameGlowRadius)

            Image(skillTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: -2, y: 2)

            Text("LV \(level)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.unbound.bg.opacity(0.94)))
                .overlay(Capsule().strokeBorder(tint.opacity(0.62), lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: 8)
        }
        .frame(width: 188, height: 202)
    }

    private var frameGlowOpacity: Double {
        switch profileColorTier.ordinal {
        case 1...4: return 0
        case 5...6: return 0.24
        case 7: return 0.34
        default: return 0.44
        }
    }

    private var frameGlowRadius: CGFloat {
        switch profileColorTier.ordinal {
        case 1...4: return 0
        case 5...6: return 6
        case 7: return 10
        default: return 14
        }
    }
}

private struct ProgressJourneyCard: View {
    let dayZero: ProgressPhoto
    let now: ProgressPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BODY TIMELINE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("DAY 0 -> NOW")
                        .font(Font.unbound.titleS)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Text(deltaCopy)
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.impact)
            }

            HStack(spacing: 10) {
                timelineImage(photo: dayZero, label: "DAY 0", tint: Color.unbound.textSecondary)
                timelineImage(photo: now, label: "NOW", tint: Color.unbound.impact)
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
                LinearGradient(
                    colors: [
                        Color.unbound.impact.opacity(0.18),
                        Color.unbound.accent.opacity(0.08),
                        .clear
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.impact.opacity(0.34), lineWidth: 1)
        )
    }

    private func timelineImage(photo: ProgressPhoto, label: String, tint: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = UIImage(contentsOfFile: photo.storageUrl) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.unbound.bg)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    )
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.58)))
                .overlay(Capsule().strokeBorder(tint.opacity(0.7), lineWidth: 1))
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 218)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.44), lineWidth: 1)
        )
    }

    private var deltaCopy: String {
        let days = Calendar.current.dateComponents([.day], from: dayZero.capturedAt, to: now.capturedAt).day ?? 0
        if days >= 60 { return "\(max(1, days / 30)) MO" }
        if days > 0 { return "\(days) D" }
        return "NOW"
    }
}

private struct RankTitlePlate: View {
    let tier: SkillTier
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.displayName.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .allowsTightening(true)
                Text("TIER")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tier.rewardTextTint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.34), lineWidth: 1)
        )
    }
}

private struct LevelProgressPlate: View {
    let currentXP: Int
    let xpPerLevel: Int
    let progress: Double
    let tint: Color
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(currentXP)/\(xpPerLevel) XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(detail)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.borderSubtle)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint, Color.unbound.textPrimary.opacity(0.74)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(7, proxy.size.width * progress))
                        .shadow(color: tint.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

private struct TrophyMetricTile: View {
    let label: String
    let value: String
    var detail: String? = nil
    let tint: Color
    let systemImage: String
    var badgeTier: SkillTier? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3, height: 36)
                .shadow(color: accent.opacity(0.26), radius: 6)

            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 4) {
                if let badgeTier {
                    Image(badgeTier.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }

                Text(value)
                    .font(.system(size: badgeTier == nil ? 17 : 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.30)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let detail {
                    Text(detail)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
        .frame(maxWidth: .infinity, minHeight: badgeTier == nil ? 54 : 74, alignment: .trailing)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var accent: Color {
        if let badgeTier {
            return badgeTier.rewardTint
        }
        return tint
    }

    private var backgroundFill: Color {
        Color.unbound.bg.opacity(0.66)
    }

    private var borderColor: Color {
        accent.opacity(0.24)
    }
}

private struct DossierLinework: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.58, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.44))
                    path.move(to: CGPoint(x: width * 0.72, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.24))
                    path.move(to: CGPoint(x: width * 0.05, y: height * 0.72))
                    path.addLine(to: CGPoint(x: width * 0.42, y: height))
                }
                .stroke(color.opacity(0.26), lineWidth: 1)

                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Rectangle()
                            .fill(Color.unbound.borderSubtle.opacity(0.42))
                            .frame(width: width * CGFloat(0.14 + Double(index) * 0.035), height: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
        }
        .allowsHitTesting(false)
    }
}
