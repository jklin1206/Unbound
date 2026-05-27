import Foundation

final class PaywallService: PaywallServiceProtocol, @unchecked Sendable {
    static let shared = PaywallService()
    private init() {}

    func configure() {}

    func setUserAttributes(_ attributes: [String: Any]) {}

    func triggerPaywall(placement: String) async -> PaywallResult {
        AnalyticsService.shared.track(.paywallTriggered(placement: placement))
        return .dismissed
    }
}
