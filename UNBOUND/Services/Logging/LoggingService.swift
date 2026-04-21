import Foundation
import os.log

// MARK: - LoggingService (local-first)
//
// Replaces the Firebase Crashlytics-backed implementation with os.Logger.
// Same public interface — callers don't change.
//
// When a real crash reporter comes back (Sentry, Bugsnag, or Crashlytics
// through Firebase V2), only this file changes.

final class LoggingService: @unchecked Sendable {
    static let shared = LoggingService()

    #if DEBUG
    private let minimumLevel: LogLevel = .debug
    #else
    private let minimumLevel: LogLevel = .info
    #endif

    private let logger = Logger(subsystem: "com.unbound.app", category: "AniBody")

    private init() {}

    func log(
        _ message: String,
        level: LogLevel = .info,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLevel else { return }

        let fileName = (file as NSString).lastPathComponent
        let contextString = context.isEmpty ? "" : " | \(context)"
        let composed = "[\(fileName):\(line)] \(function) — \(message)\(contextString)"

        switch level {
        case .debug:    logger.debug("\(composed, privacy: .public)")
        case .info:     logger.info("\(composed, privacy: .public)")
        case .warning:  logger.warning("\(composed, privacy: .public)")
        case .error:    logger.error("\(composed, privacy: .public)")
        case .critical: logger.critical("\(composed, privacy: .public)")
        }
    }
}
