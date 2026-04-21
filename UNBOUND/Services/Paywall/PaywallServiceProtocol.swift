protocol PaywallServiceProtocol: Sendable {
    func configure()
    func setUserAttributes(_ attributes: [String: Any])
    func triggerPaywall(placement: String) async -> PaywallResult
}

enum PaywallResult {
    case purchased
    case dismissed
    case error(Error)
}
