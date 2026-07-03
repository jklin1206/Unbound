import Foundation
import CoreGraphics

enum AppConstants {
    enum RevenueCat {
        static let apiKey = "appl_OIQYrbHrtkobrAoGiqBJVJkLpcf"
        static let entitlementIdentifier = "Unbound Pro"
        /// Lookup key of the exit-intent discount offering. Purchases made from
        /// the promo sheet must resolve against this offering, never `current` —
        /// experiment variants swap `current`, and its `$rc_annual` package is
        /// the full-price annual.
        static let promoOfferingKey = "promo"
        /// RevenueCat placement id the promo sheet asks for FIRST. Experiments
        /// and targeting rules can remap this placement to a different offering
        /// per arm (that's how the exit price itself gets A/B-tested); when no
        /// rule matches, the fixed `promo` offering is the fallback.
        static let promoPlacementId = "promo_exit"
    }
    enum PostHog {
        static let apiKey = "phc_xWUn9rk9938eRhF4MVFa8pgL9A8GceCmrPideTWwWbe7"
        static let host = "https://us.i.posthog.com"
    }
    enum Analytics {
        static let usageOptOutKey = "unbound.analyticsOptOut"
    }
    enum Legal {
        static let termsURL = URL(string: "https://unboundbtr.com/terms")!
        static let privacyURL = URL(string: "https://unboundbtr.com/privacy")!
    }
    enum Limits {
        static let maxPhotoWidthPx: CGFloat = 1200
        static let jpegCompressionQuality: CGFloat = 0.7
        static let maxPhotoSizeBytes = 300_000
        static let analysisTimeoutSeconds: TimeInterval = 120
        static let networkTimeoutSeconds: TimeInterval = 30
        static let maxRetryAttempts = 3
    }
    enum Paywall {
        static let hardGate = "hard_gate"
        static let reportUnlockProgram = "report_unlock_program"
        static let tabProgramLocked = "tab_program_locked"
        static let rescanLocked = "rescan_locked"
    }
}
