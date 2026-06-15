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
// rest (rank, stats, badges) and nests the existing
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
    @State private var unlockedBadges: [Badge] = []
    @State private var totalBadgeCount: Int = 0
    @State private var totalWorkouts: Int = 0
    @State private var showcaseSkillId: String?
    @State private var showcaseSkillName: String = "None yet"
    @State private var showcaseSkillTier: SkillTier = .initiate
    @State private var showcaseLiftId: String?
    @State private var showcaseLiftName: String = "None yet"
    @State private var showcaseLiftTier: SkillTier = .initiate
    @State private var showcaseSkillOptions: [ProfileShowcaseOption] = []
    @State private var showcaseLiftOptions: [ProfileShowcaseOption] = []
    @State private var equippedFrameTier: RankTitle = .initiate
    @State private var equippedBackgroundTier: RankTitle = .initiate
    @State private var equippedShopProfileBorder: ShopProfileBorderID?
    @State private var equippedProfileBackdrop: ShopItem?
    @State private var sessionXP: SessionXPRecord?
    @State private var manualPhotoCount: Int = 0
    @State private var scanPhotoCount: Int = 0
    @State private var beforePhoto: ProgressPhoto?
    @State private var afterPhoto: ProgressPhoto?
    @State private var isLoading = true
    @State private var trialsState: TrialsState = .empty
    @State private var overallRankTrialReadiness: OverallRankTrialReadiness?
    @State private var activeOverallRankTrialDraft: TrainingSessionDraft?
    @State private var gateHallWorld: GateWorld?
    @State private var showTrialRecords = false
    @State private var profileEquipment: Set<MovementEquipment> = [.bodyweight, .openSpace]
    @State private var profileHeaderWidth: CGFloat = UIScreen.main.bounds.width

    @ObservedObject private var photoStore = ProfilePhotoStore.shared
    @State private var showPhotoOptions = false
    @State private var showEditProfile = false
    @State private var showRankInfo = false
    @State private var showProfileCosmetics = false
    @State private var didAutoOpenCosmetics = false
    @State private var showShop = false
    @State private var shopInitialCategory: ShopCategory = .backdrop
    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem?
    private var photoUserId: String { services.auth.currentUserId ?? "" }

    @State private var overallLevel: OverallLevelProgress?

    var body: some View {
        GeometryReader { rootProxy in
            ZStack(alignment: .top) {
                Color.unbound.bg.ignoresSafeArea()
                profileBaseWash

                if isLoading {
                    ProgressView().tint(Color.unbound.accent)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            trophyHeader(topSafeInset: rootProxy.safeAreaInsets.top)

                            VStack(spacing: 0) {
                                ProfileBuildCard(profile: attributeProfile)
                                badgesArchiveSection
                                rewardsRow
                                if let beforePhoto, let afterPhoto {
                                    ProgressJourneySection(dayZero: beforePhoto, now: afterPhoto)
                                }
                                PhotoCalendarView().environmentObject(services)
                                Spacer().frame(height: 118)
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .ignoresSafeArea(edges: .top)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationBarHidden(true)
        .task(id: services.auth.currentUserId ?? "anonymous") { await load() }
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
                displayHandle: profile?.displayHandle ?? "",
                unlockedTitles: trialsState.unlockedTitles,
                equippedTitle: trialsState.equippedTitle,
                showcaseSkillOptions: showcaseSkillOptions,
                selectedShowcaseSkillId: showcaseSkillId,
                showcaseLiftOptions: showcaseLiftOptions,
                selectedShowcaseLiftId: showcaseLiftId,
                save: saveProfileIdentity
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Screenshot harness: `--unbound-open-cosmetics` (with
            // `--unbound-open-profile`) lands directly on the cosmetics sheet.
            if !didAutoOpenCosmetics,
               ProcessInfo.processInfo.arguments.contains("--unbound-open-cosmetics") {
                didAutoOpenCosmetics = true
                showProfileCosmetics = true
            }
        }
        .sheet(isPresented: $showProfileCosmetics, onDismiss: {
            // Guarantee the header avatar reflects any frame/border the user
            // equipped while the picker was open, even if a change notification
            // was missed.
            refreshEquippedCosmetics()
        }) {
            NavigationStack {
                ProfileCosmeticsView { category in
                    shopInitialCategory = category
                    showProfileCosmetics = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        showShop = true
                    }
                }
                .environmentObject(services)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShop) {
            NavigationStack {
                ShopView(initialCategory: shopInitialCategory)
                    .environmentObject(services)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRankInfo) {
            RankInfoSheet(
                currentTier: aggregateTier,
                readiness: overallRankTrialReadiness,
                onOpenGate: {
                    showRankInfo = false
                    if let definition = overallRankTrialReadiness?.definition {
                        gateHallWorld = GateWorldCatalog.world(for: definition.format)
                    }
                },
                onOpenRecords: {
                    showRankInfo = false
                    showTrialRecords = true
                }
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $gateHallWorld) { world in
            GateHallView(
                world: world,
                resolvedTrial: overallRankTrialReadiness?.resolvedTrial,
                latestAttempt: overallRankTrialReadiness?.latestAttempt,
                loadout: overallRankTrialReadiness?.resolvedTrial?.selectedLoadout ?? .noGymField,
                resolveStations: { loadout in resolveStations(for: loadout) },
                onBegin: { loadout in
                    gateHallWorld = nil
                    if let definition = overallRankTrialReadiness?.definition {
                        startOverallRankTrial(definition, loadout: loadout)
                    }
                },
                onClose: { gateHallWorld = nil }
            )
            .environmentObject(services)
        }
        .fullScreenCover(isPresented: $showTrialRecords) {
            ZStack(alignment: .topTrailing) {
                TrialRecordsShelf(progress: OverallRankTrialStore.shared.load(userId: services.auth.currentUserId ?? ""))
                Button { showTrialRecords = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
                .padding(.top, 16).padding(.trailing, 16)
            }
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
            GateTrialLaunchView(draft: draft, services: services, onFinished: {
                activeOverallRankTrialDraft = nil
            })
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
                    await refreshRewardReadouts(userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .overallLevelProgressUpdated)) { note in
            guard let userId = services.auth.currentUserId else { return }
            if let progress = note.userInfo?["progress"] as? OverallLevelProgress,
               progress.userId == userId {
                overallLevel = progress
            }
            Task { await refreshRewardReadouts(userId: userId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionXPUpdated)) { _ in
            guard let userId = services.auth.currentUserId else { return }
            Task { await refreshRewardReadouts(userId: userId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestOpenProfileRankInfo)) { _ in
            showRankInfo = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            refreshShopCosmetics()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileCosmeticsChanged)) { note in
            guard profileCosmeticChangeAppliesToCurrentUser(note) else { return }
            refreshEquippedCosmetics()
        }
        .attributeRankUpToast()
    }

    private var profileBaseWash: some View {
        LinearGradient(
            stops: [
                .init(color: activeProfileTint.opacity(0.10), location: 0),
                .init(color: Color.unbound.bg.opacity(0.98), location: 0.32),
                .init(color: Color.black.opacity(0.28), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
        refreshEquippedCosmetics(userId: userId)
        attributeProfile = services.attribute.profile(userId: userId)

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
        resolveProfileShowcase(
            userId: userId,
            workoutLogs: workoutLogs,
            bodyweightKg: profile?.weightKg,
            sex: profile?.biologicalSex
        )

        // Load trials state
        trialsState = services.trials.state(userId: userId)
        profileEquipment = TrialReadinessService.movementEquipment(from: profile?.equipment ?? [.bodyweight])
        overallRankTrialReadiness = await TrialReadinessService.shared.readiness(userId: userId, services: services)

        isLoading = false
    }

    @MainActor
    private func refreshRewardReadouts(userId: String) async {
        sessionXP = services.sessionXP.record(userId: userId)
        overallLevel = (try? await services.database.read(
            collection: "overall_level_progress",
            documentId: userId
        )) ?? OverallLevelProgress(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
        trialsState = services.trials.state(userId: userId)
        totalWorkouts = max(totalWorkouts, sessionXP?.totalSessions ?? 0)
    }

    private func refreshShopCosmetics(userId overrideUserId: String? = nil) {
        let userId = overrideUserId ?? services.auth.currentUserId ?? "anonymous"
        equippedShopProfileBorder = ShopInventoryStore.equippedProfileBorder(userId: userId)
        equippedProfileBackdrop = ShopInventoryStore.equippedBackdrop(for: .profile, userId: userId)
    }

    private func refreshEquippedCosmetics(userId overrideUserId: String? = nil) {
        let userId = overrideUserId ?? services.auth.currentUserId ?? "anonymous"
        // Cosmetics reflect the CONFIRMED overall rank (highestPassedRank,
        // permanent), not the live accumulation (Phase 7 §5).
        let confirmedRank = OverallRankTrialStore.shared.load(userId: userId).currentRank
        let cosmeticTier = RankCosmetics.equipped(highestRank: confirmedRank)
        _ = RankCosmetics.unlockedTiers(userId: userId, currentTier: cosmeticTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: cosmeticTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: cosmeticTier)
        refreshShopCosmetics(userId: userId)
    }

    private func profileCosmeticChangeAppliesToCurrentUser(_ note: Notification) -> Bool {
        guard let eventUserId = note.userInfo?["userId"] as? String else { return true }
        return eventUserId == (services.auth.currentUserId ?? "anonymous")
    }

    private func startOverallRankTrial(_ definition: OverallRankTrialDefinition, loadout: TrialLoadout? = nil) {
        let userId = services.auth.currentUserId ?? "anonymous"

        let resolvedTrial: ResolvedRankTrial?
        if let loadout {
            // Honor the Hall loadout pick: re-resolve the trial for it.
            resolvedTrial = RankTrialLoadoutResolver.shared.resolve(
                definition: definition,
                userId: userId,
                equipment: profileEquipment,
                attributeScores: AttributeProfileStore.shared.load(userId: userId),
                preferredLoadout: loadout
            ).resolvedTrial
        } else {
            resolvedTrial = overallRankTrialReadiness?.resolvedTrial?.definitionId == definition.id
                ? overallRankTrialReadiness?.resolvedTrial
                : nil
        }
        activeOverallRankTrialDraft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: userId,
            resolvedTrial: resolvedTrial,
            bodyweightKg: profile?.weightKg
        )
    }

    /// Live station list for the Hall's loadout picker (spec §6.2).
    private func resolveStations(for loadout: TrialLoadout) -> [ResolvedTrialStation] {
        guard let definition = overallRankTrialReadiness?.definition else { return [] }
        let userId = services.auth.currentUserId ?? "anonymous"
        return RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: userId,
            equipment: profileEquipment,
            attributeScores: AttributeProfileStore.shared.load(userId: userId),
            preferredLoadout: loadout
        ).resolvedTrial?.stations ?? []
    }

    @MainActor
    private func saveProfileIdentity(
        displayHandle: String,
        equippedTitle: TitleID?,
        showcaseSelection: ProfileShowcaseSelection
    ) async throws {
        let userId = services.auth.currentUserId ?? "anonymous"
        let cleanedHandle = displayHandle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))

        try await services.user.updateProfile(
            userId: userId,
            fields: [
                "displayName": NSNull(),
                "displayHandle": cleanedHandle.isEmpty ? NSNull() : cleanedHandle
            ]
        )

        services.trials.equipTitle(equippedTitle, userId: userId)
        trialsState = services.trials.state(userId: userId)
        ProfileShowcaseStore.save(showcaseSelection, userId: userId)
        applyProfileShowcase(
            selection: showcaseSelection,
            skillOptions: showcaseSkillOptions,
            liftOptions: showcaseLiftOptions
        )

        if var profile {
            profile.displayName = nil
            profile.displayHandle = cleanedHandle.isEmpty ? nil : cleanedHandle
            self.profile = profile
        }
    }

    // MARK: - Header

    private func trophyHeader(topSafeInset: CGFloat) -> some View {
        let level = overallLevel?.level ?? 0
        let levelProgress = overallLevel?.progressToNextLevel ?? 0
        let currentXP = { guard let p = overallLevel else { return 0 }; return max(0, Int(p.totalXP - OverallLevelCurve.xpRequired(forLevel: p.level))) }()
        let lastXPGain = max(0, Int((overallLevel?.lastGainedXP ?? 0).rounded()))
        let rankColor = aggregateTier.rewardTint
        let rankTextColor = aggregateTier.rewardTextTint
        let profileTint = activeProfileTint
        let avatarSize = profileAvatarSize
        let metrics = [
            UnboundNativeMetric(
                label: "Streak",
                value: "\(sessionXP?.longestStreak ?? 0)D",
                detail: "Best",
                tint: Color.unbound.ember
            ),
            UnboundNativeMetric(
                label: "Sessions",
                value: "\(totalWorkouts)",
                detail: "Total",
                tint: Color.unbound.coachCyan
            ),
            UnboundNativeMetric(
                label: "Vows",
                value: "\(vowsCompletedCount)",
                detail: vowMetricDetail,
                tint: vowMetricTint
            )
        ]

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                UnboundBackdropArt(
                    assetName: activeProfileBackgroundAsset,
                    role: .profileBanner,
                    tint: profileTint
                )
                .ignoresSafeArea(edges: .top)

                DossierLinework(color: profileTint)
                    .opacity(0.08)

                // Lower-band legibility + seamless hand-off: the full-bleed
                // banner reaches the bottom of the header, so we ramp its lower
                // half into the page background. This both guarantees the
                // avatar + name + rank read cleanly on the art's dead space and
                // dissolves the old hard black cut into the metric rail below.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.40),
                        .init(color: Color.unbound.bg.opacity(0.58), location: 0.74),
                        .init(color: Color.unbound.bg, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    profileTopBar
                        .unboundTextShadow(strength: 0.96)

                    Spacer(minLength: 16)

                    HStack(alignment: .bottom, spacing: profileHeroSpacing) {
                        heroAvatar(level: level, tint: rankColor, size: avatarSize)
                            .shadow(color: profileTint.opacity(0.36), radius: 20, x: 0, y: 10)
                            .layoutPriority(3)

                        identityStack(
                            level: level,
                            currentXP: currentXP,
                            lastXPGain: lastXPGain,
                            levelProgress: levelProgress,
                            rankColor: rankColor,
                            rankTextColor: rankTextColor
                        )
                        .layoutPriority(2)
                        .unboundTextShadow(strength: 0.98)
                    }
                }
                .frame(maxWidth: profileHeaderContentMaxWidth, alignment: .leading)
                .padding(.horizontal, profileHeaderHorizontalPadding)
                .padding(.top, max(8, topSafeInset + 12))
                .padding(.bottom, profileHeaderBottomPadding)
            }
            .frame(height: profileHeaderHeight + topSafeInset)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateProfileHeaderWidth(proxy.size.width)
                        }
                        .onChange(of: proxy.size.width) { _, width in
                            updateProfileHeaderWidth(width)
                        }
                }
            }

            UnboundNativeMetricRail(metrics: metrics)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 18)

            HStack(alignment: .top, spacing: 16) {
                TrophyShowcaseRow(
                    label: "SKILL",
                    value: showcaseSkillName.uppercased(),
                    systemImage: "sparkles",
                    badgeTier: showcaseSkillTier
                )
                TrophyShowcaseRow(
                    label: "LIFT",
                    value: showcaseLiftName.uppercased(),
                    systemImage: "dumbbell.fill",
                    badgeTier: showcaseLiftTier
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background {
            LinearGradient(
                stops: [
                    .init(color: profileTint.opacity(0.06), location: 0),
                    .init(color: Color.unbound.bg.opacity(0.98), location: 0.30),
                    .init(color: Color.unbound.bg, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .overlay(alignment: .bottom) {
            UnboundNativeDivider(opacity: 0.62)
        }
    }

    private var profileTopBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UNBOUND")
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.impact)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("PROFILE")
                    .font(Font.unbound.titleM)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .layoutPriority(1)
            Spacer()
            Button {
                UnboundHaptics.medium()
                showProfileCosmetics = true
            } label: {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(activeProfileTint)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.bg.opacity(0.78)))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Customize profile cosmetics")
            .accessibilityIdentifier("profile.cosmetics")

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

    private var activeProfileBackgroundAsset: String? {
        if let assetName = equippedProfileBackdrop?.backdropAssetName,
           UIImage(named: assetName) != nil {
            return assetName
        }
        return RankCosmetics.profileHeaderBannerAsset(for: equippedBackgroundTier)
    }

    private var activeProfileTint: Color {
        if let backdrop = equippedProfileBackdrop,
           let assetName = backdrop.backdropAssetName,
           UIImage(named: assetName) != nil {
            return backdrop.accent
        }
        if let border = equippedShopProfileBorder {
            return border.accent
        }
        return equippedBackgroundTier.rewardTint
    }

    private var profileHeaderHeight: CGFloat {
        Self.profileHeaderHeight(for: profileHeaderWidth)
    }

    private static func profileHeaderHeight(for width: CGFloat) -> CGFloat {
        let clampedWidth = max(320, min(width, 820))
        let bannerHeight = clampedWidth / UnboundBackdropAspect.profileBanner
        // Keep the header closer to the banner's own wide aspect. A shorter
        // header means the full-bleed fill crops far less off the sides, so the
        // off-centre focal "core" stays fully on-screen instead of being shoved
        // past the right edge.
        return min(400, max(286, bannerHeight + 52))
    }

    private var profileHeaderContentMaxWidth: CGFloat {
        profileHeaderWidth >= 700 ? 660 : .infinity
    }

    private var profileHeaderHorizontalPadding: CGFloat {
        profileHeaderWidth >= 700 ? 32 : 20
    }

    private var profileHeaderBottomPadding: CGFloat {
        // Lifts the avatar + identity block UP off the bottom edge so it sits
        // higher on the banner, leaving a measured band of dead space below it
        // before the art blends into the page.
        if profileHeaderWidth < 360 {
            return 40
        }
        if profileHeaderWidth >= 700 {
            return 56
        }
        return 46
    }

    private var profileHeroSpacing: CGFloat {
        profileHeaderWidth < 360 ? 10 : 14
    }

    private var profileAvatarSize: CGFloat {
        if profileHeaderWidth < 360 {
            return hasLongIdentityText ? 104 : 118
        }
        if profileHeaderWidth >= 700 {
            return hasLongIdentityText ? 168 : 196
        }
        return hasLongIdentityText ? 126 : 148
    }

    private var hasLongIdentityText: Bool {
        profileIdentityName.count > 20 || profileTitleLine.count > 22
    }

    private func heroAvatar(level: Int, tint: Color, size: CGFloat) -> some View {
        Button {
            showPhotoOptions = true
        } label: {
            ProfileHeroAvatar(
                cosmeticTier: equippedFrameTier,
                glowTier: equippedFrameTier,
                profileTint: activeProfileTint,
                skillTier: aggregateTier,
                level: level,
                tint: tint,
                image: photoStore.image(userId: photoUserId),
                letterFallback: avatarInitial,
                shopBorder: equippedShopProfileBorder,
                size: size
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile picture. Tap to change.")
    }

    private func updateProfileHeaderWidth(_ width: CGFloat) {
        guard width > 1, abs(profileHeaderWidth - width) > 0.5 else { return }
        profileHeaderWidth = width
    }

    private var vowsCompletedCount: Int {
        trialsState.completionsByCardKind.values.reduce(0, +)
    }

    private var vowMetricDetail: String {
        "COMPLETED"
    }

    private var vowMetricTint: Color {
        Color.unbound.rankGold
    }

    private func identityStack(
        level: Int,
        currentXP: Int,
        lastXPGain: Int,
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
                    HStack(alignment: .top, spacing: 6) {
                        Text(profileIdentityName.uppercased())
                            .font(.system(size: 22, weight: .black))
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(profileIdentityName.count > 26 ? 2 : 1)
                            .minimumScaleFactor(profileIdentityName.count > 26 ? 0.52 : 0.62)
                            .allowsTightening(true)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(profileTitleLine.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(rankTextColor)
                        .lineLimit(profileTitleLine.count > 28 ? 2 : 1)
                        .minimumScaleFactor(0.58)
                        .allowsTightening(true)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile handle and title")

            Button {
                showRankInfo = true
            } label: {
                RankTitlePlate(
                    tier: aggregateTier,
                    tint: rankColor
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current tier and rank gate details")
            .accessibilityIdentifier("profile.rankInfoButton")
            .frame(maxWidth: .infinity)

            LevelProgressPlate(
                currentXP: currentXP,
                xpPerLevel: xpPerLevel,
                lastXPGain: lastXPGain,
                progress: levelProgress,
                tint: rankColor,
                detail: "XP"
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var profileIdentityName: String {
        playerHandle
    }

    private var profileTitleLine: String {
        trialsState.equippedTitle.map(TitleCatalog.displayName(for:)) ?? "No title"
    }

    private var avatarInitial: String {
        if let handle = cleanedStoredHandle, let first = handle.first {
            return String(first).uppercased()
        }
        return "U"
    }

    private var playerHandle: String {
        if let handle = cleanedStoredHandle {
            return handle.uppercased()
        }
        return "PLAYER"
    }

    private var cleanedStoredHandle: String? {
        guard let handle = profile?.displayHandle else { return nil }
        let cleaned = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return cleaned.isEmpty ? nil : cleaned
    }

    private func resolveProfileShowcase(
        userId: String,
        workoutLogs: [WorkoutLog],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) {
        let selection = ProfileShowcaseStore.load(userId: userId)
        let skillOptions = Self.skillShowcaseOptions(userId: userId)
        let liftOptions = Self.loggedLiftCandidates(
            logs: workoutLogs,
            bodyweightKg: bodyweightKg,
            sex: sex
        )

        showcaseSkillOptions = skillOptions
        showcaseLiftOptions = liftOptions
        applyProfileShowcase(selection: selection, skillOptions: skillOptions, liftOptions: liftOptions)
    }

    private func applyProfileShowcase(
        selection: ProfileShowcaseSelection,
        skillOptions: [ProfileShowcaseOption],
        liftOptions: [ProfileShowcaseOption]
    ) {
        let skill = Self.selectedShowcaseOption(selection.skillId, options: skillOptions) ?? skillOptions.first
        showcaseSkillId = skill?.id
        showcaseSkillName = skill?.name ?? "None yet"
        showcaseSkillTier = skill?.tier ?? .initiate

        let lift = Self.selectedShowcaseOption(selection.liftId, options: liftOptions) ?? liftOptions.first
        showcaseLiftId = lift?.id
        showcaseLiftName = lift?.name ?? "None yet"
        showcaseLiftTier = lift?.tier ?? .initiate
    }

    private static func selectedShowcaseOption(
        _ id: String?,
        options: [ProfileShowcaseOption]
    ) -> ProfileShowcaseOption? {
        guard let id else { return nil }
        return options.first { $0.id == id }
    }

    private static func skillShowcaseOptions(userId: String) -> [ProfileShowcaseOption] {
        let skillTiers = UserSkillTierStore.shared.load(userId: userId).perSkill
        let nodeStates = SkillProgressService.shared.nodeStates
        let options = SkillGraph.shared.nodes.compactMap { node -> ProfileShowcaseOption? in
            guard nodeStates[node.id] == .proven else { return nil }
            return ProfileShowcaseOption(
                id: node.id,
                name: node.title,
                tier: skillTiers[node.id] ?? .initiate,
                metricSort: Double(node.placementRank.rawValue),
                repsSort: node.tier
            )
        }
        return sortedShowcaseOptions(options)
    }

    private static func displayLiftName(_ lift: String) -> String {
        lift.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func loggedLiftCandidates(
        logs: [WorkoutLog],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> [ProfileShowcaseOption] {
        var bestById: [String: ProfileShowcaseOption] = [:]
        for entry in logs.flatMap(\.exerciseEntries) {
            let rankKey = rankExerciseKey(for: entry)
            let liftId = MovementCatalog.normalized(entry.exerciseName)
            let liftName = displayLiftName(entry.exerciseName)

            for set in entry.sets {
                guard !set.isWarmup, let weightKg = set.weightKg, weightKg > 0 else { continue }
                guard let tier = Self.liftTier(
                    for: rankKey,
                    weightKg: weightKg,
                    bodyweightKg: bodyweightKg,
                    sex: sex
                ) else { continue }
                let option = ProfileShowcaseOption(
                    id: liftId,
                    name: liftName,
                    tier: tier,
                    metricSort: weightKg,
                    repsSort: set.reps
                )
                if let existing = bestById[liftId] {
                    if isShowcaseOption(option, betterThan: existing) {
                        bestById[liftId] = option
                    }
                } else {
                    bestById[liftId] = option
                }
            }
        }
        return sortedShowcaseOptions(Array(bestById.values))
    }

    private static func liftTier(
        for lift: String,
        weightKg: Double,
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> SkillTier? {
        guard weightKg > 0 else { return nil }
        if let bodyweightKg, bodyweightKg > 0 {
            return StrengthStandards.progressToNextRank(
                metricValue: weightKg,
                bodyweightKg: bodyweightKg,
                exerciseKey: lift,
                sex: sex
            )?.current
        }

        if StrengthStandards.canonicalKey(for: lift) != nil ||
            StrengthStandards.accessoryFamily(for: lift) != nil {
            return .initiate
        }

        return nil
    }

    private static func rankExerciseKey(for entry: ExerciseLogEntry) -> String {
        if let key = canonicalMovementExerciseKey(for: entry.rankStandardMovementId) {
            return key
        }
        if let key = canonicalMovementExerciseKey(for: entry.movementId) {
            return key
        }

        let resolved = MovementResolver.resolve(entry.exerciseName)
        if let key = canonicalMovementExerciseKey(for: resolved.rankStandardMovementId) {
            return key
        }
        return MovementResolution.normalizedKey(entry.exerciseName)
    }

    private static func canonicalMovementExerciseKey(for movementId: String?) -> String? {
        guard let movementId, let definition = MovementCatalog.definition(for: movementId) else {
            return nil
        }
        if let canonical = definition.canonicalExerciseName {
            return MovementResolution.normalizedKey(canonical)
        }
        return MovementResolution.normalizedKey(definition.displayName)
    }

    private static func sortedShowcaseOptions(_ options: [ProfileShowcaseOption]) -> [ProfileShowcaseOption] {
        options.sorted { lhs, rhs in
            isShowcaseOption(lhs, betterThan: rhs)
        }
    }

    private static func isShowcaseOption(
        _ lhs: ProfileShowcaseOption,
        betterThan rhs: ProfileShowcaseOption
    ) -> Bool {
        if lhs.tier != rhs.tier { return lhs.tier > rhs.tier }
        if lhs.metricSort != rhs.metricSort { return lhs.metricSort > rhs.metricSort }
        if lhs.repsSort != rhs.repsSort { return lhs.repsSort > rhs.repsSort }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func rankTitle(for tier: SkillTier) -> RankTitle {
        tier.rankTitle
    }

    // MARK: - Archive

    private var rewardsRow: some View {
        NavigationLink(destination: RewardsVaultView().environmentObject(services)) {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 30, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("REWARDS")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Titles, skins, cosmetics & badges")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("See everything and how to earn it")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                UnboundNativeDivider(opacity: 0.42)
            }
        }
        .buttonStyle(.plain)
    }

    private var badgesArchiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        .contentShape(Rectangle())
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
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            UnboundNativeDivider(opacity: 0.52)
        }
        .overlay(alignment: .bottom) {
            UnboundNativeDivider(opacity: 0.42)
        }
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

}
