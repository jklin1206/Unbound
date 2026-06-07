import XCTest
@testable import UNBOUND

final class RankTrialUserServiceStub: UserServiceProtocol, @unchecked Sendable {
    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
        profile(userId: userId, email: email)
    }

    func fetchProfile(userId: String) async throws -> UserProfile {
        profile(userId: userId)
    }

    func updateProfile(userId: String, fields: [String: Any]) async throws {}
    func deleteUserData(userId: String) async throws {}

    private func profile(userId: String, email: String? = nil) -> UserProfile {
        var profile = UserProfile(
            id: userId,
            email: email,
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0,
            weightKg: 100
        )
        profile.equipment = [.fullGym, .pullupBar, .homeWeights, .bands]
        return profile
    }
}
