import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

/// The two sanctioned App Store rating asks, both at aha moments:
/// 1. Scan analyzing - fired by `Step_ScanAnalyzing` a couple seconds into the
///    cinematic "building your protocol" sweep, before any price talk.
/// 2. First REAL workout - fired once, right after the first non-rehearsal
///    reward sequence dismisses.
/// Apple throttles the actual sheet (max ~3/year, never twice in quick
/// succession), so both call sites request unconditionally and let the OS
/// decide which one shows.
enum AppStoreReviewPrompt {

    static func request() {
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("-SuppressOnboardingReviewPrompt") else {
            return
        }
        #endif

        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
        #endif
    }

    /// One-shot ask after the user's first real (non-rehearsal) workout.
    /// Slightly delayed so the reward cover finishes dismissing and the sheet
    /// rises over a settled screen instead of a mid-flight transition.
    static func requestAfterFirstRealWorkoutIfNeeded() {
        let key = "review.askedAfterFirstRealWorkout"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            request()
        }
    }
}
