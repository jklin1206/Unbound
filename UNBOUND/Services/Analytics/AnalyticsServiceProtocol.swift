import Foundation

typealias AnalyticsProperties = [String: Any]

enum AnalyticsDefaults {
    static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> AnalyticsProperties {
        var properties: AnalyticsProperties = [
            "osVersion": processInfo.operatingSystemVersionString
        ]

        if let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            properties["appVersion"] = appVersion
        }

        if let build = bundle.infoDictionary?["CFBundleVersion"] as? String {
            properties["build"] = build
        }

        return properties
    }
}

protocol AnalyticsServiceProtocol: Sendable {
    func configure(defaultProperties: AnalyticsProperties)
    func track(_ event: AnalyticsEvent)
    func identify(userId: String, traits: AnalyticsProperties)
    func reset()
    func registerSuper(_ properties: AnalyticsProperties)
    func optIn()
    func optOut()
    func setUserProperty(_ value: String?, forName name: String)
    func setUserId(_ userId: String?)
}

extension AnalyticsServiceProtocol {
    func configure(defaultProperties: AnalyticsProperties = AnalyticsDefaults.current()) {
        registerSuper(defaultProperties)
    }

    func identify(userId: String, traits: AnalyticsProperties = [:]) {
        setUserId(userId)
        registerSuper(traits)
    }

    func reset() {
        setUserId(nil)
    }

    func registerSuper(_ properties: AnalyticsProperties) {
        for (name, value) in properties {
            setUserProperty(String(describing: value), forName: name)
        }
    }

    func optIn() {}
    func optOut() {}
    func setUserProperty(_ value: String?, forName name: String) {}
    func setUserId(_ userId: String?) {}
}
