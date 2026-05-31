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

    /// The pending payload, or nil if none is waiting.
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
}
