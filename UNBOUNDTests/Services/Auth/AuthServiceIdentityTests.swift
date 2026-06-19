import XCTest
@testable import UNBOUND

/// Locks the identity-resolution contract that the streak (and every other
/// per-user record) is keyed on. A drift here is what made the streak "lose its
/// place": an involuntary sign-out silently fell back to the stale anonymous id.
final class AuthServiceIdentityTests: XCTestCase {
    private let suiteName = "AuthServiceIdentityTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_resolveUserId_prefersCachedOverLegacy() {
        AuthService.seedIdentityForTesting(
            cachedUserId: "supabase-uid",
            legacyUserId: "anon-uid",
            in: defaults
        )
        XCTAssertEqual(AuthService.resolveUserId(defaults: defaults), "supabase-uid")
    }

    func test_resolveUserId_fallsBackToLegacyWhenNoCache() {
        AuthService.seedIdentityForTesting(
            cachedUserId: nil,
            legacyUserId: "anon-uid",
            in: defaults
        )
        XCTAssertEqual(AuthService.resolveUserId(defaults: defaults), "anon-uid")
    }

    func test_involuntarySignOut_dropsLegacyId_forSignedInUser() {
        // A migrated/signed-in user has both a cached id and a legacy id on disk.
        AuthService.seedIdentityForTesting(
            cachedUserId: "supabase-uid",
            legacyUserId: "anon-uid",
            in: defaults
        )

        let hadCachedSession = AuthService.clearSessionOnRemoteSignOut(defaults: defaults)

        XCTAssertTrue(hadCachedSession)
        // Identity resolves to nil → the app routes to re-auth (which restores the
        // real id + streak) instead of flapping onto the stale anonymous run.
        XCTAssertNil(AuthService.resolveUserId(defaults: defaults))
    }

    func test_involuntarySignOut_preservesLegacyId_forNeverSignedInUser() {
        // Pure anonymous user: only a legacy id, never had a Supabase session.
        AuthService.seedIdentityForTesting(
            cachedUserId: nil,
            legacyUserId: "anon-uid",
            in: defaults
        )

        let hadCachedSession = AuthService.clearSessionOnRemoteSignOut(defaults: defaults)

        XCTAssertFalse(hadCachedSession)
        // A spurious sign-out event must not strand their local-only progress.
        XCTAssertEqual(AuthService.resolveUserId(defaults: defaults), "anon-uid")
    }
}
