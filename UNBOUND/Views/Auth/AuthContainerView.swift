import SwiftUI

struct AuthContainerView: View {
    @EnvironmentObject private var services: ServiceContainer

    // Escape hatch: invoked when the user taps "continue for now". RootView wires
    // this to record an offline deferral and route into the main app. Defaults to
    // a no-op so isolated hosts (the `-authScreenDemo` harness, previews) can still
    // render the screen — and the affordance — without any routing.
    var onContinueWithoutAccount: () -> Void = {}

    var body: some View {
        AuthContainerContentView(
            auth: services.auth,
            user: services.user,
            analytics: services.analytics,
            onContinueWithoutAccount: onContinueWithoutAccount
        )
        .id(ObjectIdentifier(services))
    }
}

private struct AuthContainerContentView: View {
    @StateObject private var viewModel: AuthViewModel
    private let onContinueWithoutAccount: () -> Void

    init(
        auth: any AuthServiceProtocol,
        user: any UserServiceProtocol,
        analytics: any AnalyticsServiceProtocol,
        onContinueWithoutAccount: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(
            auth: auth,
            user: user,
            analytics: analytics
        ))
        self.onContinueWithoutAccount = onContinueWithoutAccount
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            // Reuse the onboarding atmosphere (god-ray glow + drifting embers +
            // vignette) so this screen — the tail of the onboarding → first-use
            // flow — feels alive and continuous with the steps before it rather
            // than a flat black wall. Slightly elevated intensity to match the
            // late-onboarding dial.
            OnboardingAtmosphere(intensity: 1.15)

            ScrollView {
                VStack(spacing: 0) {
                    // "Protect your progress" moment — a shield motif over the
                    // headline + supporting line. The user reaches this right
                    // after the paywall, so the framing is about safeguarding the
                    // training they just committed to, not a generic login wall.
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.unbound.accent.opacity(0.12))
                                .frame(width: 84, height: 84)
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(Color.unbound.accent)
                                .shadow(color: Color.unbound.accent.opacity(0.4), radius: 14)
                        }

                        VStack(spacing: 8) {
                            Text(L10n.string(.authProtectTitle, defaultValue: "Protect your progress"))
                                .font(.headline(28))
                                .foregroundColor(Color.unbound.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(L10n.string(.authProtectBody, defaultValue: "Save your training to your account so it's backed up and follows you to any device."))
                                .font(.bodyMedium(15))
                                .foregroundColor(Color.unbound.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 64)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 40)

                    VStack(spacing: 12) {
                        // Apple first (Apple's guideline 4.8 requires it to be at
                        // least as prominent as other sign-in options).
                        AppleSignInButton {
                            Task { await viewModel.signInWithApple() }
                        }

                        // Google
                        GoogleSignInButton {
                            Task { await viewModel.signInWithGoogle() }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption(13))
                                .foregroundColor(Color.unbound.alert)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }

                        // Divider
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.unbound.surfaceElevated)
                                .frame(height: 1)

                            Text(L10n.string(.authEmailDivider, defaultValue: "or continue with email"))
                                .font(.caption(13))
                                .foregroundColor(Color.unbound.textTertiary)
                                .fixedSize()

                            Rectangle()
                                .fill(Color.unbound.surfaceElevated)
                                .frame(height: 1)
                        }
                        .padding(.top, 4)

                        // Email auth
                        EmailAuthView(viewModel: viewModel)
                    }
                    .padding(.horizontal, 24)

                    // Quiet escape hatch. Deliberately tertiary — a text-style
                    // button, no fill, below the providers — so signing in stays
                    // the obvious path. It exists so a network outage right after
                    // payment can't wall a paying customer out: progress is kept
                    // locally until they link (see the Settings > Account row).
                    VStack(spacing: 6) {
                        Button {
                            onContinueWithoutAccount()
                        } label: {
                            Text(L10n.string(.authDeferContinue, defaultValue: "Not now - continue without an account"))
                                .font(.bodyMedium(14))
                                .foregroundColor(Color.unbound.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.plain)

                        Text(L10n.string(.authDeferNote, defaultValue: "Your progress stays saved on this device until you link an account."))
                            .font(.caption(12))
                            .foregroundColor(Color.unbound.textTertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 28)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)

                    // Terms / privacy
                    VStack(spacing: 4) {
                        Text(L10n.string(.authLegalPrefix, defaultValue: "By continuing, you agree to our"))
                            .font(.caption(12))
                            .foregroundColor(Color.unbound.textTertiary)

                        HStack(spacing: 4) {
                            Link(L10n.string(.legalTermsOfService, defaultValue: "Terms of Service"), destination: AppConstants.Legal.termsURL)
                            Text(L10n.string(.authLegalAnd, defaultValue: "and"))
                            Link(L10n.string(.legalPrivacyPolicy, defaultValue: "Privacy Policy"), destination: AppConstants.Legal.privacyURL)
                        }
                        .font(.caption(12))
                        .foregroundColor(Color.unbound.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

#Preview {
    AuthContainerView()
        .environmentObject(ServiceContainer.mock)
}
