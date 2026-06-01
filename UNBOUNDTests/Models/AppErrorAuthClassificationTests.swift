import XCTest
@testable import UNBOUND

/// Locks the auth/network error classification added to harden sign-in:
/// connection failures get connection-specific copy, genuine auth failures get
/// actionable copy (not the generic "Something went wrong"), and an
/// already-classified AppError passes through untouched.
final class AppErrorAuthClassificationTests: XCTestCase {

    func test_from_noConnectionURLError_mapsToNetworkNoConnection() {
        let mapped = AppError.from(authError: URLError(.notConnectedToInternet))
        guard case .networkNoConnection = mapped else {
            return XCTFail("Expected .networkNoConnection, got \(mapped)")
        }
    }

    func test_from_connectionLostURLError_mapsToNetworkNoConnection() {
        let mapped = AppError.from(authError: URLError(.networkConnectionLost))
        guard case .networkNoConnection = mapped else {
            return XCTFail("Expected .networkNoConnection, got \(mapped)")
        }
    }

    func test_from_timeoutURLError_mapsToNetworkTimeout() {
        let mapped = AppError.from(authError: URLError(.timedOut))
        guard case .networkTimeout = mapped else {
            return XCTFail("Expected .networkTimeout, got \(mapped)")
        }
    }

    func test_from_genericError_mapsToAuthSignInFailed() {
        struct Boom: Error {}
        let mapped = AppError.from(authError: Boom())
        guard case .authSignInFailed = mapped else {
            return XCTFail("Expected .authSignInFailed, got \(mapped)")
        }
    }

    func test_from_existingAppError_passesThrough() {
        let mapped = AppError.from(authError: AppError.authCanceled)
        guard case .authCanceled = mapped else {
            return XCTFail("Expected pass-through .authCanceled, got \(mapped)")
        }
    }

    func test_authSignInFailed_hasActionableCopy_notGeneric() {
        let generic = AppError.unknown(underlying: URLError(.unknown)).errorDescription
        let authCopy = AppError.authSignInFailed(
            underlying: URLError(.userAuthenticationRequired)
        ).errorDescription
        XCTAssertNotNil(authCopy)
        XCTAssertNotEqual(
            authCopy, generic,
            "Auth sign-in failure must not fall back to the generic message"
        )
    }

    func test_networkTimeout_hasDedicatedCopy() {
        let timeout = AppError.networkTimeout.errorDescription
        let generic = AppError.unknown(underlying: URLError(.unknown)).errorDescription
        XCTAssertNotNil(timeout)
        XCTAssertNotEqual(timeout, generic, "Timeout must have its own copy")
    }
}
