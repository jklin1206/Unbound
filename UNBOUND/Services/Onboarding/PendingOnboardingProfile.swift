import Foundation

// MARK: - PendingOnboardingProfile
//
// Onboarding is completed BEFORE sign-in (the route gate shows auth only after
// `onboardingCompleted` flips true). So `OnboardingFlowViewModel.finish()` can
// only write the answers under the "anonymous" placeholder id, which lands in
// the local store and never reaches the real account — leaving the authed user
// with a blank stub and program generation running on defaults.
//
// This stashes the built profile payload at finish time so it can be REPLAYED
// onto the real user the instant they authenticate (see the post-auth task in
// RootView). The payload is plist-safe (strings / ints / bools / arrays of
// those), so UserDefaults round-trips it cleanly.

enum PendingOnboardingProfile {
    private static let key = "pendingOnboardingProfile"

    /// Save the onboarding profile payload for post-sign-in replay.
    static func stash(_ fields: [String: Any]) {
        UserDefaults.standard.set(fields, forKey: key)
    }

    /// The pending payload, or nil if none is waiting. A peek — it does NOT
    /// clear. Route replays through `replay(_:)` so the stash only clears on a
    /// successful write.
    static func take() -> [String: Any]? {
        guard let fields = UserDefaults.standard.dictionary(forKey: key), !fields.isEmpty else {
            return nil
        }
        return fields
    }

    /// Clear after the payload has landed on the authenticated user.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Replay the pending payload through `apply`, clearing the stash ONLY if
    /// `apply` succeeds — a thrown error leaves it in place so a later launch or
    /// sign-in retries. No-op when nothing is stashed. This is the real "take"
    /// contract: `take()` alone is a peek, so replaying through here is what
    /// prevents clearing on a failed write.
    static func replay(_ apply: (_ fields: [String: Any]) async throws -> Void) async rethrows {
        guard let fields = take() else { return }
        try await apply(fields)
        clear()
    }
}
