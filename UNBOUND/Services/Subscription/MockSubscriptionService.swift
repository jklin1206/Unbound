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
                hasFreeTrial: true,
                freeTrialDuration: "3 Days"
            ),
            SubscriptionPackage(
                id: "$rc_three_month",
                productId: "unbound_month_3",
                title: "3 Month",
                price: "$24.99",
                duration: "3 Months",
                pricePerMonth: "$8.33",
                hasFreeTrial: true,
                freeTrialDuration: "3 Days"
            )
        ]
    }

    func purchase(packageId: String) async throws -> Bool {
        subject.send(true)
        return true
    }

    func restorePurchases() async throws -> Bool {
        subject.send(true)
        return true
    }
}
