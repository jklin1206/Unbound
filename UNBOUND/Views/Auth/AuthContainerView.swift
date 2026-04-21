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
                        Text("UNBOUND")
                            .font(.headline(40))
                            .foregroundColor(.theme.textPrimary)
                            .tracking(4)

                        Text("Sign in to back up your progress")
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

                            Text("or continue with email")
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
                        Text("By continuing, you agree to our")
                            .font(.caption(12))
                            .foregroundColor(.theme.textMuted)

                        HStack(spacing: 4) {
                            Link("Terms of Service", destination: URL(string: "https://unboundapp.com/terms")!)
                            Text("and")
                            Link("Privacy Policy", destination: URL(string: "https://unboundapp.com/privacy")!)
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
