import SwiftUI

// MARK: - Step_Paywall
//
// Hard paywall. Blurred full-protocol preview behind, unlock CTA in front.
//
// Two pricing tiers: weekly (highlighted) + annual (best value). The app no
// longer offers limited access after onboarding; users subscribe or remain on
// the locked paywall surface.

struct Step_Paywall: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onUnlock: () -> Void

    @State private var hasAnimated = false
    @State private var pulse = false
    @EnvironmentObject var services: ServiceContainer

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                paywallBackground

                VStack(spacing: 10) {
                    header
                    includedFeatureList

                    Spacer(minLength: 4)

                    ctaSection
                }
                .padding(.horizontal, 20)
                .padding(.top, max(12, proxy.safeAreaInsets.top + 10))
                .padding(.bottom, max(12, proxy.safeAreaInsets.bottom + 10))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .opacity(hasAnimated ? 1 : 0)
        .onAppear {
            services.analytics.track(.paywallViewed(placement: AppConstants.Paywall.hardGate))
            withAnimation(.easeOut(duration: 0.4)) { hasAnimated = true }
            pulse = true
        }
    }

    private var paywallBackground: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            Image("onboarding_path_open_gate")
                .resizable()
                .scaledToFill()
                .opacity(0.32)
                .blur(radius: 2)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.72),
                    Color.unbound.bg.opacity(0.9),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(pulse ? 0.22 : 0.12),
                    Color.clear
                ],
                center: .top,
                startRadius: 28,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                OnboardingAssetGlyph(
                    assetName: "rank_title_ascendant",
                    tint: Color.unbound.impact,
                    size: 21,
                    imagePadding: 2,
                    shape: .hexagon,
                    showsCornerMark: false
                )
                Text(L10n.onboarding("paywall.clean.kicker", defaultValue: "UNBOUND PRO"))
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
            }
            .foregroundStyle(Color.unbound.impact)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.unbound.impact.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Color.unbound.impact.opacity(0.35), lineWidth: 1))

            Text(L10n.onboarding("paywall.clean.title", defaultValue: "Unlock your first arc."))
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .shadow(color: Color.unbound.accent.opacity(0.42), radius: 18)

            Text(L10n.onboarding("paywall.clean.subtitle", defaultValue: "Weekly training, adaptive logs, streaks, and progress scans from your Day Zero setup."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.86)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 4)
    }

    private var includedFeatureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.onboarding("paywall.features.title", defaultValue: "INCLUDED"))
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.7)
                    .foregroundStyle(Color.unbound.impact)
                Spacer()
                Text(L10n.onboarding("paywall.features.badge", defaultValue: "DAY ZERO"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            VStack(spacing: 0) {
                featureListRow(
                    assetName: "onboarding_path_protocol_dossier",
                    title: L10n.onboarding("paywall.feature.plan.title", defaultValue: "Weekly training arc"),
                    detail: L10n.onboarding("paywall.feature.plan.detail", defaultValue: "\(sessionsPerWeek) sessions fit to your schedule")
                )
                listDivider
                featureListRow(
                    assetName: "badge_art_first_session",
                    title: L10n.onboarding("paywall.feature.logs.title", defaultValue: "Editable workout logs"),
                    detail: L10n.onboarding("paywall.feature.logs.detail", defaultValue: "Sets, reps, RPE, swaps, and finishes")
                )
                listDivider
                featureListRow(
                    assetName: "badge_art_consistency_loop",
                    title: L10n.onboarding("paywall.feature.streak.title", defaultValue: "Streak and reminder loop"),
                    detail: L10n.onboarding("paywall.feature.streak.detail", defaultValue: "Keep the habit alive between sessions")
                )
                listDivider
                featureListRow(
                    assetName: "badge_art_proof_10",
                    title: L10n.onboarding("paywall.feature.progress.title", defaultValue: "Progress profile"),
                    detail: L10n.onboarding("paywall.feature.progress.detail", defaultValue: "Ranks, milestones, and visible proof")
                )
                listDivider
                featureListRow(
                    assetName: "badge_art_first_scan",
                    title: L10n.onboarding("paywall.feature.scans.title", defaultValue: "Monthly scan check-ins"),
                    detail: L10n.onboarding("paywall.feature.scans.detail", defaultValue: "Compare changes and tune the next arc")
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.22), lineWidth: 1)
        )
    }

    private var listDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 35)
    }

    private func featureListRow(assetName: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: Color.unbound.impact,
                size: 27,
                imagePadding: 4,
                shape: .hexagon,
                showsCornerMark: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(detail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 38)
    }

    private var unlockBoxGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                unlockBox(
                    assetName: "onboarding_path_protocol_dossier",
                    title: L10n.onboarding("paywall.box.plan.title", defaultValue: "Plan"),
                    detail: L10n.onboarding("paywall.box.plan.detail", defaultValue: "\(sessionsPerWeek)x weekly arc")
                )
                unlockBox(
                    assetName: "badge_art_first_session",
                    title: L10n.onboarding("paywall.box.log.title", defaultValue: "Log"),
                    detail: L10n.onboarding("paywall.box.log.detail", defaultValue: "Sets, RPE, swaps")
                )
            }

            HStack(spacing: 8) {
                unlockBox(
                    assetName: "badge_art_consistency_loop",
                    title: L10n.onboarding("paywall.box.streak.title", defaultValue: "Streak"),
                    detail: L10n.onboarding("paywall.box.streak.detail", defaultValue: "Keep it alive")
                )
                unlockBox(
                    assetName: "badge_art_first_scan",
                    title: L10n.onboarding("paywall.box.scan.title", defaultValue: "Scans"),
                    detail: L10n.onboarding("paywall.box.scan.detail", defaultValue: "Track changes")
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func unlockBox(assetName: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: Color.unbound.impact,
                size: 32,
                imagePadding: 5,
                shape: .hexagon
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: Transformation

    private var transformationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                paywallSeal

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.onboarding("paywall.panel.title", defaultValue: "Your arc is waiting beyond the gate."))
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)

                    Text(L10n.onboarding("paywall.panel.subtitle", defaultValue: "Start with a four-week block tuned to your schedule, equipment, focus areas, and Day Zero scan."))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                compactUnlock(assetName: "badge_art_arc_week", text: "4-week opening arc")
                compactUnlock(assetName: "badge_art_hour_glass", text: "Recovery targets")
                compactUnlock(assetName: "badge_art_proof_10", text: "Rank proof")
            }
        }
        .padding(15)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.92))
                LinearGradient(
                    colors: [
                        Color.unbound.accent.opacity(0.22),
                        Color.unbound.impact.opacity(0.1),
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private var paywallSeal: some View {
        OnboardingAssetGlyph(
            assetName: "rank_title_ascendant",
            tint: Color.unbound.impact,
            size: 58,
            imagePadding: 5,
            shape: .hexagon
        )
    }

    private func compactUnlock(assetName: String, text: String) -> some View {
        HStack(spacing: 9) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: Color.unbound.impact,
                size: 22,
                imagePadding: 4,
                shape: .hexagon,
                showsCornerMark: false
            )
            Text(text)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Feature unlocks

    private var featureUnlocks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.onboarding("paywall.unlocks.title", defaultValue: "What unlocks now"))
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.7)
                .foregroundStyle(Color.unbound.impact)

            ForEach(unlocks) { unlock in
                featureRow(unlock)
            }
        }
    }

    private var unlocks: [PaywallUnlock] {
        [
            PaywallUnlock(
                assetName: "onboarding_path_protocol_dossier",
                title: L10n.onboarding("paywall.unlock.program.title", defaultValue: "The opening arc"),
                detail: L10n.onboarding("paywall.unlock.program.detail", defaultValue: "A 4-week route built from your goals, equipment, training days, and starting point.")
            ),
            PaywallUnlock(
                assetName: "badge_art_first_session",
                title: L10n.onboarding("paywall.unlock.sessions.title", defaultValue: "Sessions that feed the next gate"),
                detail: L10n.onboarding("paywall.unlock.sessions.detail", defaultValue: "Log sets, RPE, swaps, and finishes so your plan keeps adapting instead of going stale.")
            ),
            PaywallUnlock(
                assetName: "badge_art_proof_10",
                title: L10n.onboarding("paywall.unlock.profile.title", defaultValue: "A character card that changes"),
                detail: L10n.onboarding("paywall.unlock.profile.detail", defaultValue: "Your Build Hex, milestones, streaks, and rank path start moving from Day Zero.")
            ),
            PaywallUnlock(
                assetName: "badge_art_first_scan",
                title: L10n.onboarding("paywall.unlock.scan.title", defaultValue: "Monthly evolution scans"),
                detail: L10n.onboarding("paywall.unlock.scan.detail", defaultValue: "Return to the scanner, compare the work, and make the next arc more specific.")
            )
        ]
    }

    private func featureRow(_ unlock: PaywallUnlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            OnboardingAssetGlyph(
                assetName: unlock.assetName,
                tint: Color.unbound.impact,
                size: 32,
                imagePadding: 5,
                shape: .hexagon
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(unlock.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(unlock.detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private var climberProof: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.onboarding("paywall.climbers.title", defaultValue: "OTHERS CLIMBED"))
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.7)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                Text(L10n.onboarding("paywall.climbers.beta", defaultValue: "BETA LOGS"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            HStack(spacing: 9) {
                climberStat(name: "KAI", move: "INIT -> MAS", detail: "28 sessions")
                climberStat(name: "MASON", move: "INIT -> VET", detail: "21d streak")
                climberStat(name: "JALEN", move: "INIT -> FORG", detail: "Arc 1 clear")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.22), lineWidth: 1)
        )
    }

    private func climberStat(name: String, move: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(move)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.impact)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var pathPreview: some View {
        ZStack(alignment: .bottomLeading) {
            Image("onboarding_path_protocol_dossier")
                .resizable()
                .scaledToFill()
                .frame(height: 174)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.onboarding("paywall.pathPreview.eyebrow", defaultValue: "BEHIND THE PAYWALL"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.accent)
                Text(L10n.onboarding("paywall.pathPreview.title", defaultValue: "Your calibration week unlocks first."))
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.18), radius: 16)
    }

    // MARK: CTA

    private var bottomPurchaseTray: some View {
        VStack(spacing: 10) {
            ctaSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.9),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    Color.unbound.accent.opacity(0.26),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1)
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 8) {
            SubscriptionPackagePicker(
                placement: AppConstants.Paywall.hardGate,
                ctaTitle: L10n.onboarding("paywall.subscribeCTA", defaultValue: "Start my first arc"),
                showsPitch: false,
                maxVisiblePackages: 2,
                onPurchased: onUnlock
            )

            Text(L10n.onboarding("paywall.disclaimer", defaultValue: "Start today. Cancel anytime. Checkout is handled securely by Apple."))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .multilineTextAlignment(.center)

            RestorePurchasesButton()
                .padding(.top, 8)

            #if DEBUG
            Button {
                DevFlags.shared.unlockAllFeatures = true
                onUnlock()
            } label: {
                Text(L10n.onboarding("paywall.devUnlock", defaultValue: "DEV · Unlock simulator"))
                    .font(Font.unbound.monoS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.impact)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            #endif
        }
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
}

private struct PaywallUnlock: Identifiable {
    let id = UUID()
    let assetName: String
    let title: String
    let detail: String
}

// MARK: - ProtocolPreviewBackdrop
//
// The blurred content behind the paywall — renders a fake protocol preview
// so the paywall feels like it's blocking a real thing.

private struct ProtocolPreviewBackdrop: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { i in
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.onboardingFormat("paywall.preview.week", defaultValue: "WEEK %d", i + 1))
                            .font(Font.unbound.captionS)
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(L10n.onboardingFormat("paywall.preview.workout", defaultValue: "Upper body · %d min", 45 + i * 5))
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(L10n.onboarding("paywall.preview.exercises", defaultValue: "Bench · Row · Press · Curl · Core"))
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    Spacer()
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.unbound.surface)
                )
            }
        }
        .padding(20)
    }
}
