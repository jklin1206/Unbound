import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import Supabase

// MARK: - AuthService (Supabase-backed, Sign in with Apple)
//
// Phase 2 auth. Sign in with Apple → Supabase `signInWithIdToken(.apple, ...)`.
// Returns real Supabase UUIDs. `currentUserId` reads from UserDefaults cache
// (populated by the Supabase session listener) for synchronous access.
//
// Legacy local-UUID users: on first successful Apple sign-in, triggers a
// one-time background migration (see `LocalToSupabaseMigration`) that
// re-keys all local JSON docs from the old anonymous UUID to the new
// Supabase UID and pushes them to the cloud.
//
// Email/password is retained for parity with the original protocol but
// tunnels through Supabase's native email auth.

private let cachedUserIdKey = "unbound.supabase.cachedUserId"
private let legacyLocalUserIdKey = "unbound.localUserId"
#if DEBUG
private let debugUserIdOverrideKey = "unbound.debugUserIdOverride"
#endif

final class AuthService: NSObject, AuthServiceProtocol, @unchecked Sendable {
    static let shared = AuthService()
    private let logger = LoggingService.shared
    private let authStateSubject: CurrentValueSubject<String?, Never>

    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<String, Error>?
    private var authStateListenerTask: Task<Void, Never>?
    private var appleSignInController: ASAuthorizationController?

    // MARK: Protocol surface

    var currentUserId: String? {
        #if DEBUG
        if let debugUserId = UserDefaults.standard.string(forKey: debugUserIdOverrideKey) {
            return debugUserId
        }
        #endif
        return UserDefaults.standard.string(forKey: cachedUserIdKey)
            ?? UserDefaults.standard.string(forKey: legacyLocalUserIdKey)
    }

    var isAuthenticated: Bool { currentUserId != nil }

    var authStatePublisher: AnyPublisher<String?, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    private override init() {
        self.authStateSubject = CurrentValueSubject<String?, Never>(Self.initialUserId())
        super.init()
        startAuthStateListener()
    }

    private static func initialUserId() -> String? {
        #if DEBUG
        if let debugUserId = UserDefaults.standard.string(forKey: debugUserIdOverrideKey) {
            return debugUserId
        }
        #endif
        return UserDefaults.standard.string(forKey: cachedUserIdKey)
            ?? UserDefaults.standard.string(forKey: legacyLocalUserIdKey)
    }

    // MARK: Sign in with Apple

    func signInWithApple() async throws -> String {
        let nonce = randomNonceString()
        currentNonce = nonce

        return try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.appleSignInController = controller
            controller.performRequests()
        }
    }

    // MARK: Email / password (Supabase native)

    func signInWithEmail(email: String, password: String) async throws -> String {
        do {
            let session = try await UnboundSupabase.client.auth.signIn(email: email, password: password)
            let uid = session.user.id.uuidString
            cacheUserId(uid)
            logger.log("Email sign in successful", level: .info)
            return uid
        } catch {
            logger.log("Email sign in failed: \(error)", level: .error)
            throw AppError.authSignInFailed(underlying: error)
        }
    }

    func createAccountWithEmail(email: String, password: String) async throws -> String {
        do {
            let session = try await UnboundSupabase.client.auth.signUp(email: email, password: password)
            let uid = (session.user.id).uuidString
            cacheUserId(uid)
            logger.log("Email account created", level: .info)
            return uid
        } catch {
            logger.log("Email account creation failed: \(error)", level: .error)
            throw AppError.authSignInFailed(underlying: error)
        }
    }

    // MARK: Sign out / delete

    func signOut() throws {
        Task { try? await UnboundSupabase.client.auth.signOut() }
        Task { @MainActor in ProgramStore.shared.clear() }
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: debugUserIdOverrideKey)
        #endif
        UserDefaults.standard.removeObject(forKey: cachedUserIdKey)
        UserDefaults.standard.removeObject(forKey: legacyLocalUserIdKey)
        authStateSubject.send(nil)
        logger.log("Signed out", level: .info)
    }

    func deleteAccount() async throws {
        // Supabase row cascade handles most of it via FK ON DELETE CASCADE.
        // User deletion requires service-role — route through an Edge Function.
        // For V1, sign out and mark locally. Full delete is a V1.1 todo.
        try signOut()
    }

    // MARK: Back-compat — some call sites still invoke this

    func autoProvisionIfNeeded() {
        guard currentUserId == nil else { return }
        let uid = UUID().uuidString
        UserDefaults.standard.set(uid, forKey: legacyLocalUserIdKey)
        authStateSubject.send(uid)
        logger.log("Auto-provisioned anonymous user \(uid)", level: .info)
    }

    #if DEBUG
    func activateDevUser(id uid: String) {
        UserDefaults.standard.removeObject(forKey: cachedUserIdKey)
        UserDefaults.standard.set(uid, forKey: debugUserIdOverrideKey)
        UserDefaults.standard.set(uid, forKey: legacyLocalUserIdKey)
        authStateSubject.send(uid)
        logger.log("Activated debug user \(uid)", level: .info)
    }
    #endif

    // MARK: Apple sign-in result handler

    fileprivate func handleAppleIDCredential(
        _ credential: ASAuthorizationAppleIDCredential
    ) async {
        guard let nonce = currentNonce,
              let token = credential.identityToken,
              let idTokenString = String(data: token, encoding: .utf8) else {
            appleSignInContinuation?.resume(
                throwing: AppError.authSignInFailed(
                    underlying: NSError(domain: "AppleAuth", code: -1)
                )
            )
            appleSignInContinuation = nil
            return
        }

        do {
            let session = try await UnboundSupabase.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idTokenString,
                    nonce: nonce
                )
            )
            let uid = session.user.id.uuidString
            let legacyUID = UserDefaults.standard.string(forKey: legacyLocalUserIdKey)

            cacheUserId(uid)
            logger.log("Apple sign in successful", level: .info)

            // Kick off local → cloud migration in the background if the
            // user has pre-auth local data.
            if let legacyUID, legacyUID != uid {
                Task.detached { [weak self] in
                    await LocalToSupabaseMigration.migrate(from: legacyUID, to: uid)
                    self?.logger.log("Local → cloud migration complete", level: .info)
                }
            }

            appleSignInContinuation?.resume(returning: uid)
        } catch {
            logger.log("Supabase idToken auth failed: \(error)", level: .error)
            appleSignInContinuation?.resume(throwing: AppError.authSignInFailed(underlying: error))
        }
        appleSignInContinuation = nil
        appleSignInController = nil
    }

    // MARK: Auth state listener — keeps UserDefaults cache in sync with Supabase session

    private func startAuthStateListener() {
        authStateListenerTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in UnboundSupabase.client.auth.authStateChanges {
                switch event {
                case .signedIn, .tokenRefreshed:
                    // Fresh session by definition (sign-in just completed or a
                    // refresh just succeeded) — safe to cache.
                    if let uid = session?.user.id.uuidString {
                        self.cacheUserId(uid)
                    }
                case .initialSession:
                    // With emitLocalSessionAsInitialSession=true (see
                    // SupabaseClient.swift), this fires with the locally stored
                    // session even if it's expired. Only treat it as signed-in
                    // when still valid; an expired local session must NOT opt
                    // the user in — auto-refresh or explicit sign-in drives that.
                    if let session, !session.isExpired {
                        self.cacheUserId(session.user.id.uuidString)
                    }
                case .signedOut, .userDeleted:
                    UserDefaults.standard.removeObject(forKey: cachedUserIdKey)
                    self.authStateSubject.send(nil)
                default:
                    break
                }
            }
        }
    }

    private func cacheUserId(_ uid: String) {
        UserDefaults.standard.set(uid, forKey: cachedUserIdKey)
        authStateSubject.send(uid)
    }

    // MARK: Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleSignInContinuation?.resume(
                throwing: AppError.authSignInFailed(
                    underlying: NSError(domain: "AppleAuth", code: -2)
                )
            )
            appleSignInContinuation = nil
            return
        }
        Task { await self.handleAppleIDCredential(credential) }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        logger.log("Apple authorization failed: \(error)", level: .error)
        appleSignInContinuation?.resume(throwing: AppError.authSignInFailed(underlying: error))
        appleSignInContinuation = nil
        appleSignInController = nil
    }
}
