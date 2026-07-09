import Foundation
import Combine

final class MockSubscriptionService: SubscriptionServiceProtocol, @unchecked Sendable {
    private let subject = CurrentValueSubject<Bool, Never>(false)
    var isSubscribed: Bool { subject.value }
    var hasActiveSubscription: Bool { isSubscribed }
    var subscriptionStatusPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }

    func configure() {}
    func login(userId: String) async throws {}
    func logout() async throws { subject.send(false) }

    func fetchOfferings() async throws -> [SubscriptionPackage] {
        [
            SubscriptionPackage(
                id: "$rc_weekly",
                productId: "unbound_weekly",
                title: "Weekly",
                price: "$14.99",
                duration: "Weekly",
                pricePerMonth: nil,
                hasFreeTrial: false,
                freeTrialDuration: nil
            ),
            SubscriptionPackage(
                id: "$rc_three_month",
                productId: "unbound_month_3",
                title: "3 Month",
                price: "$24.99",
                duration: "3 Months",
                pricePerMonth: "$8.33",
                hasFreeTrial: true,
                freeTrialDuration: "7 Days"
            )
        ]
    }

    func fetchPromoOffering() async throws -> [SubscriptionPackage] {
        [
            SubscriptionPackage(
                id: "$rc_annual",
                productId: "unbound_yearly_promo",
                title: "Yearly",
                price: "$29.99",
                duration: "Annual",
                pricePerMonth: "$2.50",
                hasFreeTrial: false,
                freeTrialDuration: nil,
                anchorPrice: "$59.99"
            )
        ]
    }

    func purchase(packageId: String, fromOffering offeringKey: String?) async throws -> SubscriptionPurchaseOutcome {
        subject.send(true)
        return .purchased
    }

    func restorePurchases() async throws -> Bool {
        subject.send(true)
        return true
    }
}
