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
    @State private var aggregateTier: SkillTier = .initiate
    @State private var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)
    @State private var bodyMapProfile: BodyMapProfile = BodyMapProfile(userId: "")
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

    @State private var overallLevel: OverallLevelProgress?

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
                        badgesCard
                        profileArchiveStrip
                        if let beforePhoto, let afterPhoto {
                            ProgressJourneyCard(dayZero: beforePhoto, now: afterPhoto)
                        }
                        PhotoCalendarView().environmentObject(services)
                        BodyMapProfileCard(profile: bodyMapProfile)
                        Spacer().frame(height: 118)
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
            RankInfoSheet(
                currentTier: aggregateTier,
                readiness: overallRankTrialReadiness
            ) { definition in
                showRankInfo = false
                startOverallRankTrial(definition)
            }
                .presentationDetents([.large])
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
        .onReceive(NotificationCenter.default.publisher(for: .requestOpenProfileRankInfo)) { _ in
            showRankInfo = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .bodyMapProgressUpdated)) { notification in
            if let profile = notification.userInfo?["profile"] as? BodyMapProfile {
                bodyMapProfile = profile
            } else if let userId = services.auth.currentUserId {
                Task {
                    bodyMapProfile = await BodyMapProgressService.shared.profile(userId: userId, database: services.database)
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

        aggregateTier = await services.rank.aggregateTier(userId: userId)
        // Cosmetics reflect the CONFIRMED overall rank (highestPassedRank,
        // permanent), not the live accumulation (Phase 7 §5).
        let confirmedRank = OverallRankTrialStore.shared.load(userId: userId).currentRank
        let cosmeticTier = RankCosmetics.equipped(highestRank: confirmedRank)
        _ = RankCosmetics.unlockedTiers(userId: userId, currentTier: cosmeticTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: cosmeticTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: cosmeticTier)
        equippedProfileColorTier = RankCosmetics.equippedProfileColorTier(userId: userId, currentTier: cosmeticTier)
        attributeProfile = services.attribute.profile(userId: userId)
        bodyMapProfile = await BodyMapProgressService.shared.profile(userId: userId, database: services.database)

        unlockedBadges = services.badges.unlockedBadges(userId: userId)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        totalBadgeCount = BadgeCatalog.all.count
        sessionXP = services.sessionXP.record(userId: userId)
        overallLevel = (try? await services.database.read(collection: "overall_level_progress", documentId: userId)) ?? OverallLevelProgress(userId: userId)

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
        resolveBestSkillAndLift(
            userId: userId,
            workoutLogs: workoutLogs,
            bodyweightKg: profile?.weightKg,
            sex: profile?.biologicalSex
        )

        // Load trials state
        trialsState = services.trials.state(userId: userId)
        overallRankTrialReadiness = await TrialReadinessService.shared.readiness(userId: userId, services: services)

        isLoading = false
    }

    private func startOverallRankTrial(_ definition: OverallRankTrialDefinition) {
        let userId = services.auth.currentUserId ?? "anonymous"

        // Auto-confirm crossings (Novice / Apprentice) claim the rank instantly
        // — no session. Fire the confirm + cinematic and refresh readiness.
        if OverallRankTrialDefinitions.ceremonyTier(for: definition.targetRank) == .autoConfirm {
            OverallRankTrialRunner.shared.confirmAutoRank(for: definition, userId: userId)
            Task { await load() }
            return
        }

        let resolvedTrial = overallRankTrialReadiness?.resolvedTrial?.definitionId == definition.id
            ? overallRankTrialReadiness?.resolvedTrial
            : nil
        activeOverallRankTrialDraft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: userId,
            resolvedTrial: resolvedTrial,
            bodyweightKg: profile?.weightKg
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
        let level = overallLevel?.level ?? 0
        let levelProgress = overallLevel?.progressToNextLevel ?? 0
        let currentXP = { guard let p = overallLevel else { return 0 }; return max(0, Int(p.totalXP - OverallLevelCurve.xpRequired(forLevel: p.level))) }()
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
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("profile.settings")
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
        let xpPerLevel = max(1, Int(OverallLevelCurve.xpRequired(forLevel: level + 1) - OverallLevelCurve.xpRequired(forLevel: level)))
        return VStack(alignment: .leading, spacing: 10) {
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
                RankTitlePlate(
                    tier: aggregateTier,
                    tint: rankColor,
                    gateSummary: rankPlateGateSummary
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current tier and rank gate details")
            .accessibilityIdentifier("profile.rankInfoButton")
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

    private func resolveBestSkillAndLift(
        userId: String,
        workoutLogs: [WorkoutLog],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) {
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
            let tier = Self.liftTier(
                for: lift,
                weightKg: pr?.weightKg ?? 0,
                bodyweightKg: bodyweightKg,
                sex: sex
            )
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

    private static func liftTier(
        for lift: String,
        weightKg: Double,
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> SkillTier {
        guard let bodyweightKg, bodyweightKg > 0, weightKg > 0 else { return .initiate }
        return StrengthStandards.rank(
            liftKg: weightKg,
            bodyweightKg: bodyweightKg,
            exerciseKey: lift,
            sex: sex
        ) ?? .initiate
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

    // MARK: - Rank gate

    private var rankPlateGateSummary: String? {
        guard let readiness = overallRankTrialReadiness,
              readiness.definition != nil
        else { return nil }
        if readiness.isReady { return "GATE READY" }
        let met = readiness.requirements.filter(\.isMet).count
        let total = max(1, readiness.requirements.count)
        return "GATE \(met)/\(total)"
    }

    // MARK: - Quiet archive

    @ViewBuilder
    private var profileArchiveStrip: some View {
        if hasVowArchiveContent {
            bindingVowArchiveTile
        }
    }

    private var hasVowArchiveContent: Bool {
        trialsState.currentTrial != nil ||
        !trialsState.unlockedTitles.isEmpty ||
        trialsState.completionsByCardKind.values.reduce(0, +) > 0
    }

    private var bindingVowArchiveTile: some View {
        let active = trialsState.currentTrial
        let total = trialsState.completionsByCardKind.values.reduce(0, +)
        let title = active?.chosenCard.displayName
            ?? trialsState.equippedTitle.map(TitleCatalog.displayName(for:))
            ?? "Binding Vows"
        let tint = active?.chosenCard.theme.tintColor ?? Color.unbound.accent

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "flag.2.crossed.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text("BINDING VOWS")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 0)
            }

            Text(title.uppercased())
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.64)

            HStack(spacing: 6) {
                archiveStatChip(value: "\(total)", label: "CLEARED", tint: tint)
                archiveStatChip(value: "\(trialsState.unlockedTitles.count)", label: "TITLES", tint: Color.unbound.rankGold)
                if let next = nextBindingVowTitleProgress {
                    archiveStatChip(value: "\(next.current)/\(next.target)", label: "NEXT", tint: next.tint)
                }
            }

            Text(bindingVowArchiveDetail(active: active))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            if !trialsState.unlockedTitles.isEmpty {
                bindingVowTitleShelf
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
        .accessibilityIdentifier("profile.bindingVowArchiveTile")
    }

    private var bindingVowTitleShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(trialsState.unlockedTitles, id: \.self) { titleId in
                    bindingVowTitleButton(titleId)
                }
            }
        }
    }

    private func bindingVowTitleButton(_ titleId: TitleID) -> some View {
        let isEquipped = titleId == trialsState.equippedTitle
        return Button {
            equipBindingVowTitle(isEquipped ? nil : titleId)
        } label: {
            TitleBadge(titleId: titleId, compact: true)
                .overlay(
                    Capsule()
                        .strokeBorder(isEquipped ? Color.unbound.rankGold : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func archiveStatChip(value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.11)))
    }

    private func bindingVowArchiveDetail(active: WeeklyVow?) -> String {
        if let active {
            return "\(active.chosenCard.theme.displayLabel) is \(bindingVowStateLabel(active.capstoneState).lowercased())."
        }
        if trialsState.unlockedTitles.isEmpty {
            return "Binding Vows live on Home; cleared vows build titles here."
        }
        return "Equipped title: \(trialsState.equippedTitle.map(TitleCatalog.displayName(for:)) ?? "None")."
    }

    private var nextBindingVowTitleProgress: (current: Int, target: Int, tint: Color)? {
        let entries: [(kind: WeeklyVowKind, tint: Color)] = [
            (.ember, Color.unbound.rankGreen),
            (.overdrive, Color.unbound.accent),
            (.apex, Color.unbound.rankGold)
        ]
        let thresholds = [3, 7, 15]
        let candidates = entries.compactMap { entry -> (current: Int, target: Int, tint: Color, ratio: Double)? in
            let current = trialsState.completionsByCardKind[entry.kind] ?? 0
            guard let target = thresholds.first(where: { current < $0 }) else { return nil }
            return (current, target, entry.tint, Double(current) / Double(target))
        }
        guard let next = candidates.max(by: { $0.ratio < $1.ratio }) else { return nil }
        return (next.current, next.target, next.tint)
    }

    private func equipBindingVowTitle(_ titleId: TitleID?) {
        guard let userId = services.auth.currentUserId else { return }
        UnboundHaptics.soft()
        services.trials.equipTitle(titleId, userId: userId)
        trialsState = services.trials.state(userId: userId)
    }

    private func bindingVowStateLabel(_ state: CapstoneState) -> String {
        switch state {
        case .pending: return "active"
        case .windowOpen: return "vow ready"
        case .completed: return "complete"
        case .missed: return "missed"
        }
    }

}

private struct BodyMapProfileCard: View {
    let profile: BodyMapProfile

    private var hotRows: [BodyMapRegionDisplayRow] {
        rankedRows
            .filter { $0.activityScore > 0 || $0.load.lifetimeLoad > 0 }
            .prefix(4)
            .map { $0 }
    }

    private var quietRows: [BodyMapRegionDisplayRow] {
        allRows
            .filter { $0.load.lifetimeLoad > 0 && $0.activityScore < maxActivityScore * 0.35 }
            .sorted {
                if $0.activityScore != $1.activityScore {
                    return $0.activityScore < $1.activityScore
                }
                return $0.region.rawValue < $1.region.rawValue
            }
            .prefix(3)
            .map { $0 }
    }

    private var rankedRows: [BodyMapRegionDisplayRow] {
        allRows.sorted {
            if $0.activityScore != $1.activityScore {
                return $0.activityScore > $1.activityScore
            }
            return $0.load.lifetimeLoad > $1.load.lifetimeLoad
        }
    }

    private var allRows: [BodyMapRegionDisplayRow] {
        BodyRegion.allCases.map { region in
            BodyMapRegionDisplayRow(region: region, load: profile.load(for: region))
        }
    }

    private var maxActivityScore: Double {
        max(1, allRows.map(\.activityScore).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("HEAT MAP")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(primaryStatus.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
                Text(trainedRegionSummary.uppercased())
                    .font(Font.unbound.monoS.weight(.black))
                    .foregroundStyle(Color.unbound.coachCyan)
                    .lineLimit(1)
            }

            BodyHeatMapSilhouette(rows: allRows, maxActivityScore: maxActivityScore)
                .frame(height: 238)

            if !hotRows.isEmpty {
                HStack(spacing: 7) {
                    ForEach(hotRows.prefix(3)) { row in
                        focusChip(row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !quietRows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("QUIET LATELY")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(Color.unbound.textTertiary)
                    HStack(spacing: 7) {
                        ForEach(quietRows) { row in
                            quietChip(row)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.28), lineWidth: 1)
        )
        .accessibilityIdentifier("profile.bodyMapCard")
    }

    private var trainedRegionCount: Int {
        allRows.filter { $0.load.lifetimeLoad > 0 }.count
    }

    private var trainedRegionSummary: String {
        trainedRegionCount == 0 ? "No logs" : "\(trainedRegionCount) areas"
    }

    private var primaryStatus: String {
        guard let top = hotRows.first, top.activityScore > 0 else {
            return "Awaiting first session"
        }
        if let jointStress = hotRows.first(where: { $0.load.recentJointTendonStressSets >= 6 }) {
            return "\(jointStress.region.displayName) joint stress elevated"
        }
        if let second = hotRows.dropFirst().first,
           second.activityScore >= top.activityScore * 0.82 {
            return "\(top.region.displayName) and \(second.region.displayName) did most work"
        }
        return "\(top.region.displayName) did most work"
    }

    private func focusChip(_ row: BodyMapRegionDisplayRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.region.displayName.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(activityLabel(for: row).uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(row.tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(row.tint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(row.tint.opacity(0.25), lineWidth: 1))
    }

    private func quietChip(_ row: BodyMapRegionDisplayRow) -> some View {
        Text(row.region.displayName.uppercased())
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(row.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(row.tint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(row.tint.opacity(0.24), lineWidth: 1))
    }

    private func activityLabel(for row: BodyMapRegionDisplayRow) -> String {
        guard row.activityScore > 0 else { return "Resting" }
        let fraction = row.activityScore / maxActivityScore
        if fraction >= 0.72 { return "Heavy" }
        if fraction >= 0.34 { return "Moderate" }
        return "Light"
    }

    private func recencyText(_ date: Date?) -> String {
        guard let date else { return "NOT LOGGED" }
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        if days <= 0 { return "TODAY" }
        if days == 1 { return "1 DAY AGO" }
        return "\(days) DAYS AGO"
    }

    private func roleSummaryText(_ load: BodyRegionLoad) -> String {
        let pairs = rolePairs(for: load).prefix(2)
        guard !pairs.isEmpty else { return "Recently trained" }
        return pairs
            .map { $0.label }
            .joined(separator: " + ")
    }

    private func rolePairs(for load: BodyRegionLoad) -> [(label: String, value: Double, priority: Int)] {
        [
            ("Main work", load.recentDirectHardSets, 0),
            ("Helping work", load.recentSecondaryExposureSets, 1),
            ("Skill practice", load.recentSkillPracticeSets, 2),
            ("Mobility", load.recentMobilityControlSets, 3),
            ("Joint stress", load.recentJointTendonStressSets, 4)
        ]
        .filter { $0.value > 0.05 }
        .sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.priority < $1.priority
        }
    }
}

private struct BodyHeatMapSilhouette: View {
    let rows: [BodyMapRegionDisplayRow]
    let maxActivityScore: Double

    private var rowByRegion: [BodyRegion: BodyMapRegionDisplayRow] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0.region, $0) })
    }

    private var patches: [BodyHeatPatch] {
        BodyRegion.allCases.flatMap { region -> [BodyHeatPatch] in
            guard let row = rowByRegion[region], row.activityScore > 0 else { return [] }
            let intensity = min(1, max(0, row.activityScore / max(1, maxActivityScore)))
            return BodyHeatPatch.patches(for: region, tint: row.tint, intensity: intensity)
        }
    }

    private var hasHeat: Bool {
        patches.contains { $0.intensity > 0 }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.22))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.45))

            SilhouetteView(rimLight: .neutral, chromaticAberration: 0.45, breathe: false, scale: 0.58, asset: .frontMale)
                .frame(width: 170, height: 222)
                .clipped()
                .opacity(0.72)

            GeometryReader { geo in
                ZStack {
                    ForEach(patches) { patch in
                        heatPatch(patch)
                            .frame(
                                width: geo.size.width * patch.width,
                                height: geo.size.height * patch.height
                            )
                            .position(
                                x: geo.size.width * patch.x,
                                y: geo.size.height * patch.y
                            )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !hasHeat {
                VStack(spacing: 6) {
                    Image(systemName: "flame")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("NO HEAT YET")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.black.opacity(0.35)))
                .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }

            VStack {
                HStack {
                    Text("LOW")
                    heatLegend
                    Text("HIGH")
                }
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.top, 10)
                Spacer()
                Text("RECENT TRAINING HEAT")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.bottom, 10)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var heatLegend: some View {
        LinearGradient(
            colors: [
                Color.unbound.coachCyan.opacity(0.24),
                Color.unbound.impact.opacity(0.58),
                Color.unbound.ember.opacity(0.86)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 64, height: 5)
        .clipShape(Capsule())
    }

    private func heatPatch(_ patch: BodyHeatPatch) -> some View {
        Capsule()
            .fill(
                RadialGradient(
                    colors: [
                        patch.tint.opacity(0.18 + patch.intensity * 0.68),
                        patch.tint.opacity(0.08 + patch.intensity * 0.28),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 54
                )
            )
            .blur(radius: 3 + patch.intensity * 3)
            .overlay(
                Capsule()
                    .strokeBorder(patch.tint.opacity(0.12 + patch.intensity * 0.36), lineWidth: 1)
            )
            .blendMode(.screen)
    }
}

private struct BodyHeatPatch: Identifiable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let tint: Color
    let intensity: Double

    static func patches(for region: BodyRegion, tint: Color, intensity: Double) -> [BodyHeatPatch] {
        func patch(_ id: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> BodyHeatPatch {
            BodyHeatPatch(id: "\(region.rawValue)-\(id)", x: x, y: y, width: width, height: height, tint: tint, intensity: intensity)
        }

        switch region {
        case .chest:
            return [patch("center", 0.50, 0.33, 0.26, 0.12)]
        case .shoulders:
            return [patch("left", 0.38, 0.28, 0.16, 0.09), patch("right", 0.62, 0.28, 0.16, 0.09)]
        case .traps:
            return [patch("upper", 0.50, 0.24, 0.19, 0.08)]
        case .lats:
            return [patch("left", 0.41, 0.40, 0.13, 0.18), patch("right", 0.59, 0.40, 0.13, 0.18)]
        case .abs:
            return [patch("center", 0.50, 0.48, 0.19, 0.18)]
        case .obliques:
            return [patch("left", 0.40, 0.49, 0.10, 0.17), patch("right", 0.60, 0.49, 0.10, 0.17)]
        case .lowerBack:
            return [patch("center", 0.50, 0.55, 0.21, 0.13)]
        case .biceps:
            return [patch("left", 0.31, 0.40, 0.08, 0.15), patch("right", 0.69, 0.40, 0.08, 0.15)]
        case .triceps:
            return [patch("left", 0.29, 0.43, 0.08, 0.16), patch("right", 0.71, 0.43, 0.08, 0.16)]
        case .forearms:
            return [patch("left", 0.25, 0.56, 0.08, 0.18), patch("right", 0.75, 0.56, 0.08, 0.18)]
        case .glutes:
            return [patch("center", 0.50, 0.63, 0.22, 0.11)]
        case .quads:
            return [patch("left", 0.43, 0.75, 0.10, 0.22), patch("right", 0.57, 0.75, 0.10, 0.22)]
        case .hamstrings:
            return [patch("left", 0.43, 0.77, 0.10, 0.20), patch("right", 0.57, 0.77, 0.10, 0.20)]
        case .calves:
            return [patch("left", 0.43, 0.91, 0.08, 0.13), patch("right", 0.57, 0.91, 0.08, 0.13)]
        }
    }
}

private struct BodyMapRegionDisplayRow: Identifiable {
    var id: String { region.rawValue }
    let region: BodyRegion
    let load: BodyRegionLoad

    var activityScore: Double {
        let roleLoad = load.recentRoleCoachLoad
        return roleLoad > 0 ? roleLoad : load.recentLoad
    }

    var tint: Color {
        switch region {
        case .chest, .triceps:
            return Color.unbound.ember
        case .shoulders:
            return Color.unbound.impact
        case .biceps, .forearms, .traps, .lats:
            return Color.unbound.coachCyan
        case .abs, .obliques, .lowerBack:
            return Color.unbound.accent
        case .quads, .hamstrings, .glutes, .calves:
            return Color.unbound.rankGold
        }
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
    let readiness: OverallRankTrialReadiness?
    let onStart: (OverallRankTrialDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Image(headerTier.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .shadow(color: headerTier.rewardTint.opacity(0.38), radius: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("RANK TRIAL")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(readiness.map(rankGateTitle) ?? currentTier.displayName)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
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

                if let readiness {
                    RankTrialFlowStrip(readiness: readiness)

                    VStack(alignment: .leading, spacing: 10) {
                        OverallRankTrialReadinessCard(readiness: readiness) { definition in
                            dismiss()
                            onStart(definition)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private var headerTier: RankTitle {
        readiness?.targetRank ?? currentTier.rankTitle
    }

    private func rankGateTitle(_ readiness: OverallRankTrialReadiness) -> String {
        if let target = readiness.targetRank {
            return "\(readiness.currentRank.displayName) -> \(target.displayName)"
        }
        return "\(readiness.currentRank.displayName) Gate Cleared"
    }
}

private struct RankTrialFlowStrip: View {
    let readiness: OverallRankTrialReadiness

    var body: some View {
        let met = readiness.requirements.filter(\.isMet).count
        let total = max(1, readiness.requirements.count)

        return HStack(spacing: 8) {
            step(icon: "list.bullet.clipboard.fill", label: "\(met)/\(total)", caption: "PROOFS", tint: Color.unbound.accent)
            connector
            step(icon: readiness.isReady ? "checkmark.seal.fill" : "lock.fill", label: readiness.isReady ? "READY" : "LOCKED", caption: "GATE", tint: readiness.targetRank?.rewardTextTint ?? Color.unbound.rankGold)
            connector
            step(icon: "play.fill", label: "TRIAL", caption: "WORKOUT", tint: Color.unbound.coachCyan)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var connector: some View {
        Capsule()
            .fill(Color.unbound.borderSubtle)
            .frame(width: 18, height: 2)
    }

    private func step(icon: String, label: String, caption: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.14)))
                .overlay(Circle().strokeBorder(tint.opacity(0.32), lineWidth: 1))
            VStack(spacing: 1) {
                Text(label)
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(caption)
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
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

            Text("LVL \(level)")
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
    let gateSummary: String?

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
                Text(gateSummary ?? "TIER")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(gateSummary == nil ? Color.unbound.textSecondary : tier.rewardTextTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
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
        .accessibilityIdentifier("profile.rankInfoPlate")
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
