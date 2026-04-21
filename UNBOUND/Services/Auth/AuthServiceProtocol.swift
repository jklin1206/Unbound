import Foundation
import Combine

protocol AuthServiceProtocol: Sendable {
    var currentUserId: String? { get }
    var isAuthenticated: Bool { get }
    var authStatePublisher: AnyPublisher<String?, Never> { get }

    func signInWithApple() async throws -> String
    func signInWithEmail(email: String, password: String) async throws -> String
    func createAccountWithEmail(email: String, password: String) async throws -> String
    func signOut() throws
    func deleteAccount() async throws
}
