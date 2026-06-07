import SwiftUI

extension Step_Verdict {
    var verdictScreenBackground: some View {
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

    var portfolioProfilePic: some View {
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

    var isDebugOnboardingPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("-OnboardingStep")
    }

    var revealIsSettled: Bool {
        hasAnimated || isDebugOnboardingPreview
    }

    func portfolioAttributeRow(_ key: AttributeKey) -> some View {
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

    func portfolioSignal(label: String, value: String) -> some View {
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

    func portfolioMetric(label: String, value: String) -> some View {
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

    var scanSignalStrip: some View {
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

    var trainingPortfolio: some View {
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

    func planLine(number: Int, title: String, detail: String) -> some View {
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

    var heroCard: some View {
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

    var loggedDateText: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: Date()).uppercased(with: Locale.current)
    }

    var snapshotBody: String {
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

    var scanInsightCard: some View {
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

    var profileHexCard: some View {
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

}
