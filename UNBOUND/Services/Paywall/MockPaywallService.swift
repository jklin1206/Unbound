final class MockPaywallService: PaywallServiceProtocol, @unchecked Sendable {
    var shouldConvert = false

    func configure() {}
    func setUserAttributes(_ attributes: [String: Any]) {}

    func triggerPaywall(placement: String) async -> PaywallResult {
        shouldConvert ? .purchased : .dismissed
    }
}
