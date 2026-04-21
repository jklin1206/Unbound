import Foundation
import os.log

// MARK: - AnalyticsService (local-first)
//
// Replaces Firebase Analytics with an OSLog-backed no-op shell. Events
// still get observed in the Console in DEBUG so we can verify funnel
// instrumentation locally. When a real analytics backend comes back
// (PostHog / Mixpanel / Amplitude / re-added Firebase), only this file
// changes.

final class AnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    static let shared = AnalyticsService()
    private let logger = Logger(subsystem: "com.unbound.app", category: "analytics")
    private init() {}

    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        logger.info("event: \(event.name, privacy: .public) params: \(String(describing: event.parameters), privacy: .public)")
        #endif
    }

    func setUserProperty(_ value: String?, forName name: String) {
        #if DEBUG
        logger.debug("userProperty \(name, privacy: .public) = \(value ?? "nil", privacy: .public)")
        #endif
    }

    func setUserId(_ userId: String?) {
        #if DEBUG
        logger.debug("userId set: \(userId ?? "nil", privacy: .public)")
        #endif
    }
}
