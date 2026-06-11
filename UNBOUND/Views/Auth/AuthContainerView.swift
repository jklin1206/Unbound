import SwiftUI

struct AuthContainerView: View {
    @EnvironmentObject private var services: ServiceContainer

    var body: some View {
        AuthContainerContentView(
            auth: services.auth,
            user: services.user,
            analytics: services.analytics
        )
        .id(ObjectIdentifier(services))
    }
}

private struct AuthContainerContentView: View {
    @StateObject private var viewModel: AuthViewModel

    init(
        auth: any AuthServiceProtocol,
        user: any UserServiceProtocol,
        analytics: any AnalyticsServiceProtocol
    ) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(
            auth: auth,
            user: user,
            analytics: analytics
        ))
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo / title area
                    VStack(spacing: 8) {
                        Text(L10n.string(.appName, defaultValue: "UNBOUND"))
                            .font(.headline(40))
                            .foregroundColor(Color.unbound.textPrimary)
                            .tracking(4)

                        Text(L10n.string(.authSignInSubtitle, defaultValue: "Sign in to back up your progress"))
                            .font(.bodyMedium(16))
                            .foregroundColor(Color.unbound.textSecondary)
                    }
                    .padding(.top, 72)
                    .padding(.bottom, 48)

                    VStack(spacing: 16) {
                        // Apple Sign-In
                        AppleSignInButton {
                            Task { await viewModel.signInWithApple() }
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

                        // Email auth
                        EmailAuthView(viewModel: viewModel)
                    }
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
