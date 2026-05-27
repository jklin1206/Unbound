import Foundation
import CoreGraphics

enum AppConstants {
    enum RevenueCat {
        static let apiKey = "appl_OIQYrbHrtkobrAoGiqBJVJkLpcf"
        static let entitlementIdentifier = "Unbound Pro"
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
    enum API {
        static let analyzeBodyURL = "https://us-central1-PLACEHOLDER.cloudfunctions.net/analyzeBody"
        static let generateProgramURL = "https://us-central1-PLACEHOLDER.cloudfunctions.net/generateProgram"
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
