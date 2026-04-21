import Foundation

enum AppError: LocalizedError {
    case authSignInFailed(underlying: Error)
    case authSignOutFailed(underlying: Error)
    case authAccountDeletionFailed(underlying: Error)
    case authNotAuthenticated
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
            return "You need to sign in to continue."
        case .cameraAccessDenied:
            return "Camera access is required for body scanning. Please enable it in Settings."
        case .analysisTimeout:
            return "Analysis is taking longer than expected. Please try again."
        case .networkNoConnection:
            return "No internet connection. Please check your network and try again."
        case .subscriptionNoActiveEntitlement:
            return "This feature requires an active subscription."
        default:
            return "Something went wrong. Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cameraAccessDenied:
            return "Open Settings > UNBOUND > Camera and enable access."
        case .networkNoConnection:
            return "Connect to Wi-Fi or enable cellular data."
        case .analysisTimeout:
            return "Try again with better lighting and clearer photos."
        default:
            return "If the problem persists, contact support."
        }
    }
}
