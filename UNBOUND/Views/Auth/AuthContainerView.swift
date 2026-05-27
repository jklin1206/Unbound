import SwiftUI

struct AuthContainerView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var viewModel: AuthViewModel

    init() {
        // Temporary placeholder — real VM built from services in task 12 pattern
        _viewModel = StateObject(wrappedValue: AuthViewModel(
            auth: AuthService.shared,
            user: UserService.shared,
            analytics: AnalyticsService.shared
        ))
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo / title area
                    VStack(spacing: 8) {
                        Text(L10n.string(.appName, defaultValue: "UNBOUND"))
                            .font(.headline(40))
                            .foregroundColor(.theme.textPrimary)
                            .tracking(4)

                        Text(L10n.string(.authSignInSubtitle, defaultValue: "Sign in to back up your progress"))
                            .font(.bodyMedium(16))
                            .foregroundColor(.theme.textSecondary)
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
                                .fill(Color.theme.surfaceLight)
                                .frame(height: 1)

                            Text(L10n.string(.authEmailDivider, defaultValue: "or continue with email"))
                                .font(.caption(13))
                                .foregroundColor(.theme.textMuted)
                                .fixedSize()

                            Rectangle()
                                .fill(Color.theme.surfaceLight)
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
                            .foregroundColor(.theme.textMuted)

                        HStack(spacing: 4) {
                            Link(L10n.string(.legalTermsOfService, defaultValue: "Terms of Service"), destination: AppConstants.Legal.termsURL)
                            Text(L10n.string(.authLegalAnd, defaultValue: "and"))
                            Link(L10n.string(.legalPrivacyPolicy, defaultValue: "Privacy Policy"), destination: AppConstants.Legal.privacyURL)
                        }
                        .font(.caption(12))
                        .foregroundColor(.theme.textSecondary)
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
