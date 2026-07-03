import Foundation
import Combine

final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    private let subject = CurrentValueSubject<String?, Never>("mock-user-123")
    var currentUserId: String? { subject.value }
    var isAuthenticated: Bool { currentUserId != nil }
    var isCloudLinked: Bool { get async { currentUserId != nil } }
    var authStatePublisher: AnyPublisher<String?, Never> { subject.eraseToAnyPublisher() }

    func signInWithApple() async throws -> String { "mock-user-123" }
    func signInWithGoogle() async throws -> String { "mock-user-123" }
    func signInWithEmail(email: String, password: String) async throws -> String { "mock-user-123" }
    func createAccountWithEmail(email: String, password: String) async throws -> String { "mock-user-123" }
    func signOut() throws { subject.send(nil) }
    func deleteAccount() async throws { subject.send(nil) }
}
