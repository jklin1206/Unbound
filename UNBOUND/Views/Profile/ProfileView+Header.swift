// UNBOUND/Views/Profile/ProfileView+Header.swift
//
// The trophy header: banner art + scrims, top bar, hero avatar, metric rail,
// showcase row, and the responsive header-layout metrics.
import SwiftUI

extension ProfileView {

    // MARK: - Header

    func trophyHeader(topSafeInset: CGFloat) -> some View {
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
                // Soft top emergence: fade the art's first ~14% from the page
                // background so it doesn't start on a hard horizontal edge
                // (which read as "cut off") — same dissolve language as the
                // bottom hand-off.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Start the art BELOW the status-bar inset: bleeding under the
                // Dynamic Island hid the banner's top slice and made the whole
                // composition read too high, detached from the avatar zone.
                .padding(.top, topSafeInset)

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
                        .init(color: .black.opacity(0.12), location: 0.42),
                        .init(color: .black.opacity(0.5), location: 0.66),
                        .init(color: Color.unbound.bg.opacity(0.88), location: 0.88),
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle.opacity(0.62), lineWidth: 0.5)
            )
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

    var activeProfileBackgroundAsset: String? {
        if let assetName = equippedProfileBackdrop?.backdropAssetName,
           UIImage(named: assetName) != nil {
            return assetName
        }
        return RankCosmetics.profileHeaderBannerAsset(for: equippedBackgroundTier)
    }

    var activeProfileTint: Color {
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
        // Full-fit: the header tracks the banner's own 16:9 so the WHOLE
        // authored art is visible at every device width (the art renders fit,
        // top-anchored — see UnboundBackdropArt). The floor only guards the
        // avatar/identity overlay on very narrow widths; any band below the
        // art dissolves into the page background via the header scrim.
        return max(252, bannerHeight)
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
        profileIdentityName.count > 20 || (profileTitleLine?.count ?? 0) > 22
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
                size: size,
                defaultPortrait: DefaultPortrait.resolve(
                    gender: profile?.gender,
                    biologicalSex: profile?.biologicalSex
                )
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
        trialsState.completionsByLane.values.reduce(0, +)
    }

    private var vowMetricDetail: String {
        "COMPLETED"
    }

    private var vowMetricTint: Color {
        Color.unbound.rankGold
    }
}
