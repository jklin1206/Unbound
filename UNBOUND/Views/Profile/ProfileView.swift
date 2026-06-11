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
// Data state lives in `ProfileViewModel`; this view keeps only presentation
// state (sheets, pickers, header sizing) and layout.
//
// Deferred to future passes:
//   - Real scan photo library (grid of ProgressPhoto)
//   - Stats history charts (weekly/monthly trend)
//   - Rank journey timeline (when you crossed D → C → B)
//   - Titles collection (separate from badges, per rank memory)

struct ProfileView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var model: ProfileViewModel

    @ObservedObject private var photoStore = ProfilePhotoStore.shared
    @State private var showPhotoOptions = false
    @State private var showEditProfile = false
    @State private var showRankInfo = false
    @State private var showProfileCosmetics = false
    @State private var showShop = false
    @State private var shopInitialCategory: ShopCategory = .backdrop
    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var activeOverallRankTrialDraft: TrainingSessionDraft?
    @State private var profileHeaderWidth: CGFloat = UIScreen.main.bounds.width
    private var photoUserId: String { services.auth.currentUserId ?? "" }

    init(services: ServiceContainer) {
        _model = StateObject(wrappedValue: ProfileViewModel(services: services))
    }

    var body: some View {
        GeometryReader { rootProxy in
            ZStack(alignment: .top) {
                Color.unbound.bg.ignoresSafeArea()
                profileBaseWash

                if model.isLoading {
                    ProgressView().tint(Color.unbound.accent)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            trophyHeader(topSafeInset: rootProxy.safeAreaInsets.top)

                            VStack(spacing: 0) {
                                ProfileBuildCard(profile: model.attributeProfile)
                                badgesArchiveSection
                                rewardsRow
                                if let beforePhoto = model.beforePhoto, let afterPhoto = model.afterPhoto {
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
        .task(id: services.auth.currentUserId ?? "anonymous") { await model.load() }
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
                displayHandle: model.profile?.displayHandle ?? "",
                unlockedTitles: model.trialsState.unlockedTitles,
                equippedTitle: model.trialsState.equippedTitle,
                showcaseSkillOptions: model.showcaseSkillOptions,
                selectedShowcaseSkillId: model.showcaseSkillId,
                showcaseLiftOptions: model.showcaseLiftOptions,
                selectedShowcaseLiftId: model.showcaseLiftId,
                save: model.saveProfileIdentity
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfileCosmetics) {
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
                currentTier: model.aggregateTier,
                readiness: model.overallRankTrialReadiness
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
            Task { await model.load() }
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
            Task { await model.handleAttributeRankUp() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .overallLevelProgressUpdated)) { note in
            guard let userId = services.auth.currentUserId else { return }
            if let progress = note.userInfo?["progress"] as? OverallLevelProgress,
               progress.userId == userId {
                model.overallLevel = progress
            }
            Task { await model.refreshRewardReadouts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionXPUpdated)) { _ in
            guard services.auth.currentUserId != nil else { return }
            Task { await model.refreshRewardReadouts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestOpenProfileRankInfo)) { _ in
            showRankInfo = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            model.refreshShopCosmetics()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileCosmeticsChanged)) { note in
            guard model.cosmeticChangeAppliesToCurrentUser(note) else { return }
            model.refreshEquippedCosmetics()
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

    private func startOverallRankTrial(_ definition: OverallRankTrialDefinition) {
        activeOverallRankTrialDraft = model.overallRankTrialDraft(for: definition)
    }

    // MARK: - Header

    private func trophyHeader(topSafeInset: CGFloat) -> some View {
        let level = model.overallLevel?.level ?? 0
        let levelProgress = model.overallLevel?.progressToNextLevel ?? 0
        let currentXP = { guard let p = model.overallLevel else { return 0 }; return max(0, Int(p.totalXP - OverallLevelCurve.xpRequired(forLevel: p.level))) }()
        let lastXPGain = max(0, Int((model.overallLevel?.lastGainedXP ?? 0).rounded()))
        let rankColor = model.aggregateTier.rewardTint
        let rankTextColor = model.aggregateTier.rewardTextTint
        let profileTint = activeProfileTint
        let avatarSize = profileAvatarSize
        let metrics = [
            UnboundNativeMetric(
                label: "Streak",
                value: "\(model.sessionXP?.longestStreak ?? 0)D",
                detail: "Best",
                tint: Color.unbound.ember
            ),
            UnboundNativeMetric(
                label: "Sessions",
                value: "\(model.totalWorkouts)",
                detail: "Total",
                tint: Color.unbound.coachCyan
            ),
            UnboundNativeMetric(
                label: "Vows",
                value: "\(model.vowsCompletedCount)",
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
            .overlay(alignment: .bottom) {
                UnboundNativeDivider(opacity: 0.64)
            }

            UnboundNativeMetricRail(metrics: metrics)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 18)

            VStack(spacing: 0) {
                TrophyShowcaseRow(
                    label: "SKILL",
                    value: model.showcaseSkillName.uppercased(),
                    systemImage: "sparkles",
                    badgeTier: model.showcaseSkillTier
                )
                TrophyShowcaseRow(
                    label: "LIFT",
                    value: model.showcaseLiftName.uppercased(),
                    systemImage: "dumbbell.fill",
                    badgeTier: model.showcaseLiftTier
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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
        if let assetName = model.equippedProfileBackdrop?.backdropAssetName,
           UIImage(named: assetName) != nil {
            return assetName
        }
        return RankCosmetics.profileBackgroundAsset(for: model.equippedBackgroundTier)
    }

    private var activeProfileTint: Color {
        if let backdrop = model.equippedProfileBackdrop,
           let assetName = backdrop.backdropAssetName,
           UIImage(named: assetName) != nil {
            return backdrop.accent
        }
        if let border = model.equippedShopProfileBorder {
            return border.accent
        }
        return model.equippedBackgroundTier.rewardTint
    }

    private var profileHeaderHeight: CGFloat {
        Self.profileHeaderHeight(for: profileHeaderWidth)
    }

    private static func profileHeaderHeight(for width: CGFloat) -> CGFloat {
        let clampedWidth = max(320, min(width, 820))
        let bannerHeight = clampedWidth / UnboundBackdropAspect.profileBanner
        return min(430, max(320, bannerHeight + 110))
    }

    private var profileHeaderContentMaxWidth: CGFloat {
        profileHeaderWidth >= 700 ? 660 : .infinity
    }

    private var profileHeaderHorizontalPadding: CGFloat {
        profileHeaderWidth >= 700 ? 32 : 20
    }

    private var profileHeaderBottomPadding: CGFloat {
        if profileHeaderWidth < 360 {
            return 58
        }
        if profileHeaderWidth >= 700 {
            return 74
        }
        return 66
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
        model.profileIdentityName.count > 20 || model.profileTitleLine.count > 22
    }

    private func heroAvatar(level: Int, tint: Color, size: CGFloat) -> some View {
        Button {
            showPhotoOptions = true
        } label: {
            ProfileHeroAvatar(
                cosmeticTier: model.equippedFrameTier,
                glowTier: model.equippedFrameTier,
                profileTint: activeProfileTint,
                skillTier: model.aggregateTier,
                level: level,
                tint: tint,
                image: photoStore.image(userId: photoUserId),
                letterFallback: model.avatarInitial,
                shopBorder: model.equippedShopProfileBorder,
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
                        Text(model.profileIdentityName.uppercased())
                            .font(.system(size: 22, weight: .black))
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(model.profileIdentityName.count > 26 ? 2 : 1)
                            .minimumScaleFactor(model.profileIdentityName.count > 26 ? 0.52 : 0.62)
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

                    Text(model.profileTitleLine.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(rankTextColor)
                        .lineLimit(model.profileTitleLine.count > 28 ? 2 : 1)
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
                    tier: model.aggregateTier,
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
                    Text("\(model.unlockedBadges.count) / \(model.totalBadgeCount) UNLOCKED")
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

            if model.unlockedBadges.isEmpty {
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
                        ForEach(Array(model.unlockedBadges.prefix(10))) { b in
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
