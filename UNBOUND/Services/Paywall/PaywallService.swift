import Foundation
import SuperwallKit

final class PaywallService: PaywallServiceProtocol, @unchecked Sendable {
    static let shared = PaywallService()
    private let logger = LoggingService.shared
    private let analytics = AnalyticsService.shared

    private init() {}

    func configure() {
        Superwall.configure(apiKey: AppConstants.Superwall.apiKey)
    }

    func setUserAttributes(_ attributes: [String: Any]) {
        Superwall.shared.setUserAttributes(attributes.mapValues { "\($0)" })
    }

    @MainActor
    func triggerPaywall(placement: String) async -> PaywallResult {
        analytics.track(.paywallTriggered(placement: placement))

        do {
            let info = try await Superwall.shared.register(placement: placement)
            // Superwall handles purchase flow internally when configured with RevenueCat
            // Check subscription status after paywall dismisses
            if SubscriptionService.shared.hasActiveSubscription {
                analytics.track(.paywallConverted(placement: placement, productId: "via_superwall"))
                return .purchased
            } else {
                analytics.track(.paywallDismissed(placement: placement))
                return .dismissed
            }
        } catch {
            logger.log("Paywall error: \(error)", level: .error, context: ["placement": placement])
            return .error(error)
        }
    }
}
