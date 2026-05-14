#if DEBUG
import Foundation

// MARK: - PreviewUserService
//
// No-op UserService for SwiftUI #Preview use. Never hits Firestore.

final class PreviewUserService: UserServiceProtocol, @unchecked Sendable {
    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
        UserProfile(
            id: userId,
            email: email,
            displayName: nil,
            createdAt: Date(),
            onboardingCompleted: false,
            totalScans: 0,
            currentProgramId: nil,
            heightCm: nil,
            weightKg: nil,
            age: nil,
            biologicalSex: nil
        )
    }

    func fetchProfile(userId: String) async throws -> UserProfile {
        try await createUserIfNeeded(userId: userId, email: nil)
    }

    func updateProfile(userId: String, fields: [String: Any]) async throws {
        // no-op for previews
    }

    func deleteUserData(userId: String) async throws {
        // no-op
    }
}
#endif
