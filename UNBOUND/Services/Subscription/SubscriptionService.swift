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

    func fetchPromoOffering() async throws -> [SubscriptionPackage] {
        guard !isStubbed else {
            #if DEBUG && targetEnvironment(simulator)
            return [Self.previewPromoAnnual]
            #else
            return []
            #endif
        }
        let offerings = try await Purchases.shared.offerings()
        // Placement first: experiments/targeting can remap what the exit promo
        // serves per arm. The fixed `promo` offering is the fallback when no
        // placement rule matches (placements unconfigured returns nil).
        guard let promo = offerings.currentOffering(forPlacement: AppConstants.RevenueCat.promoPlacementId)
            ?? offerings.all[AppConstants.RevenueCat.promoOfferingKey] else { return [] }
        // Anchor = the standard annual package (from the current offering). Its
        // localized string is struck through next to the promo price; its decimal
        // price is what the discount is computed against.
        let anchorPackage = offerings.current?.availablePackages
            .first { $0.storeProduct.subscriptionPeriod?.unit == .year }
        let anchor = anchorPackage?.localizedPriceString
        let anchorValue = anchorPackage?.storeProduct.price
        return promo.availablePackages.map { pkg in
            SubscriptionPackage(
                id: pkg.identifier,
                productId: pkg.storeProduct.productIdentifier,
                title: pkg.storeProduct.localizedTitle,
                price: pkg.localizedPriceString,
                duration: pkg.storeProduct.subscriptionPeriod?.durationTitle ?? "",
                pricePerMonth: pkg.storeProduct.localizedPricePerMonth,
                hasFreeTrial: pkg.storeProduct.introductoryDiscount != nil,
                freeTrialDuration: pkg.storeProduct.introductoryDiscount?.subscriptionPeriod.durationTitle,
                anchorPrice: anchor,
                sourceOfferingId: promo.identifier,
                discountPercent: Self.promoDiscountPercent(promo: pkg.storeProduct.price, anchor: anchorValue)
            )
        }
    }

    /// Whole-percent saving of `promo` against `anchor`, or `nil` when it can't
    /// be stated honestly. Both prices come from the same store account, so they
    /// share a currency and compare directly. Returns `nil` on a missing/zero
    /// anchor or a result outside a believable 5–90% range, so the exit sheet
    /// falls back to non-numeric copy instead of a misleading "X% OFF".
    static func promoDiscountPercent(promo: Decimal?, anchor: Decimal?) -> Int? {
        guard let promo, let anchor, anchor > 0, promo >= 0 else { return nil }
        let fraction = (anchor - promo) / anchor
        let percent = Int(((fraction as NSDecimalNumber).doubleValue * 100).rounded())
        guard (5...90).contains(percent) else { return nil }
        return percent
    }

    #if DEBUG && targetEnvironment(simulator)
    private static let previewWeekly = SubscriptionPackage(
        id: "$rc_weekly", productId: "unbound_weekly", title: "Weekly",
        price: "$14.99", duration: "Weekly", pricePerMonth: nil,
        hasFreeTrial: false, freeTrialDuration: nil)
    private static let previewMonthly = SubscriptionPackage(
        id: "$rc_monthly", productId: "unbound_monthly", title: "Monthly",
        price: "$12.99", duration: "Monthly", pricePerMonth: nil,
        hasFreeTrial: false, freeTrialDuration: nil)
    private static let previewThreeMonth = SubscriptionPackage(
        id: "$rc_three_month", productId: "unbound_month_3", title: "3 Month",
        price: "$24.99", duration: "3 Months", pricePerMonth: "$8.33",
        hasFreeTrial: true, freeTrialDuration: "7 Days")
    private static let previewYearly = SubscriptionPackage(
        id: "$rc_annual", productId: "unbound_yearly", title: "Yearly",
        price: "$59.99", duration: "Annual", pricePerMonth: "$5.00",
        hasFreeTrial: true, freeTrialDuration: "7 Days")
    /// Exit-intent promo: discounted annual with the standard $59.99 struck through.
    private static let previewPromoAnnual = SubscriptionPackage(
        id: "$rc_annual", productId: "unbound_yearly_promo", title: "Yearly",
        price: "$29.99", duration: "Annual", pricePerMonth: "$2.50",
        hasFreeTrial: false, freeTrialDuration: nil, anchorPrice: "$59.99",
        sourceOfferingId: AppConstants.RevenueCat.promoOfferingKey,
        discountPercent: SubscriptionService.promoDiscountPercent(promo: 29.99, anchor: 59.99))

    /// Sim-only preview packages. `--paywall-combo=<id>` swaps the pair so the
    /// paywall's per-plan styling can be eyeballed across combinations.
    private static var debugPreviewPackages: [SubscriptionPackage] {
        let combo = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--paywall-combo=") }?
            .replacingOccurrences(of: "--paywall-combo=", with: "")
        switch combo {
        case "year-weekly":    return [previewYearly, previewWeekly]
        case "weekly-monthly": return [previewWeekly, previewMonthly]
        case "year-3m":        return [previewYearly, previewThreeMonth]
        case "monthly-weekly": return [previewMonthly, previewWeekly]
        case "all3":           return [previewThreeMonth, previewWeekly, previewYearly]
        default:               return [previewYearly, previewThreeMonth, previewWeekly]
        }
    }
    #endif

    func purchase(packageId: String, fromOffering offeringKey: String?) async throws -> Bool {
        guard !isStubbed else {
            #if DEBUG && targetEnvironment(simulator)
            setSubscriptionStatus(true)
            return true
            #else
            return false
            #endif
        }
        let offerings = try await Purchases.shared.offerings()
        let offering = offeringKey.flatMap { offerings.all[$0] } ?? offerings.current
        guard let pkg = offering?.availablePackages.first(where: { $0.identifier == packageId }) else {
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
