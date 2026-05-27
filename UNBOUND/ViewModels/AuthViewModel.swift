import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isSignUp = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let auth: any AuthServiceProtocol
    private let user: any UserServiceProtocol
    private let analytics: any AnalyticsServiceProtocol

    init(auth: any AuthServiceProtocol, user: any UserServiceProtocol, analytics: any AnalyticsServiceProtocol) {
        self.auth = auth
        self.user = user
        self.analytics = analytics
    }

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        analytics.track(.signInStarted(method: "apple"))

        do {
            let userId = try await auth.signInWithApple()
            _ = try await user.createUserIfNeeded(userId: userId, email: nil)
            #if DEBUG
            DevFlags.shared.unlockAllFeatures = true
            #endif
            analytics.track(.signInCompleted(method: "apple"))
        } catch {
            errorMessage = error.localizedDescription
            analytics.track(.signInFailed(method: "apple", error: error.localizedDescription))
        }

        isLoading = false
    }

    func signInWithEmail() async {
        isLoading = true
        errorMessage = nil
        let method = isSignUp ? "email_signup" : "email"
        analytics.track(.signInStarted(method: method))

        do {
            let userId: String
            if isSignUp {
                userId = try await auth.createAccountWithEmail(email: email, password: password)
            } else {
                userId = try await auth.signInWithEmail(email: email, password: password)
            }
            _ = try await user.createUserIfNeeded(userId: userId, email: email)
            #if DEBUG
            DevFlags.shared.unlockAllFeatures = true
            #endif
            analytics.track(.signInCompleted(method: method))
        } catch {
            errorMessage = error.localizedDescription
            analytics.track(.signInFailed(method: method, error: error.localizedDescription))
        }

        isLoading = false
    }
}
