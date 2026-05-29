import SwiftUI

// MARK: - Step_Verdict
//
// The post-scan reveal. Reframed from "verdict" to "snapshot" — the scan is
// a visual record of progress toward the user's chosen archetype, not a
// score against it. No match-% anywhere. Rank shown is the user's gym-earned
// rank (derived from commitment + lifestyle), not a scan output.

struct Step_Verdict: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onContinue: () -> Void

    @State private var hasAnimated = false

    var body: some View {
        ZStack {
            verdictScreenBackground

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        Color.clear
                            .frame(height: 0)
                            .id("verdictTop")

                        portfolioSheet
                        if flow.scanInsights != nil {
                            scanSignalStrip
                        }
                        Spacer().frame(height: 124) // space for pinned CTA
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 52)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo("verdictTop", anchor: .top)
                    }
                }
            }

            // Pinned CTA
            VStack {
                Spacer()
                UnboundButton(
                    title: L10n.onboarding("verdict.primary", defaultValue: "See the ladder"),
                    icon: "arrow.right",
                    action: onContinue
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        colors: [Color.unbound.bg.opacity(0), Color.unbound.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false),
                    alignment: .bottom
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .opacity(revealIsSettled ? 1 : 0)
        .offset(y: revealIsSettled ? 0 : 16)
        .onAppear {
            if isDebugOnboardingPreview {
                hasAnimated = true
                return
            }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.88)) {
                hasAnimated = true
            }
            UnboundHaptics.heavy()
        }
    }

    // MARK: Hero — rank + scan photo

    private var portfolioSheet: some View {
        VStack(alignment: .center, spacing: 14) {
            revealHeader
            initiateAvatarReveal
            initiateIdentityBlock
            initiateTierPlate
            dayZeroMilestoneBand
            profileHexReveal
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 10)
        .opacity(hasAnimated ? 1 : 0)
        .scaleEffect(hasAnimated ? 1 : 0.97)
    }

    private var revealHeader: some View {
        VStack(spacing: 2) {
            Text(L10n.string(.appName, defaultValue: "UNBOUND").uppercased())
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .tracking(5.0)
                .foregroundStyle(Color.unbound.accent)
                .multilineTextAlignment(.center)

            Text(L10n.onboarding("verdict.rankRevealed", defaultValue: "RANK REVEALED"))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(initiateTint)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(initiateTint.opacity(0.12)))
                .overlay(Capsule().strokeBorder(initiateTint.opacity(0.42), lineWidth: 1))
                .padding(.top, 4)

            Text(L10n.onboarding("verdict.dayZero", defaultValue: "DAY ZERO"))
                .font(.system(size: 50, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var initiateAvatarReveal: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            initiateTint.opacity(0.34),
                            Color.unbound.accent.opacity(0.16),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 142
                    )
                )
                .frame(width: 250, height: 250)
                .blur(radius: 14)

            CosmeticAvatar(
                tier: .initiate,
                size: 222,
                image: onboardingProfileImage,
                letterFallback: "U"
            )
            .shadow(color: initiateTint.opacity(0.46), radius: 26)
            .scaleEffect(hasAnimated ? 1 : 0.82)
            .rotation3DEffect(.degrees(hasAnimated ? 0 : -8), axis: (x: 0, y: 1, z: 0))

            Circle()
                .trim(from: 0, to: hasAnimated ? 1 : 0.08)
                .stroke(
                    AngularGradient(
                        colors: [.clear, initiateTint.opacity(0.2), Color.unbound.impact, initiateTint.opacity(0.2), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 246, height: 246)
                .rotationEffect(.degrees(hasAnimated ? 360 : 0))
                .animation(.easeOut(duration: 1.1).delay(0.12), value: hasAnimated)
        }
        .frame(height: 232)
    }

    private var initiateIdentityBlock: some View {
        VStack(spacing: 8) {
            Text(L10n.onboarding("verdict.profileCreated", defaultValue: "PROFILE CREATED"))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(initiateTint)
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.unbound.bg.opacity(0.88)))
                .overlay(Capsule().strokeBorder(initiateTint.opacity(0.44), lineWidth: 1))

            Text(L10n.string(.appName, defaultValue: "UNBOUND").uppercased())
                .font(.system(size: 34, weight: .black))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(displayHandleText)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(initiateTint)
                .lineLimit(1)
        }
    }

    private var initiateTierPlate: some View {
        HStack(spacing: 13) {
            Spacer(minLength: 0)

            Image(RankTitle.initiate.asSkillTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.onboarding("verdict.currentRank", defaultValue: "CURRENT RANK"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(initiateTint)
                Text(L10n.onboarding("common.rank.initiate", defaultValue: "INITIATE"))
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(initiateTint.opacity(0.58), lineWidth: 1.2)
        )
        .shadow(color: initiateTint.opacity(hasAnimated ? 0.42 : 0), radius: 24)
        .scaleEffect(hasAnimated ? 1 : 0.94)
    }

    private var dayZeroMilestoneBand: some View {
        VStack(spacing: 10) {
            VStack(alignment: .center, spacing: 4) {
                Text(L10n.onboarding("verdict.startingLine", defaultValue: "STARTING LINE"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(initiateTint)
                Text(L10n.onboarding("verdict.startingLine.body", defaultValue: "Your first rank is locked in. The rest is earned by showing up."))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                revealPill(L10n.onboarding("common.dayZero.compact", defaultValue: "DAY 0"))
                revealPill(L10n.onboardingFormat("common.timesPerWeek.long", defaultValue: "%dx / WEEK", sessionsPerWeek))
                revealPill(L10n.onboarding("verdict.firstArc", defaultValue: "FIRST ARC"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(initiateTint.opacity(0.50), lineWidth: 1)
        )
    }

    private var onboardingProofGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            revealStatTile(label: L10n.onboarding("common.start", defaultValue: "START"), value: L10n.onboarding("common.dayZero.compact", defaultValue: "DAY 0"), icon: "flame.fill", tint: Color.unbound.ember)
            revealStatTile(label: L10n.onboarding("verdict.monthOne", defaultValue: "MONTH ONE"), value: L10n.onboardingFormat("common.timesPerWeek.long", defaultValue: "%dx / WEEK", sessionsPerWeek), icon: "bolt.fill", tint: Color.unbound.coachCyan)
            revealStatTile(label: L10n.onboarding("verdict.buildFocus", defaultValue: "BUILD FOCUS"), value: focusAreas.first?.uppercased() ?? L10n.onboarding("common.fullBody", defaultValue: "Full Body").uppercased(), icon: "sparkles", tint: initiateTint)
            revealStatTile(label: L10n.onboarding("verdict.firstUnlock", defaultValue: "FIRST UNLOCK"), value: firstUnlockTitle.uppercased(), icon: "dumbbell.fill", tint: Color.unbound.accent)
        }
    }

    private var profileHexReveal: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L10n.onboarding("verdict.buildHex", defaultValue: "BUILD HEX"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(L10n.onboarding("verdict.baseline", defaultValue: "BASELINE"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(initiateTint)
            }

            AttributeHex(
                current: onboardingAttributeValues,
                levels: onboardingAttributeLevels,
                tiers: onboardingAttributeTiers,
                showLabels: true,
                labelVariant: .profile,
                radius: 82
            )
            .padding(.horizontal, 42)
            .padding(.top, 42)
            .padding(.bottom, 46)

            attributeLevelGrid

            Text(L10n.onboarding("verdict.buildHex.body", defaultValue: "This is just the baseline. Every session makes the card harder to ignore."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.9), lineWidth: 1)
        )
    }

    private var attributeLevelGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7)], spacing: 7) {
            ForEach(AttributeKey.allCases, id: \.self) { key in
                let level = onboardingAttributeLevels[key] ?? 1
                HStack(spacing: 6) {
                    Text(key.shortCode)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(key.rewardTint)
                    Spacer(minLength: 0)
                    Text(L10n.onboardingFormat("common.level", defaultValue: "LVL %d", level))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(key.rewardTint.opacity(0.24), lineWidth: 1)
                )
            }
        }
    }

    private func revealStatTile(label: String, value: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
                .frame(width: 4, height: 42)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.42), lineWidth: 1)
        )
    }

    private func revealPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(Color.unbound.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(initiateTint.opacity(0.24), lineWidth: 1))
    }

    private var verdictScreenBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    initiateTint.opacity(0.34),
                    Color.unbound.surfaceElevated.opacity(0.96),
                    Color.black.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let asset = RankCosmetics.profileBackgroundAsset(for: .initiate),
               let ui = UIImage(named: asset) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.68)
                    .blendMode(.plusLighter)
            }

            RadialGradient(
                colors: [
                    initiateTint.opacity(0.22),
                    Color.clear
                ],
                center: UnitPoint(x: 0.64, y: 0.24),
                startRadius: 20,
                endRadius: 330
            )

            Rectangle()
                .fill(Color.black.opacity(0.18))

            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.24),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            DayZeroDossierLinework(color: initiateTint)
                .opacity(0.26)
        }
        .ignoresSafeArea()
    }

    private var portfolioProfilePic: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.accent.opacity(0.18),
                            Color.unbound.surface.opacity(0.36),
                            Color.black.opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)

            Group {
                if isDebugOnboardingPreview, let baseline = UIImage(named: "body_baseline") {
                    Image(uiImage: baseline)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else if let photo = flow.profilePhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else if let baseline = UIImage(named: "body_baseline") {
                    Image(uiImage: baseline)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
            .frame(width: 82, height: 82)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.unbound.accent.opacity(0.46), lineWidth: 1.5)
            )
        }
    }

    private var isDebugOnboardingPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("-OnboardingStep")
    }

    private var revealIsSettled: Bool {
        hasAnimated || isDebugOnboardingPreview
    }

    private func portfolioAttributeRow(_ key: AttributeKey) -> some View {
        let value = onboardingAttributeValues[key] ?? 0
        // Onboarding preview is pre-account (no persisted xp). Treat the
        // synthetic 0…22 estimate directly as a small starter level.
        let level = Int(value.rounded())

        return HStack(spacing: 12) {
            Text(key.shortCode)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(key.rewardTint)
                .frame(width: 34, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.textPrimary.opacity(0.06))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    key.rewardTint.opacity(0.92),
                                    Color.unbound.accent.opacity(0.62)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * min(1, max(0.06, value / 100)))
                }
            }
            .frame(height: 5)

            Text(L10n.onboardingFormat("common.level", defaultValue: "LVL %d", level))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .overlay(
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.64))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func portfolioSignal(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func portfolioMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
    }

    private var scanSignalStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.ember)
                Text(L10n.onboarding("verdict.scanSignal.title", defaultValue: "DAY ZERO SIGNAL"))
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.ember)
            }

            if let insights = flow.scanInsights {
                Text(L10n.onboardingFormat("verdict.scanSignal.summary", defaultValue: "%@ · Shoulder-to-hip %.2f", insights.headline, insights.shoulderHipRatio))
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
    }

    private var trainingPortfolio: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.onboarding("verdict.firstArc", defaultValue: "FIRST ARC"))
                    .font(Font.unbound.captionS)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)

                Text(buildNarrative)
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                planLine(
                    number: 1,
                    title: L10n.onboarding("verdict.trainingPlan.foundation.title", defaultValue: "Foundation"),
                    detail: L10n.onboarding("verdict.trainingPlan.foundation.detail", defaultValue: "Lock the base. Make the first week automatic.")
                )
                planLine(
                    number: 2,
                    title: L10n.onboarding("verdict.trainingPlan.growth.title", defaultValue: "Growth"),
                    detail: L10n.onboarding("verdict.trainingPlan.growth.detail", defaultValue: "Add pressure where your build is asking for it.")
                )
                planLine(
                    number: 3,
                    title: L10n.onboarding("verdict.trainingPlan.rankClimb.title", defaultValue: "Rank climb"),
                    detail: L10n.onboarding("verdict.trainingPlan.rankClimb.detail", defaultValue: "Sessions push the profile forward.")
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private func planLine(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", number))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 30, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.7))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var heroCard: some View {
        VStack(spacing: 20) {
            // Scan photo as circular profile pic with violet ring
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.unbound.accent.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)

                Group {
                    if let photo = flow.profilePhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else if let baseline = UIImage(named: "body_baseline") {
                        // User skipped capture (dev path / fallback) — show
                        // the baseline starter silhouette as "you are here"
                        // rather than a raw SF Symbol.
                        Image(uiImage: baseline)
                            .resizable()
                            .scaledToFit()
                            .background(Color.unbound.surfaceElevated)
                    } else {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.unbound.surfaceElevated)
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.unbound.accent, lineWidth: 2)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 12, x: 0, y: 0)
                )
            }

            // Snapshot framing — no judgment, just a logged moment.
            VStack(spacing: 10) {
                Text(L10n.onboarding("verdict.snapshot.title", defaultValue: "YOUR SNAPSHOT · UNBOUND"))
                    .font(Font.unbound.monoS)
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)

                Text(L10n.onboarding("verdict.snapshot.headline", defaultValue: "The Build Begins"))
                    .font(Font.unbound.displayM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.onboardingFormat("verdict.snapshot.logged", defaultValue: "LOGGED · %@", loggedDateText))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                }
                .foregroundStyle(Color.unbound.success)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Capsule().strokeBorder(Color.unbound.success.opacity(0.55), lineWidth: 1)
                )

                Text(snapshotBody)
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var loggedDateText: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: Date()).uppercased(with: Locale.current)
    }

    private var snapshotBody: String {
        if flow.displayHandle.isEmpty {
            return L10n.onboarding("verdict.snapshot.body.anonymous", defaultValue: "Your arc is logged. Every session moves this forward.")
        }
        return L10n.onboardingFormat("verdict.snapshot.body.named", defaultValue: "%@ — your arc is logged. Every session moves this forward.", flow.displayHandle)
    }

    // MARK: Scan insight — one honest, specific fact from the Vision analysis
    //
    // Shown only when `LocalBodyInsightsService` produced a result during
    // the analyzing screen. Intentionally narrow: one measured ratio, one
    // line explaining how it nudged the program. No body-fat %, no muscle-
    // mass score, nothing we don't actually measure.

    private var scanInsightCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text(L10n.onboarding("verdict.scanInsight.fromDayZero", defaultValue: "FROM DAY ZERO"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }

                if let insights = flow.scanInsights {
                    Text(insights.headline)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)

                    HStack(spacing: 8) {
                        Text(L10n.onboarding("verdict.scanInsight.shoulderToHip", defaultValue: "SHOULDER-TO-HIP"))
                            .font(Font.unbound.captionS)
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(String(format: "%.2f", insights.shoulderHipRatio))
                            .font(Font.unbound.monoM)
                            .foregroundStyle(Color.unbound.accent)
                            .monospacedDigit()
                    }

                    Text(insights.programImpact)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Marketable profile artifact — handle + starting rank + stat hex

    private var profileHexCard: some View {
        UnboundCard {
            VStack(spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.onboarding("verdict.profile.title", defaultValue: "DAY ZERO PROFILE"))
                            .font(Font.unbound.captionS)
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(displayHandleText)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 12)

                    VStack(spacing: 3) {
                        Text(L10n.onboarding("common.start", defaultValue: "START"))
                            .font(Font.unbound.captionS)
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(flow.derivedRank.displayName.uppercased())
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                            .foregroundStyle(rankTint(flow.derivedRank))
                            .shadow(color: rankTint(flow.derivedRank).opacity(0.45), radius: 12)
                    }
                    .frame(width: 96)
                }

                HStack(alignment: .center, spacing: 18) {
                    AttributeHex(
                        current: onboardingAttributeValues,
                        levels: onboardingAttributeLevels,
                        showLabels: true,
                        radius: 82
                    )
                    .padding(.vertical, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        profileStat(label: L10n.onboarding("common.focus", defaultValue: "FOCUS"), value: focusAreas.first?.uppercased() ?? L10n.onboarding("common.fullBody", defaultValue: "Full Body").uppercased())
                        profileStat(label: L10n.onboarding("verdict.firstUnlock", defaultValue: "FIRST UNLOCK"), value: firstUnlockTitle.uppercased())
                        profileStat(label: L10n.onboarding("verdict.protocol", defaultValue: "PROTOCOL"), value: L10n.onboardingFormat("common.timesPerWeek.long", defaultValue: "%dx / WEEK", sessionsPerWeek))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(L10n.onboarding("verdict.profile.body", defaultValue: "This is your starting card. Every completed session moves the stats, rank, and next unlock forward."))
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var displayHandleText: String {
        let trimmed = flow.displayHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.onboarding("verdict.handle.fallback", defaultValue: "@PLAYER") : "@\(trimmed.uppercased())"
    }

    private var displayNameText: String {
        let trimmed = flow.displayHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.string(.appName, defaultValue: "UNBOUND").uppercased() : trimmed.uppercased()
    }

    private var initiateTint: Color {
        RankTitle.initiate.rewardTint
    }

    private var onboardingProfileImage: UIImage? {
        if isDebugOnboardingPreview, let baseline = UIImage(named: "body_baseline") {
            return baseline
        }
        return flow.profilePhoto
    }

    private var onboardingAttributeLevels: [AttributeKey: Int] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
            let value = onboardingAttributeValues[key] ?? 0
            return (key, Int(value.rounded()))
        })
    }

    private var onboardingAttributeTiers: [AttributeKey: RankTitle] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, RankTitle.initiate) })
    }

    private var onboardingAttributeValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
            let base: Double = {
                switch key {
                case .power: return 16
                case .vitality: return 12
                case .control: return 14
                case .endurance: return 15
                case .mobility: return 10
                case .explosiveness: return 8
                }
            }()
            let seededBoost = flow.effectiveSeededAttributes.contains(key) ? 3.0 : 0.0
            let goalBoost: Double = {
                switch key {
                case .power:
                    return flow.goals.contains(.getStronger) ? 2 : 0
                case .endurance:
                    return flow.goals.contains(.athletic) ? 2 : 0
                case .control:
                    return flow.exerciseStyles.contains(.calisthenics) ? 2 : 0
                case .mobility:
                    return flow.exerciseStyles.contains(.mobility) ? 2 : 0
                case .explosiveness:
                    return flow.exerciseStyles.contains(.plyometrics) ? 2 : 0
                case .vitality:
                    return flow.exerciseStyles.contains(.sports) ? 2 : 0
                }
            }()
            return (key, min(22, base + seededBoost + goalBoost))
        })
    }


    private var firstUnlockTitle: String {
        SkillTree.universal.nodes.first?.title ?? L10n.onboarding("verdict.firstUnlockFallback", defaultValue: "First Node")
    }

    private func profileStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: Build dossier — tailored narrative paragraph
    //
    // Pulls from every onboarding answer to assemble a 3–4 sentence dossier
    // that reads like a dossier, not a checklist. Static template with
    // input-driven slots.

    private var buildDossierCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text(L10n.onboarding("verdict.dossier.title", defaultValue: "YOUR BUILD DOSSIER"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }

                Text(buildNarrative)
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
        }
    }

    /// Weaves focus areas, experience, and commitment into one cohesive dossier
    /// paragraph. Not AI — purely template — but reads tailored because it
    /// pulls from the user's actual answers.
    private var buildNarrative: String {
        let focusPhrase = focusAreasPhrase
        let experiencePhrase = experienceDescriptor
        let commitPhrase = commitmentDescriptor
        let equipPhrase = equipmentDescriptor

        return L10n.onboardingFormat(
            "verdict.dossier.narrative",
            defaultValue: "Your first arc starts from your %@ baseline %@. Priority work is %@ — the gap between today and the version you keep picturing. With your %@ commitment, the first milestone is close enough to chase, and the climb keeps going after that.",
            experiencePhrase,
            equipPhrase,
            focusPhrase,
            commitPhrase
        )
    }

    private var focusAreasPhrase: String {
        let names = focusAreas.prefix(2).map { $0.lowercased() }
        switch names.count {
        case 0: return L10n.onboarding("verdict.focusPhrase.fullBody", defaultValue: "full-body recomposition")
        case 1: return names[0]
        default: return L10n.onboardingFormat("verdict.focusPhrase.pair", defaultValue: "%@ and %@", names[0], names[1])
        }
    }

    private var experienceDescriptor: String {
        // Keyed off experience level — any experience enum exists downstream;
        // if not wired, return a safe default read.
        L10n.onboarding("verdict.experience.current", defaultValue: "current")
    }

    private var commitmentDescriptor: String {
        switch flow.commitment {
        case 9...10: return L10n.onboarding("verdict.commitment.allIn", defaultValue: "all-in")
        case 7...8: return L10n.onboarding("verdict.commitment.serious", defaultValue: "serious")
        case 5...6: return L10n.onboarding("verdict.commitment.steady", defaultValue: "steady")
        default: return L10n.onboarding("verdict.commitment.starting", defaultValue: "starting")
        }
    }

    private var equipmentDescriptor: String {
        if flow.equipment.contains(.fullGym) {
            return L10n.onboarding("verdict.equipment.fullGym", defaultValue: "with full-gym access")
        }
        if flow.equipment.contains(.bodyweight), flow.equipment.count == 1 {
            return L10n.onboarding("verdict.equipment.bodyweight", defaultValue: "with bodyweight only")
        }
        if flow.equipment.isEmpty { return "" }
        return L10n.onboarding("verdict.equipment.currentGear", defaultValue: "with your current gear")
    }

    // MARK: Build arc + supportive quote

    private var archetypeCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.onboarding("verdict.arc.title", defaultValue: "YOUR BUILD ARC"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text(L10n.string(.appName, defaultValue: "UNBOUND").uppercased())
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.accent)
                        .tracking(1.2)
                }

                Divider().background(Color.unbound.borderSubtle)

                Text(L10n.onboardingFormat("verdict.arc.quote", defaultValue: "\"%@\"", supportiveQuote))
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Supportive tone — Phase 2g upgrades this with BuildIdentity-keyed copy.
    private var supportiveQuote: String {
        L10n.onboarding("verdict.supportiveQuote", defaultValue: "Dense frame waiting to be built. Let's go.")
    }

    // MARK: Focus areas

    private var focusCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.onboarding("verdict.focusAreas.title", defaultValue: "FOCUS AREAS"))
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                FlexibleWrap(spacing: 8) {
                    ForEach(focusAreas, id: \.self) { area in
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.system(size: 10, weight: .semibold))
                            Text(area)
                                .font(Font.unbound.bodyS)
                        }
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var focusAreas: [String] {
        // Phase 2g: derive from BuildIdentity + targetAreas scan output.
        // For now, fall back to user-selected target areas or generic default.
        let areas = flow.targetAreas.prefix(4).map(\.displayName)
        return areas.isEmpty ? [L10n.onboarding("common.fullBody", defaultValue: "Full Body")] : Array(areas)
    }

    // MARK: Plan preview

    private var planCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.onboarding("verdict.protocol.title", defaultValue: "YOUR ADAPTIVE PROTOCOL"))
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                planArc(
                    number: 1,
                    title: L10n.onboarding("verdict.protocol.foundation.title", defaultValue: "Foundation"),
                    detail: L10n.onboarding("verdict.protocol.foundation.detail", defaultValue: "Wake the base. Volume in, form locked.")
                )
                planArc(
                    number: 2,
                    title: L10n.onboarding("verdict.protocol.growth.title", defaultValue: "Growth"),
                    detail: L10n.onboarding("verdict.protocol.growth.detail", defaultValue: "Intensification. Loads climb, reps tighten.")
                )
                planArc(
                    number: 3,
                    title: L10n.onboarding("verdict.protocol.power.title", defaultValue: "Power"),
                    detail: L10n.onboarding("verdict.protocol.power.detail", defaultValue: "Realization when rank opens it.")
                )

                Divider().background(Color.unbound.borderSubtle)

                HStack(spacing: 12) {
                    statChip(icon: "calendar", value: "\(sessionsPerWeek)", label: L10n.onboarding("verdict.protocol.sessionsPerWeek", defaultValue: "sessions / week"))
                    statChip(icon: "clock", value: "\(sessionMinutes)", label: L10n.onboarding("verdict.protocol.minutesPerSession", defaultValue: "min / session"))
                }
            }
        }
    }

    private func planArc(number: Int, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Color.unbound.accent, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
        }
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text(value)
                .font(Font.unbound.monoM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
    }

    private var sessionsPerWeek: Int {
        switch flow.targetFrequency {
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case nil: return 4
        }
    }

    private var sessionMinutes: Int {
        flow.sessionLength?.minutes ?? 45
    }

    private func rankTint(_ rank: RankTitle) -> Color {
        rank.rewardTextTint
    }
}

private struct DayZeroPortfolioHex: View {
    let current: [AttributeKey: Double]
    let radius: CGFloat
    var showsLabels: Bool = true

    private let axisOrder: [AttributeKey] = [.power, .vitality, .control, .endurance, .mobility, .explosiveness]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            drawGrid(ctx: ctx, center: center)
            drawAxes(ctx: ctx, center: center)
            drawCurrent(ctx: ctx, center: center)
        }
        .frame(width: radius * 2.55, height: radius * 2.35)
        .overlay { if showsLabels { labels } }
    }

    private func point(for index: Int, at fraction: Double, center: CGPoint) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 6)
        let r = radius * CGFloat(fraction)
        return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
    }

    private func hexPath(fraction: Double, center: CGPoint) -> Path {
        var path = Path()
        for i in 0..<axisOrder.count {
            let p = point(for: i, at: fraction, center: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    private func drawGrid(ctx: GraphicsContext, center: CGPoint) {
        for fraction in [0.33, 0.66, 1.0] {
            ctx.stroke(
                hexPath(fraction: fraction, center: center),
                with: .color(Color.unbound.textSecondary.opacity(fraction == 1.0 ? 0.42 : 0.2)),
                style: StrokeStyle(lineWidth: fraction == 1.0 ? 1.4 : 1.0, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawAxes(ctx: GraphicsContext, center: CGPoint) {
        for i in 0..<axisOrder.count {
            var path = Path()
            path.move(to: center)
            path.addLine(to: point(for: i, at: 1.0, center: center))
            ctx.stroke(
                path,
                with: .color(Color.unbound.textSecondary.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1.0, lineCap: .round)
            )
        }
    }

    private func drawCurrent(ctx: GraphicsContext, center: CGPoint) {
        var path = Path()
        for (i, key) in axisOrder.enumerated() {
            let raw = max(0, min(100, current[key] ?? 0))
            let fraction = max(0.06, raw / 100)
            let p = point(for: i, at: fraction, center: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()

        ctx.fill(path, with: .color(Color.unbound.accent.opacity(0.22)))
        ctx.stroke(
            path,
            with: .color(Color.unbound.accent.opacity(0.95)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )
    }

    @ViewBuilder
    private var labels: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let labelRadius = radius + 26

            ForEach(Array(axisOrder.enumerated()), id: \.offset) { index, key in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 6)
                let level = Int((current[key] ?? 0).rounded())

                HStack(spacing: 4) {
                    Text(key.shortCode)
                    Text("\(level)")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary.opacity(0.92))
                .frame(width: 58)
                .position(
                    x: center.x + cos(angle) * labelRadius,
                    y: center.y + sin(angle) * labelRadius
                )
            }
        }
    }
}

private struct DayZeroDossierLinework: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.12))
                    path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.05))
                    path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.12))
                    path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.08))

                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.88))
                    path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.82))
                    path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.92))

                    path.move(to: CGPoint(x: w * 0.86, y: h * 0.04))
                    path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.96))
                }
                .stroke(color.opacity(0.42), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

                ForEach(0..<5) { i in
                    Circle()
                        .fill(color.opacity(0.28))
                        .frame(width: 3, height: 3)
                        .position(
                            x: w * [0.18, 0.42, 0.66, 0.82, 0.30][i],
                            y: h * [0.18, 0.30, 0.20, 0.68, 0.78][i]
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
