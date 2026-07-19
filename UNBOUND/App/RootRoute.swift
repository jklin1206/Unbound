import Foundation

// MARK: - RootRoute
//
// The four top-level destinations RootView can resolve to. Extracted from
// RootView's inline branching so the decision is a pure, testable function:
// the branching now also has to weigh an offline auth deferral, which is easy
// to get subtly wrong across relaunch.

enum RootRoute: Equatable {
    /// Auth state is still resolving on launch.
    case loading
    /// Onboarding has not been completed.
    case onboarding
    /// The forced post-paywall "protect your progress" screen (now with a quiet
    /// escape hatch). Shown when onboarded + not cloud-linked + no active deferral.
    case auth
    /// The main app (HomeTabView). Reached on a real cloud session, or when an
    /// onboarded local user has an active offline deferral.
    case main
}

// MARK: - RootRouter

enum RootRouter {
    /// Resolve the top-level route. Pure: every input is a plain value so the full
    /// permutation matrix is unit-testable without UserDefaults or a live session.
    ///
    /// - Parameters:
    ///   - isCheckingAuth: auth state is still resolving on launch.
    ///   - onboardingCompleted: the onboarding/paywall flow finished.
    ///   - isCloudLinked: a real Supabase session exists (not merely an anon uid).
    ///   - deferralActive: the user chose "continue for now" and the gentle
    ///     re-prompt window has not yet elapsed (see `AuthDeferralStore.isActive`).
    ///   - forceAuthScreen: DEBUG review hook — force the auth screen regardless of
    ///     an active deferral so it can be screenshotted on-sim. Always false in
    ///     release builds.
    static func route(
        isCheckingAuth: Bool,
        onboardingCompleted: Bool,
        isCloudLinked: Bool,
        deferralActive: Bool,
        forceAuthScreen: Bool = false
    ) -> RootRoute {
        // DEBUG review hook wins unconditionally - it must show the wall even on
        // a signed-in dev state, or it can't be screenshotted in review.
        if forceAuthScreen { return .auth }
        if isCheckingAuth { return .loading }
        if !onboardingCompleted { return .onboarding }
        // A real cloud session always wins: the deferral is irrelevant once linked.
        if isCloudLinked { return .main }
        // Onboarded + still anonymous: honor an active deferral so an outage right
        // after payment can't wall out a paying customer; otherwise show the wall.
        return deferralActive ? .main : .auth
    }
}
