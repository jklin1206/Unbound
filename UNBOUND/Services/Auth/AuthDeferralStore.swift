import Foundation

// MARK: - AuthDeferralStore
//
// The forced post-paywall "protect your progress" screen used to be a hard
// wall: onboarded + not-cloud-linked routed to AuthContainerView with no way
// past it, so a Supabase outage right after payment could lock a paying
// customer out of the app they just bought. Sign-in stays the default,
// strongly-encouraged path; this store just lets the user step past the wall
// and keep training locally (the app is fully functional in the anonymous
// local-user state) until they choose to link.
//
// Like PendingSquadInvite, the deferral is intentionally NOT keyed to user
// identity — it predates sign-in (the user is still the anonymous local UUID)
// — so it uses one stable global key. Identity keying would lose the deferral
// across the anonymous -> authed handoff.
//
// A single timestamp does double duty: it records that the user deferred and
// drives a gentle re-prompt. While the deferral is "active" (within the
// re-prompt window) routing skips the wall; once the window elapses the wall
// is shown once more, and a fresh "continue for now" tap restarts the window.
// Date() here is deliberate wall-clock UX and is NOT governed by the repo's
// dev clock (ProgramClock / dayOffset), which only governs program WRITES;
// `now` is injected so tests can pin it.

struct AuthDeferralStore {
    // Global (not identity-keyed) UserDefaults key holding the wall-clock time
    // the user last chose "continue for now". Exposed (not private) so RootView's
    // `@AppStorage(AuthDeferralStore.deferredAtKey)` can observe it and re-route
    // past the auth wall the moment a deferral is recorded.
    static let deferredAtKey = "authDeferral.deferredAt"

    /// How long a deferral suppresses the forced auth wall before it re-prompts
    /// once more. Wall-clock; a gentle cadence (3 days), not a per-launch nag.
    static let repromptInterval: TimeInterval = 3 * 24 * 60 * 60

    /// Shared production instance, backed by the standard defaults.
    static let shared = AuthDeferralStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Record that the user chose to continue without linking, (re)starting the
    /// re-prompt window. Called when the escape affordance is tapped.
    func markDeferred(now: Date = Date()) {
        defaults.set(now.timeIntervalSince1970, forKey: Self.deferredAtKey)
    }

    /// True when a deferral is active and should suppress the forced auth wall:
    /// the user deferred and the re-prompt window has not yet elapsed. Once the
    /// window passes this returns false so routing shows the wall one more time.
    func isActive(now: Date = Date()) -> Bool {
        Self.isActive(deferredAt: defaults.double(forKey: Self.deferredAtKey), now: now)
    }

    /// Pure re-prompt-window check, split out so the routing view can evaluate it
    /// directly from the `@AppStorage`-observed raw timestamp. A zero/absent value
    /// (never deferred) is never active.
    static func isActive(deferredAt: TimeInterval, now: Date = Date()) -> Bool {
        guard deferredAt > 0 else { return false }
        return now.timeIntervalSince1970 - deferredAt < repromptInterval
    }

    /// Clear the deferral. Called once the user is cloud-linked — the deferral is
    /// then meaningless (a real session already routes to the main app) — so no
    /// stale timestamp lingers to affect a future signed-out state.
    func clear() {
        defaults.removeObject(forKey: Self.deferredAtKey)
    }
}
