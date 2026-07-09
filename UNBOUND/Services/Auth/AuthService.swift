import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import Supabase
import GoogleSignIn
import UIKit

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
        Self.resolveUserId()
    }

    /// Single source of truth for identity resolution: debug override (DEBUG
    /// only) → cached Supabase UID → legacy anonymous UID. Used by both the
    /// synchronous `currentUserId` accessor and the initial-state seed so the
    /// two can never drift. `defaults` is injectable for unit tests.
    static func resolveUserId(defaults: UserDefaults = .standard) -> String? {
        #if DEBUG
        if let debugUserId = defaults.string(forKey: debugUserIdOverrideKey) {
            return debugUserId
        }
        #endif
        return defaults.string(forKey: cachedUserIdKey)
            ?? defaults.string(forKey: legacyLocalUserIdKey)
    }

    /// Clears identity on an *involuntary* sign-out (an expired/invalidated
    /// Supabase session surfacing as `.signedOut`/`.userDeleted`), as opposed to
    /// the deliberate `signOut()`.
    ///
    /// Critically, when the user had a cached (signed-in) session this also
    /// drops the legacy anonymous id. Otherwise `resolveUserId` falls back to
    /// that stale pre-auth identity, surfacing a *different* (usually zeroed)
    /// streak/profile until the next token refresh flips it back — the "streak
    /// keeps losing its place" flapping. Dropping it resolves identity to nil so
    /// the app routes to re-auth, which restores the real id and streak.
    ///
    /// A never-signed-in anonymous user (no cached id) keeps their legacy id, so
    /// a spurious event can't strand their local-only progress.
    /// Returns whether a cached session was present (i.e. the legacy id was dropped).
    @discardableResult
    static func clearSessionOnRemoteSignOut(defaults: UserDefaults = .standard) -> Bool {
        let hadCachedSession = defaults.string(forKey: cachedUserIdKey) != nil
        defaults.removeObject(forKey: cachedUserIdKey)
        if hadCachedSession {
            defaults.removeObject(forKey: legacyLocalUserIdKey)
        }
        return hadCachedSession
    }

    var isAuthenticated: Bool { currentUserId != nil }

    var isCloudLinked: Bool {
        get async {
            #if DEBUG
            // Dev builds run under a debug-override identity with no real Supabase
            // session; treat that as linked so the dev workflow and demo harnesses
            // aren't trapped on the forced-auth screen. Genuine-new-user runs
            // (`-genuineNewUser`) clear this override, so the real gate still shows.
            if UserDefaults.standard.string(forKey: debugUserIdOverrideKey) != nil {
                return true
            }
            #endif
            return await UnboundSupabase.isSignedIn
        }
    }

    var authStatePublisher: AnyPublisher<String?, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    private override init() {
        self.authStateSubject = CurrentValueSubject<String?, Never>(Self.initialUserId())
        super.init()
        startAuthStateListener()
    }

    private static func initialUserId() -> String? {
        resolveUserId()
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

    // MARK: Sign in with Google (native, Supabase idToken exchange)

    func signInWithGoogle() async throws -> String {
        let result: GIDSignInResult
        do {
            result = try await presentGoogleSignIn()
        } catch {
            // GoogleSignIn reports user-cancel as kGIDSignInErrorCodeCanceled
            // (-5) in kGIDSignInErrorDomain. Match on the raw NSError so we don't
            // depend on how the ObjC NS_ERROR_ENUM bridges case names into Swift.
            let nsError = error as NSError
            if nsError.domain == kGIDSignInErrorDomain, nsError.code == -5 {
                logger.log("Google sign-in cancelled by user", level: .info)
                throw AppError.authCanceled
            }
            logger.log("Google sign in failed: \(error)", level: .error)
            throw AppError.from(authError: error)
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AppError.authSignInFailed(
                underlying: NSError(domain: "GoogleAuth", code: -1)
            )
        }

        do {
            let session = try await UnboundSupabase.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
            )
            logger.log("Google sign in successful", level: .info)
            return adoptSupabaseSession(session)
        } catch {
            logger.log("Google sign in (idToken exchange) failed: \(error)", level: .error)
            throw AppError.from(authError: error)
        }
    }

    /// Presents the Google consent sheet on the key window's top-most view
    /// controller. `@MainActor` because it reads the window hierarchy and drives
    /// UIKit presentation.
    @MainActor
    private func presentGoogleSignIn() async throws -> GIDSignInResult {
        guard let presenting = Self.topViewController() else {
            throw AppError.authSignInFailed(
                underlying: NSError(domain: "GoogleAuth", code: -3)
            )
        }
        return try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Shared tail of every OIDC sign-in (Apple, Google): cache the new uid and,
    /// if the user had pre-auth local data under a different (anonymous) uid,
    /// kick off the local → cloud migration in the background. Returns the uid.
    private func adoptSupabaseSession(_ session: Session) -> String {
        let uid = session.user.id.uuidString
        let legacyUID = UserDefaults.standard.string(forKey: legacyLocalUserIdKey)
        cacheUserId(uid)
        if let legacyUID, legacyUID != uid {
            Task.detached { [weak self] in
                await LocalToSupabaseMigration.migrate(from: legacyUID, to: uid)
                self?.logger.log("Local → cloud migration complete", level: .info)
            }
        }
        return uid
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
            throw AppError.from(authError: error)
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
            throw AppError.from(authError: error)
        }
    }

    // MARK: Sign out / delete

    func signOut() throws {
        AnalyticsService.shared.track(.signOut)
        AnalyticsService.shared.reset()
        Task { try? await UnboundSupabase.client.auth.signOut() }
        Task { try? await SubscriptionService.shared.logout() }
        Task { @MainActor in ProgramStore.shared.clear() }
        DevFlags.shared.unlockAllFeatures = false
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: debugUserIdOverrideKey)
        #endif
        UserDefaults.standard.removeObject(forKey: cachedUserIdKey)
        UserDefaults.standard.removeObject(forKey: legacyLocalUserIdKey)
        authStateSubject.send(nil)
        logger.log("Signed out", level: .info)
    }

    func deleteAccount() async throws {
        guard await UnboundSupabase.isSignedIn else {
            try signOut()
            return
        }

        // Capture the live UID and any legacy/local UUID BEFORE sign-out clears
        // UserDefaults. The server purges the legacy UID's Storage directory;
        // the client purges its on-disk photo root. Without this, a migrated
        // user's old-UUID photos would survive account deletion.
        let liveUserId = currentUserId
        let legacyUserId = UserDefaults.standard.string(forKey: legacyLocalUserIdKey)

        struct DeleteAccountBody: Encodable {
            let confirm: Bool
            let legacy_user_id: String?
        }
        struct DeleteAccountResponse: Decodable {
            let deleted: Bool
        }

        do {
            let response: DeleteAccountResponse = try await UnboundSupabase.client.functions
                .invoke(
                    "delete_account",
                    options: FunctionInvokeOptions(
                        body: DeleteAccountBody(
                            confirm: true,
                            legacy_user_id: (legacyUserId != liveUserId) ? legacyUserId : nil
                        )
                    )
                )
            guard response.deleted else {
                throw AppError.authAccountDeletionFailed(
                    underlying: NSError(
                        domain: "AuthService",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Delete account function returned false"]
                    )
                )
            }
        } catch {
            logger.log("Delete account failed: \(error)", level: .error)
            throw AppError.authAccountDeletionFailed(underlying: error)
        }

        // Tear down on-disk photo roots for the live UID and any legacy UID.
        // Best-effort: a local-FS failure must not block the (already
        // server-confirmed) deletion or the subsequent sign-out.
        let photoRootIds = [liveUserId, legacyUserId].compactMap { $0 }
        if !photoRootIds.isEmpty {
            try? await StorageService.shared.deleteAllPhotoRoots(userIds: photoRootIds)
        }

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
            logger.log("Apple sign in successful", level: .info)
            // Cache uid + kick off local → cloud migration if the user has
            // pre-auth local data (shared with the Google path).
            let uid = adoptSupabaseSession(session)
            appleSignInContinuation?.resume(returning: uid)
        } catch {
            logger.log("Supabase idToken auth failed: \(error)", level: .error)
            appleSignInContinuation?.resume(throwing: AppError.from(authError: error))
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
                    Self.clearSessionOnRemoteSignOut()
                    AnalyticsService.shared.reset()
                    self.authStateSubject.send(nil)
                default:
                    break
                }
            }
        }
    }

    private func cacheUserId(_ uid: String) {
        #if DEBUG
        if let debugUserId = UserDefaults.standard.string(forKey: debugUserIdOverrideKey) {
            // Debug override takes precedence on read (see getCachedUserId), so we
            // must NOT delete the real cached UID here — doing so permanently loses
            // the real session once the override is cleared. Just route to the debug
            // identity and leave the real cache intact.
            AnalyticsService.shared.identify(
                userId: debugUserId,
                traits: ["authState": "debugSignedIn"]
            )
            authStateSubject.send(debugUserId)
            return
        }
        #endif
        UserDefaults.standard.set(uid, forKey: cachedUserIdKey)
        AnalyticsService.shared.identify(
            userId: uid,
            traits: ["authState": "signedIn"]
        )
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

#if DEBUG
extension AuthService {
    /// Test seam: seed identity keys into an isolated `UserDefaults` so unit
    /// tests can exercise `resolveUserId` / `clearSessionOnRemoteSignOut`
    /// without reaching the file-private key constants.
    static func seedIdentityForTesting(
        cachedUserId: String?,
        legacyUserId: String?,
        in defaults: UserDefaults
    ) {
        if let cachedUserId {
            defaults.set(cachedUserId, forKey: cachedUserIdKey)
        } else {
            defaults.removeObject(forKey: cachedUserIdKey)
        }
        if let legacyUserId {
            defaults.set(legacyUserId, forKey: legacyLocalUserIdKey)
        } else {
            defaults.removeObject(forKey: legacyLocalUserIdKey)
        }
    }
}
#endif

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
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            // The user dismissed the Apple sheet — a deliberate choice, not a
            // failure. Surface it as authCanceled so the UI shows nothing.
            logger.log("Apple sign-in cancelled by user", level: .info)
            appleSignInContinuation?.resume(throwing: AppError.authCanceled)
        } else {
            logger.log("Apple authorization failed: \(error)", level: .error)
            appleSignInContinuation?.resume(throwing: AppError.from(authError: error))
        }
        appleSignInContinuation = nil
        appleSignInController = nil
    }
}
