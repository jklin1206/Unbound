import Foundation
import Combine
import RevenueCat

final class SubscriptionService: NSObject, SubscriptionServiceProtocol, @unchecked Sendable {
    static let shared = SubscriptionService()
    private let logger = LoggingService.shared
    private let statusSubject = CurrentValueSubject<Bool, Never>(false)

    @Published private(set) var isSubscribed: Bool = false

    var hasActiveSubscription: Bool { isSubscribed }
    var subscriptionStatusPublisher: AnyPublisher<Bool, Never> { statusSubject.eraseToAnyPublisher() }

    private override init() { super.init() }

    func configure() {
        let key = AppConstants.RevenueCat.apiKey
        guard !Self.shouldStubPurchases(for: key) else {
            logger.log(
                "SubscriptionService.configure: skipping RevenueCat init (\(Self.stubReason(for: key)))",
                level: .info
            )
            return
        }
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: key)
        Purchases.shared.delegate = self
    }

    /// True when purchases are disabled for local simulator safety.
    /// All Purchases.shared calls become no-ops to avoid triggering Apple Account modals.
    private var isStubbed: Bool {
        Self.shouldStubPurchases(for: AppConstants.RevenueCat.apiKey)
    }

    private static func shouldStubPurchases(for key: String) -> Bool {
        if key.hasPrefix("PLACEHOLDER_") { return true }

        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["UNBOUND_ENABLE_REVENUECAT_SIM"] != "1"
        #else
        return false
        #endif
    }

    private static func stubReason(for key: String) -> String {
        if key.hasPrefix("PLACEHOLDER_") { return "placeholder key" }

        #if DEBUG && targetEnvironment(simulator)
        return "debug simulator"
        #else
        return "disabled"
        #endif
    }

    func login(userId: String) async throws {
        guard !isStubbed else { return }
        let (customerInfo, _) = try await Purchases.shared.logIn(userId)
        updateStatus(from: customerInfo)
    }

    func logout() async throws {
        guard !isStubbed else {
            setSubscriptionStatus(false)
            return
        }
        _ = try await Purchases.shared.logOut()
        setSubscriptionStatus(false)
    }

    func fetchOfferings() async throws -> [SubscriptionPackage] {
        guard !isStubbed else {
            #if DEBUG && targetEnvironment(simulator)
            return Self.debugPreviewPackages
            #else
            return []
            #endif
        }
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else { return [] }

        return current.availablePackages.map { pkg in
            SubscriptionPackage(
                id: pkg.identifier,
                productId: pkg.storeProduct.productIdentifier,
                title: pkg.storeProduct.localizedTitle,
                price: pkg.localizedPriceString,
                duration: pkg.storeProduct.subscriptionPeriod?.durationTitle ?? "",
                pricePerMonth: pkg.storeProduct.localizedPricePerMonth,
                hasFreeTrial: pkg.storeProduct.introductoryDiscount != nil,
                freeTrialDuration: pkg.storeProduct.introductoryDiscount?.subscriptionPeriod.durationTitle
            )
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    private static var debugPreviewPackages: [SubscriptionPackage] {
        [
            SubscriptionPackage(
                id: "$rc_three_month",
                productId: "unbound_month_3",
                title: "3 Month",
                price: "$24.99",
                duration: "3 Months",
                pricePerMonth: "$8.33",
                hasFreeTrial: true,
                freeTrialDuration: "3 Days"
            ),
            SubscriptionPackage(
                id: "$rc_weekly",
                productId: "unbound_weekly",
                title: "Weekly",
                price: "$14.99",
                duration: "Weekly",
                pricePerMonth: nil,
                hasFreeTrial: true,
                freeTrialDuration: "3 Days"
            )
        ]
    }
    #endif

    func purchase(packageId: String) async throws -> Bool {
        guard !isStubbed else {
            #if DEBUG && targetEnvironment(simulator)
            setSubscriptionStatus(true)
            return true
            #else
            return false
            #endif
        }
        let offerings = try await Purchases.shared.offerings()
        guard let pkg = offerings.current?.availablePackages.first(where: { $0.identifier == packageId }) else {
            throw AppError.subscriptionPurchaseFailed(underlying: NSError(domain: "RC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Package not found"]))
        }
        let (_, customerInfo, _) = try await Purchases.shared.purchase(package: pkg)
        updateStatus(from: customerInfo)
        return hasActiveSubscription
    }

    func restorePurchases() async throws -> Bool {
        guard !isStubbed else {
            #if DEBUG && targetEnvironment(simulator)
            setSubscriptionStatus(true)
            return true
            #else
            return false
            #endif
        }
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateStatus(from: customerInfo)
        return hasActiveSubscription
    }

    private func updateStatus(from customerInfo: CustomerInfo) {
        let isActive = customerInfo.entitlements[AppConstants.RevenueCat.entitlementIdentifier]?.isActive == true
        setSubscriptionStatus(isActive)
    }

    private func setSubscriptionStatus(_ isActive: Bool) {
        let previous = isSubscribed
        isSubscribed = isActive
        statusSubject.send(isActive)
        AnalyticsService.shared.registerSuper(["isSubscribed": isActive])

        guard previous != isActive else { return }
        if isActive {
            AnalyticsService.shared.track(.subscriptionStarted(productId: AppConstants.RevenueCat.entitlementIdentifier, isTrialPeriod: false))
        } else {
            AnalyticsService.shared.track(.subscriptionCanceled(productId: AppConstants.RevenueCat.entitlementIdentifier))
        }
    }
}

extension SubscriptionService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateStatus(from: customerInfo)
    }
}

extension SubscriptionPeriod {
    var durationTitle: String {
        switch unit {
        case .day: return value == 1 ? "Daily" : "\(value) Days"
        case .week: return value == 1 ? "Weekly" : "\(value) Weeks"
        case .month: return value == 1 ? "Monthly" : "\(value) Months"
        case .year: return value == 1 ? "Annual" : "\(value) Years"
        @unknown default: return ""
        }
    }
}
