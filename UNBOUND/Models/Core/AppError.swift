import Foundation

enum AppError: LocalizedError {
    case authSignInFailed(underlying: Error)
    case authSignOutFailed(underlying: Error)
    case authAccountDeletionFailed(underlying: Error)
    case authNotAuthenticated
    /// The user dismissed a sign-in sheet (e.g. tapped Cancel on the Apple
    /// prompt). A deliberate choice, not a failure — callers suppress it and
    /// surface nothing. Intentionally absent from `errorDescription`.
    case authCanceled
    case networkTimeout
    case networkNoConnection
    case networkServerError(statusCode: Int, message: String?)
    case networkDecodingFailed(underlying: Error)
    case analysisPhotoUploadFailed(underlying: Error)
    case analysisProcessingFailed(message: String)
    case analysisInvalidResponse
    case analysisTimeout
    case programGenerationFailed(message: String)
    case programInvalidResponse
    case cameraAccessDenied
    case cameraUnavailable
    case cameraCaptureFailed
    case subscriptionPurchaseFailed(underlying: Error)
    case subscriptionRestoreFailed(underlying: Error)
    case subscriptionNoActiveEntitlement
    case databaseReadFailed(underlying: Error)
    case databaseWriteFailed(underlying: Error)
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .authNotAuthenticated:
            return L10n.string(
                .appErrorAuthNotAuthenticatedDescription,
                defaultValue: "You need to sign in to continue."
            )
        case .authSignInFailed:
            return L10n.string(
                .appErrorAuthSignInFailedDescription,
                defaultValue: "We couldn't sign you in. Please check your email and password, then try again."
            )
        case .networkTimeout:
            return L10n.string(
                .appErrorNetworkTimeoutDescription,
                defaultValue: "The connection timed out. Please check your network and try again."
            )
        case .cameraAccessDenied:
            return L10n.string(
                .appErrorCameraAccessDeniedDescription,
                defaultValue: "Camera access is required for scan photos. Please enable it in Settings."
            )
        case .analysisTimeout:
            return L10n.string(
                .appErrorAnalysisTimeoutDescription,
                defaultValue: "Analysis is taking longer than expected. Please try again."
            )
        case .networkNoConnection:
            return L10n.string(
                .appErrorNetworkNoConnectionDescription,
                defaultValue: "No internet connection. Please check your network and try again."
            )
        case .subscriptionNoActiveEntitlement:
            return L10n.string(
                .appErrorSubscriptionNoActiveEntitlementDescription,
                defaultValue: "This feature requires an active subscription."
            )
        default:
            return L10n.string(
                .appErrorGenericDescription,
                defaultValue: "Something went wrong. Please try again."
            )
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cameraAccessDenied:
            return L10n.string(
                .appErrorCameraAccessDeniedRecovery,
                defaultValue: "Open Settings > UNBOUND > Camera and enable access."
            )
        case .networkNoConnection:
            return L10n.string(
                .appErrorNetworkNoConnectionRecovery,
                defaultValue: "Connect to Wi-Fi or enable cellular data."
            )
        case .analysisTimeout:
            return L10n.string(
                .appErrorAnalysisTimeoutRecovery,
                defaultValue: "Try again with better lighting and clearer photos."
            )
        default:
            return L10n.string(
                .appErrorGenericRecovery,
                defaultValue: "If the problem persists, contact support."
            )
        }
    }

    // MARK: - Classification

    /// Maps a raw error from an auth or network call into the most specific
    /// user-facing case: an already-classified `AppError` passes through; a
    /// `URLError` becomes connection-specific copy; anything else is treated as
    /// a genuine auth failure. Apple's user-cancellation is detected upstream in
    /// `AuthService` (it lives in the AuthenticationServices layer, which this
    /// Foundation-only model deliberately does not import).
    static func from(authError error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if let urlError = error as? URLError {
            return urlError.code == .timedOut ? .networkTimeout : .networkNoConnection
        }
        return .authSignInFailed(underlying: error)
    }
}
