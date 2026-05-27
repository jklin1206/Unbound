import Foundation
import os.log
import PostHog

protocol AnalyticsBackendProtocol: Sendable {
    func configure(defaultProperties: AnalyticsProperties)
    func track(name: String, properties: AnalyticsProperties)
    func identify(userId: String, traits: AnalyticsProperties)
    func reset()
    func registerSuper(_ properties: AnalyticsProperties)
    func optIn()
    func optOut()
}

extension AnalyticsBackendProtocol {
    func configure(defaultProperties: AnalyticsProperties) {}
    func identify(userId: String, traits: AnalyticsProperties) {}
    func reset() {}
    func registerSuper(_ properties: AnalyticsProperties) {}
    func optIn() {}
    func optOut() {}
}

struct AnalyticsRecordedEvent {
    let name: String
    let properties: AnalyticsProperties
}

final class InMemoryAnalyticsBackend: AnalyticsBackendProtocol, @unchecked Sendable {
    private struct State {
        var configuredProperties: AnalyticsProperties = [:]
        var events: [AnalyticsRecordedEvent] = []
        var identifiedUserId: String?
        var identifyTraits: AnalyticsProperties = [:]
        var registeredSuperProperties: AnalyticsProperties = [:]
        var resetCount = 0
        var optInCount = 0
        var optOutCount = 0
        var isOptedOut = false
    }

    private let lock = NSLock()
    private var state = State()

    var configuredProperties: AnalyticsProperties {
        lock.withLock { state.configuredProperties }
    }

    var events: [AnalyticsRecordedEvent] {
        lock.withLock { state.events }
    }

    var identifiedUserId: String? {
        lock.withLock { state.identifiedUserId }
    }

    var identifyTraits: AnalyticsProperties {
        lock.withLock { state.identifyTraits }
    }

    var registeredSuperProperties: AnalyticsProperties {
        lock.withLock { state.registeredSuperProperties }
    }

    var resetCount: Int {
        lock.withLock { state.resetCount }
    }

    var optInCount: Int {
        lock.withLock { state.optInCount }
    }

    var optOutCount: Int {
        lock.withLock { state.optOutCount }
    }

    var isOptedOut: Bool {
        lock.withLock { state.isOptedOut }
    }

    func configure(defaultProperties: AnalyticsProperties) {
        lock.withLock {
            state.configuredProperties.merge(defaultProperties) { _, new in new }
        }
    }

    func track(name: String, properties: AnalyticsProperties) {
        lock.withLock {
            guard !state.isOptedOut else { return }
            state.events.append(AnalyticsRecordedEvent(name: name, properties: properties))
        }
    }

    func identify(userId: String, traits: AnalyticsProperties) {
        lock.withLock {
            guard !state.isOptedOut else { return }
            state.identifiedUserId = userId
            state.identifyTraits = traits
        }
    }

    func reset() {
        lock.withLock {
            state.identifiedUserId = nil
            state.identifyTraits = [:]
            state.resetCount += 1
        }
    }

    func registerSuper(_ properties: AnalyticsProperties) {
        lock.withLock {
            state.registeredSuperProperties.merge(properties) { _, new in new }
        }
    }

    func optIn() {
        lock.withLock {
            state.isOptedOut = false
            state.optInCount += 1
        }
    }

    func optOut() {
        lock.withLock {
            state.isOptedOut = true
            state.optOutCount += 1
        }
    }
}

final class OSLogAnalyticsBackend: AnalyticsBackendProtocol, @unchecked Sendable {
    private let logger: Logger

    init(logger: Logger = Logger(subsystem: "com.unbound.app", category: "analytics")) {
        self.logger = logger
    }

    func configure(defaultProperties: AnalyticsProperties) {
        #if DEBUG
        logger.debug("configure defaults: \(String(describing: defaultProperties), privacy: .public)")
        #endif
    }

    func track(name: String, properties: AnalyticsProperties) {
        #if DEBUG
        logger.info("event: \(name, privacy: .public) params: \(String(describing: properties), privacy: .public)")
        #endif
    }

    func identify(userId: String, traits: AnalyticsProperties) {
        #if DEBUG
        logger.debug("identify userId: \(userId, privacy: .public) traits: \(String(describing: traits), privacy: .public)")
        #endif
    }

    func reset() {
        #if DEBUG
        logger.debug("reset")
        #endif
    }

    func registerSuper(_ properties: AnalyticsProperties) {
        #if DEBUG
        logger.debug("registerSuper: \(String(describing: properties), privacy: .public)")
        #endif
    }

    func optIn() {
        #if DEBUG
        logger.debug("optIn")
        #endif
    }

    func optOut() {
        #if DEBUG
        logger.debug("optOut")
        #endif
    }
}

final class PostHogAnalyticsBackend: AnalyticsBackendProtocol, @unchecked Sendable {
    private let projectToken: String
    private let host: String
    private let lock = NSLock()
    private var configured = false

    init(projectToken: String, host: String) {
        self.projectToken = projectToken
        self.host = host
    }

    func configure(defaultProperties: AnalyticsProperties) {
        lock.withLock {
            guard !configured else { return }
            let config = PostHogConfig(projectToken: projectToken, host: host)
            config.captureApplicationLifecycleEvents = false
            config.captureScreenViews = false
            #if DEBUG
            config.debug = true
            #endif
            PostHogSDK.shared.setup(config)
            configured = true
        }
        registerSuper(defaultProperties)
    }

    func track(name: String, properties: AnalyticsProperties) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture(name, properties: properties)
    }

    func identify(userId: String, traits: AnalyticsProperties) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify(userId, userProperties: traits)
    }

    func reset() {
        guard isConfigured else { return }
        PostHogSDK.shared.reset()
    }

    func registerSuper(_ properties: AnalyticsProperties) {
        guard isConfigured else { return }
        var values: AnalyticsProperties = [:]
        for (key, value) in properties {
            if value is NSNull {
                PostHogSDK.shared.unregister(key)
            } else {
                values[key] = value
            }
        }
        guard !values.isEmpty else { return }
        PostHogSDK.shared.register(values)
    }

    func optIn() {
        guard isConfigured else { return }
        PostHogSDK.shared.optIn()
    }

    func optOut() {
        guard isConfigured else { return }
        PostHogSDK.shared.optOut()
    }

    private var isConfigured: Bool {
        lock.withLock { configured }
    }
}

final class MultiplexAnalyticsBackend: AnalyticsBackendProtocol, @unchecked Sendable {
    private let backends: [any AnalyticsBackendProtocol]

    init(_ backends: [any AnalyticsBackendProtocol]) {
        self.backends = backends
    }

    func configure(defaultProperties: AnalyticsProperties) {
        backends.forEach { $0.configure(defaultProperties: defaultProperties) }
    }

    func track(name: String, properties: AnalyticsProperties) {
        backends.forEach { $0.track(name: name, properties: properties) }
    }

    func identify(userId: String, traits: AnalyticsProperties) {
        backends.forEach { $0.identify(userId: userId, traits: traits) }
    }

    func reset() {
        backends.forEach { $0.reset() }
    }

    func registerSuper(_ properties: AnalyticsProperties) {
        backends.forEach { $0.registerSuper(properties) }
    }

    func optIn() {
        backends.forEach { $0.optIn() }
    }

    func optOut() {
        backends.forEach { $0.optOut() }
    }
}

private enum AnalyticsBackendFactory {
    static func makeDefault() -> any AnalyticsBackendProtocol {
        let osLog = OSLogAnalyticsBackend()
        let token = AppConstants.PostHog.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !token.hasPrefix("PLACEHOLDER") else {
            return osLog
        }
        return MultiplexAnalyticsBackend([
            osLog,
            PostHogAnalyticsBackend(projectToken: token, host: AppConstants.PostHog.host)
        ])
    }
}

// MARK: - AnalyticsService (local-first)
//
// Routes typed analytics calls through a small backend seam. The default
// backend preserves DEBUG OSLog visibility and enables PostHog when a real
// project token is configured.

final class AnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    static let shared = AnalyticsService(backend: AnalyticsBackendFactory.makeDefault())
    private let backend: any AnalyticsBackendProtocol
    private let lock = NSLock()
    private var superProperties: AnalyticsProperties = [:]
    private var isOptedOut = false

    init(backend: any AnalyticsBackendProtocol = AnalyticsBackendFactory.makeDefault()) {
        self.backend = backend
    }

    func configure(defaultProperties: AnalyticsProperties = AnalyticsDefaults.current()) {
        lock.withLock {
            superProperties.merge(defaultProperties) { _, new in new }
        }
        backend.configure(defaultProperties: defaultProperties)
    }

    func track(_ event: AnalyticsEvent) {
        guard let properties = lock.withLock({ mergedProperties(for: event) }) else { return }
        backend.track(name: event.name, properties: properties)
    }

    func identify(userId: String, traits: AnalyticsProperties = [:]) {
        guard lock.withLock({ !isOptedOut }) else { return }
        backend.identify(userId: userId, traits: traits)
    }

    func reset() {
        backend.reset()
    }

    func registerSuper(_ properties: AnalyticsProperties) {
        lock.withLock {
            superProperties.merge(properties) { _, new in new }
        }
        backend.registerSuper(properties)
    }

    func optIn() {
        lock.withLock {
            isOptedOut = false
        }
        backend.optIn()
    }

    func optOut() {
        lock.withLock {
            isOptedOut = true
        }
        backend.optOut()
    }

    func setUserProperty(_ value: String?, forName name: String) {
        if let value {
            registerSuper([name: value])
        } else {
            lock.withLock {
                _ = superProperties.removeValue(forKey: name)
            }
            backend.registerSuper([name: NSNull()])
        }
    }

    func setUserId(_ userId: String?) {
        if let userId {
            identify(userId: userId)
        } else {
            reset()
        }
    }

    private func mergedProperties(for event: AnalyticsEvent) -> AnalyticsProperties? {
        guard !isOptedOut else { return nil }
        return superProperties.merging(event.parameters) { _, eventValue in eventValue }
    }
}

private extension NSLock {
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
