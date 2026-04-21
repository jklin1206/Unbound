import SwiftUI

struct EmailAuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Email field
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.bodyMedium(16))
                .foregroundColor(.theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(viewModel.isLoading)

            // Password field
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .font(.bodyMedium(16))
                .foregroundColor(.theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(viewModel.isLoading)

            // Error message
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption(13))
                    Text(errorMessage)
                        .font(.caption(13))
                }
                .foregroundColor(.theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            // Sign In / Create Account button
            GradientButton(
                title: viewModel.isSignUp ? "Create Account" : "Sign In",
                action: {
                    Task { await viewModel.signInWithEmail() }
                },
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.email.isEmpty || viewModel.password.isEmpty
            )

            // Toggle sign up / sign in
            Button {
                viewModel.isSignUp.toggle()
                viewModel.errorMessage = nil
            } label: {
                Text(viewModel.isSignUp
                     ? "Already have an account? Sign in"
                     : "Don't have an account? Create one")
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textSecondary)
            }
            .disabled(viewModel.isLoading)
        }
    }
}

#Preview {
    ZStack {
        Color.theme.background.ignoresSafeArea()
        EmailAuthView(viewModel: AuthViewModel(
            auth: MockAuthService(),
            user: UserService.shared,
            analytics: AnalyticsService.shared
        ))
        .padding(.horizontal, 24)
    }
}
