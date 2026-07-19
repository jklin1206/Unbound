// UNBOUNDTests/Services/Auth/RootRouterTests.swift
import XCTest
@testable import UNBOUND

/// Locks the top-level routing decision (`App/RootRoute.swift`) across the full
/// permutation matrix of (checkingAuth, onboardingCompleted, isCloudLinked,
/// deferralActive, forceAuthScreen). The offline escape hatch means an onboarded,
/// not-cloud-linked user must reach the main app when they have deferred — that
/// is the behavior this suite protects from regressing back into a hard wall.
final class RootRouterTests: XCTestCase {

    private func route(
        checking: Bool = false,
        onboarded: Bool = true,
        linked: Bool = false,
        deferred: Bool = false,
        forceAuth: Bool = false
    ) -> RootRoute {
        RootRouter.route(
            isCheckingAuth: checking,
            onboardingCompleted: onboarded,
            isCloudLinked: linked,
            deferralActive: deferred,
            forceAuthScreen: forceAuth
        )
    }

    // MARK: - Loading wins first

    func testStillCheckingAuthShowsLoadingRegardlessOfEverythingElse() {
        XCTAssertEqual(route(checking: true, onboarded: false), .loading)
        XCTAssertEqual(route(checking: true, onboarded: true, linked: true), .loading)
        XCTAssertEqual(route(checking: true, deferred: true), .loading)
    }

    // MARK: - DEBUG review hook outranks everything

    // The force flag exists to render the wall on ANY dev state (even signed-in),
    // so it must beat loading, onboarding, and a live session.
    func testForceAuthHookAlwaysShowsAuth() {
        XCTAssertEqual(route(forceAuth: true), .auth)
        XCTAssertEqual(route(checking: true, forceAuth: true), .auth)
        XCTAssertEqual(route(onboarded: false, forceAuth: true), .auth)
        XCTAssertEqual(route(linked: true, forceAuth: true), .auth)
        XCTAssertEqual(route(deferred: true, forceAuth: true), .auth)
    }

    // MARK: - Onboarding gate

    func testNotOnboardedShowsOnboarding() {
        XCTAssertEqual(route(onboarded: false), .onboarding)
        // Even a (spurious) deferral cannot skip onboarding.
        XCTAssertEqual(route(onboarded: false, deferred: true), .onboarding)
    }

    // MARK: - A real cloud session always wins

    func testCloudLinkedGoesToMain() {
        XCTAssertEqual(route(linked: true), .main)
        // Deferral is irrelevant once linked.
        XCTAssertEqual(route(linked: true, deferred: false), .main)
        XCTAssertEqual(route(linked: true, deferred: true), .main)
    }

    // MARK: - The wall, and the escape hatch

    func testOnboardedNotLinkedNoDeferralShowsAuthWall() {
        XCTAssertEqual(route(linked: false, deferred: false), .auth)
    }

    func testOnboardedNotLinkedWithActiveDeferralGoesToMain() {
        // The core fix: a deferred, not-yet-re-prompted user is NOT walled out.
        XCTAssertEqual(route(linked: false, deferred: true), .main)
    }

    // MARK: - Re-prompt: expired deferral falls back to the wall

    func testExpiredDeferralFallsBackToAuthWall() {
        // deferralActive == false models the re-prompt window having elapsed.
        XCTAssertEqual(route(linked: false, deferred: false), .auth)
    }

    // MARK: - DEBUG review hook

    func testForceAuthOverridesAnActiveDeferral() {
        // The screenshot hook must show the wall even if a lingering deferral
        // would otherwise skip it.
        XCTAssertEqual(route(linked: false, deferred: true, forceAuth: true), .auth)
    }

    func testForceAuthWithNoDeferralStillShowsAuthWall() {
        XCTAssertEqual(route(linked: false, deferred: false, forceAuth: true), .auth)
    }
}
