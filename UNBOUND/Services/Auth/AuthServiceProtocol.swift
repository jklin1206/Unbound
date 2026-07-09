import Foundation
import Combine

protocol AuthServiceProtocol: Sendable {
    var currentUserId: String? { get }
    var isAuthenticated: Bool { get }
    /// True once the user has a real cloud session (Sign in with Apple/Google or
    /// email), as opposed to the pre-auth anonymous local UUID. Drives the forced
    /// "protect your progress" gate: a locally-provisioned anonymous user has a
    /// `currentUserId` but is NOT cloud-linked.
    var isCloudLinked: Bool { get async }
    var authStatePublisher: AnyPublisher<String?, Never> { get }

    func signInWithApple() async throws -> String
    func signInWithGoogle() async throws -> String
    func signInWithEmail(email: String, password: String) async throws -> String
    func createAccountWithEmail(email: String, password: String) async throws -> String
    func signOut() throws
    func deleteAccount() async throws
}
