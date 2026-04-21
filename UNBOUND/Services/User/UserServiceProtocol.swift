protocol UserServiceProtocol: Sendable {
    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile
    func fetchProfile(userId: String) async throws -> UserProfile
    func updateProfile(userId: String, fields: [String: Any]) async throws
    func deleteUserData(userId: String) async throws
}
