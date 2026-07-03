import Foundation
import Combine

protocol SubscriptionServiceProtocol: Sendable {
    var isSubscribed: Bool { get }
    var hasActiveSubscription: Bool { get }
    var subscriptionStatusPublisher: AnyPublisher<Bool, Never> { get }

    func configure()
    func login(userId: String) async throws
    func logout() async throws
    func fetchOfferings() async throws -> [SubscriptionPackage]
    /// Packages from the RevenueCat `promo` offering — the discounted annual
    /// shown on exit-intent. Empty when the offering isn't configured.
    func fetchPromoOffering() async throws -> [SubscriptionPackage]
    /// Purchases a package. `offeringKey` names the offering the package was
    /// listed from (`nil` = the current offering). Passing the right offering
    /// matters: package identifiers like `$rc_annual` repeat across offerings
    /// with different products/prices, and RevenueCat attributes the conversion
    /// to the offering of the package object it's handed.
    func purchase(packageId: String, fromOffering offeringKey: String?) async throws -> Bool
    func restorePurchases() async throws -> Bool
}

extension SubscriptionServiceProtocol {
    /// Purchase from the current offering.
    func purchase(packageId: String) async throws -> Bool {
        try await purchase(packageId: packageId, fromOffering: nil)
    }
}

struct SubscriptionPackage: Identifiable, Sendable {
    let id: String
    let productId: String
    let title: String
    let price: String
    let duration: String
    let pricePerMonth: String?
    let hasFreeTrial: Bool
    let freeTrialDuration: String?
    /// The "was" price to strike through (e.g. the standard annual next to a
    /// discounted promo). `nil` for regular packages.
    var anchorPrice: String? = nil
    /// Lookup key of the offering this package was listed from, when it wasn't
    /// the current offering (e.g. a placement-served promo). Purchase calls
    /// pass it back so the same package id resolves to the same product.
    var sourceOfferingId: String? = nil
    /// Honest, whole-percent saving of this package against its anchor price,
    /// or `nil` when no believable discount can be stated. Computed from the
    /// store's decimal prices (see `SubscriptionService.promoDiscountPercent`),
    /// so a drifting promo/anchor never misstates the claim.
    var discountPercent: Int? = nil
}
