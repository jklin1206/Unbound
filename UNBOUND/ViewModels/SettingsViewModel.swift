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

    private let services: ServiceContainer
    private var cancellables = Set<AnyCancellable>()

    init(services: ServiceContainer) {
        self.services = services

        services.subscription.subscriptionStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasActiveSubscription)
    }

    func loadProfile() async {
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

    func restorePurchases() async {
        isLoading = true
        do {
            _ = try await services.subscription.restorePurchases()
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
