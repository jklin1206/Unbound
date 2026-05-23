import Foundation
import Combine
import RevenueCat

final class SubscriptionService: NSObject, SubscriptionServiceProtocol, @unchecked Sendable {
    static let shared = SubscriptionService()
    private let logger = LoggingService.shared
    private let statusSubject = CurrentValueSubject<Bool, Never>(false)

    var hasActiveSubscription: Bool { statusSubject.value }
    var subscriptionStatusPublisher: AnyPublisher<Bool, Never> { statusSubject.eraseToAnyPublisher() }

    private override init() { super.init() }

    func configure() {
        let key = AppConstants.RevenueCat.apiKey
        // Skip RevenueCat init when running with a placeholder key (dev/sim).
        // Otherwise iOS triggers the Apple Account sign-in modal repeatedly
        // when the SDK tries to validate receipts with a fake key.
        guard !key.hasPrefix("PLACEHOLDER_") else {
            logger.log("SubscriptionService.configure: skipping RevenueCat init (placeholder key)", level: .info)
            return
        }
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: key)
        Purchases.shared.delegate = self
    }

    /// True when running with a placeholder RevenueCat key (dev/sim).
    /// All Purchases.shared calls become no-ops to avoid triggering Apple Account modals.
    private var isStubbed: Bool {
        AppConstants.RevenueCat.apiKey.hasPrefix("PLACEHOLDER_")
    }

    func login(userId: String) async throws {
        guard !isStubbed else { return }
        let (customerInfo, _) = try await Purchases.shared.logIn(userId)
        updateStatus(from: customerInfo)
    }

    func logout() async throws {
        guard !isStubbed else { statusSubject.send(false); return }
        _ = try await Purchases.shared.logOut()
        statusSubject.send(false)
    }

    func fetchOfferings() async throws -> [SubscriptionPackage] {
        guard !isStubbed else { return [] }
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else { return [] }

        return current.availablePackages.map { pkg in
            SubscriptionPackage(
                id: pkg.identifier,
                title: pkg.storeProduct.localizedTitle,
                price: pkg.localizedPriceString,
                duration: pkg.storeProduct.subscriptionPeriod?.durationTitle ?? "",
                hasFreeTrial: pkg.storeProduct.introductoryDiscount != nil,
                freeTrialDuration: pkg.storeProduct.introductoryDiscount?.subscriptionPeriod.durationTitle
            )
        }
    }

    func purchase(packageId: String) async throws -> Bool {
        guard !isStubbed else { return false }
        let offerings = try await Purchases.shared.offerings()
        guard let pkg = offerings.current?.availablePackages.first(where: { $0.identifier == packageId }) else {
            throw AppError.subscriptionPurchaseFailed(underlying: NSError(domain: "RC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Package not found"]))
        }
        let (_, customerInfo, _) = try await Purchases.shared.purchase(package: pkg)
        updateStatus(from: customerInfo)
        return hasActiveSubscription
    }

    func restorePurchases() async throws -> Bool {
        guard !isStubbed else { return false }
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateStatus(from: customerInfo)
        return hasActiveSubscription
    }

    private func updateStatus(from customerInfo: CustomerInfo) {
        let isActive = customerInfo.entitlements["pro"]?.isActive == true
        statusSubject.send(isActive)
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
