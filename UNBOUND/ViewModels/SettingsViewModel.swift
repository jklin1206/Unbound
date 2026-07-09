import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var hasActiveSubscription = false
    @Published var isLoading = false
    @Published var showDeleteConfirmation = false
    @Published var deleteConfirmationText = ""
    @Published var errorMessage: String?
    /// Post-restore outcome ("restored" vs "no subscription found") surfaced
    /// as its own settings alert; failures keep flowing through `errorMessage`.
    @Published var restoreMessage: String?
    /// True when a real Supabase (Apple) session backs the account, false for
    /// the anonymous local-UUID identity. Drives the Account section: connected
    /// accounts get Sign Out, anonymous ones get the Sign in with Apple CTA.
    @Published var isCloudLinked = false

    private let services: ServiceContainer
    private var cancellables = Set<AnyCancellable>()

    init(services: ServiceContainer) {
        self.services = services

        services.subscription.subscriptionStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasActiveSubscription)
    }

    func loadProfile() async {
        isCloudLinked = await UnboundSupabase.isSignedIn
        guard let userId = services.auth.currentUserId else { return }
        do {
            userProfile = try await services.user.fetchProfile(userId: userId)
        } catch {
            #if DEBUG
            if userId == "dev-player",
               let localProfile: UserProfile = try? await DatabaseService.shared.read(collection: "users", documentId: userId) {
                userProfile = localProfile
                return
            }
            #endif
            errorMessage = "Failed to load profile"
        }
    }

    func signOut() {
        do {
            try services.auth.signOut()
        } catch {
            errorMessage = "Failed to sign out"
        }
    }

    /// Connects the anonymous local account to Apple/Supabase. On success the
    /// one-time local→cloud migration kicks off inside AuthService; the section
    /// re-renders into its connected state.
    func signInWithApple() async {
        isLoading = true
        do {
            _ = try await services.auth.signInWithApple()
            await loadProfile()
        } catch {
            // Dismissing the Apple sheet is a deliberate choice, not a failure —
            // AuthService surfaces it as AppError.authCanceled.
            if case AppError.authCanceled = error {
                // quiet
            } else {
                errorMessage = "Sign in failed. Please try again."
            }
        }
        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        do {
            // Mirror RestorePurchasesButton: every outcome gets visible
            // feedback, so a silent tap never leaves the user guessing.
            let hasActive = try await services.subscription.restorePurchases()
            restoreMessage = hasActive
                ? "Purchases restored. Your subscription is active."
                : "No active subscription found."
        } catch {
            errorMessage = "Failed to restore purchases"
        }
        isLoading = false
    }

    func deleteAccount() async {
        guard deleteConfirmationText.lowercased() == "delete" else {
            errorMessage = "Please type 'delete' to confirm"
            return
        }
        guard let userId = services.auth.currentUserId else { return }

        isLoading = true
        do {
            try? await services.user.deleteUserData(userId: userId)
            try? await services.storage.deleteUserPhotos(userId: userId)
            try await services.auth.deleteAccount()
            services.analytics.track(.accountDeleted)
        } catch {
            errorMessage = "Failed to delete account. Please contact support."
        }
        isLoading = false
    }
}
