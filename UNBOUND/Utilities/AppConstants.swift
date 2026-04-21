import Foundation
import CoreGraphics

enum AppConstants {
    enum RevenueCat {
        static let apiKey = "PLACEHOLDER_REVENUECAT_API_KEY"
    }
    enum Superwall {
        static let apiKey = "PLACEHOLDER_SUPERWALL_API_KEY"
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
        static let reportUnlockProgram = "report_unlock_program"
        static let tabProgramLocked = "tab_program_locked"
        static let rescanLocked = "rescan_locked"
    }
}
