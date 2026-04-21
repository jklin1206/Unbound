protocol AnalyticsServiceProtocol: Sendable {
    func track(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserId(_ userId: String?)
}
