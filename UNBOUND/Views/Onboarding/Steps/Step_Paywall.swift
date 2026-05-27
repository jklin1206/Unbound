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
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            Image("onboarding_path_open_gate")
                .resizable()
                .scaledToFill()
                .opacity(0.46)
                .blur(radius: 3)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.54),
                    Color.unbound.bg.opacity(0.86),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(pulse ? 0.34 : 0.18),
                    Color.clear
                ],
                center: .top,
                startRadius: 30,
                endRadius: 460
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    Spacer().frame(height: 14)

                    header
                    transformationPanel

                    Spacer().frame(height: 440)
                }
                .padding(.horizontal, 20)
            }

            VStack(spacing: 0) {
                Spacer()
                bottomPurchaseTray
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .opacity(hasAnimated ? 1 : 0)
        .onAppear {
            services.analytics.track(.paywallViewed(placement: AppConstants.Paywall.hardGate))
            withAnimation(.easeOut(duration: 0.4)) { hasAnimated = true }
            pulse = true
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(L10n.onboarding("paywall.kicker", defaultValue: "THE GATE IS OPEN"))
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
            }
            .foregroundStyle(Color.unbound.impact)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.unbound.impact.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Color.unbound.impact.opacity(0.35), lineWidth: 1))

            Text(L10n.onboarding("paywall.title", defaultValue: "Become the version that keeps showing up."))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: Color.unbound.accent.opacity(0.42), radius: 18)

            Text(L10n.onboarding("paywall.subtitle", defaultValue: "Unlock your first block, recovery targets, progress profile, and the feedback loop that makes training feel worth coming back to."))
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Transformation

    private var transformationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                paywallSeal

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.onboarding("paywall.panel.title", defaultValue: "Your first arc is ready."))
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)

                    Text(L10n.onboarding("paywall.panel.subtitle", defaultValue: "Start with a four-week block that turns training, recovery, and visible progress into one loop."))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                compactUnlock(icon: "calendar.badge.clock", text: "First 4-week training arc")
                compactUnlock(icon: "moon.stars.fill", text: "Recovery and sleep targets")
                compactUnlock(icon: "hexagon.fill", text: "Build Hex, logs, and profile proof")
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
        ZStack {
            Circle()
                .fill(Color.unbound.impact.opacity(0.16))
            Circle()
                .strokeBorder(Color.unbound.impact.opacity(0.45), lineWidth: 1)
            Image(systemName: "lock.open.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.unbound.impact)
                .shadow(color: Color.unbound.impact.opacity(0.6), radius: 12)
        }
        .frame(width: 58, height: 58)
    }

    private func compactUnlock(icon: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.unbound.impact)
                .frame(width: 16)
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
                icon: "calendar.badge.clock",
                title: L10n.onboarding("paywall.unlock.program.title", defaultValue: "Your first block"),
                detail: L10n.onboarding("paywall.unlock.program.detail", defaultValue: "Workouts built from your goals, equipment, schedule, and starting point.")
            ),
            PaywallUnlock(
                icon: "figure.strengthtraining.traditional",
                title: L10n.onboarding("paywall.unlock.sessions.title", defaultValue: "A loop that keeps moving"),
                detail: L10n.onboarding("paywall.unlock.sessions.detail", defaultValue: "Log sets, RPE, swaps, and finishes so every session feeds the next.")
            ),
            PaywallUnlock(
                icon: "hexagon.fill",
                title: L10n.onboarding("paywall.unlock.profile.title", defaultValue: "Visible proof"),
                detail: L10n.onboarding("paywall.unlock.profile.detail", defaultValue: "Your Build Hex, logs, milestones, and rank path start changing from Day Zero.")
            )
        ]
    }

    private func featureRow(_ unlock: PaywallUnlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: unlock.icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.unbound.impact)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.unbound.impact.opacity(0.12)))

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
    let icon: String
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
