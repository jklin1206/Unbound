import Foundation
import Combine

final class MockSubscriptionService: SubscriptionServiceProtocol, @unchecked Sendable {
    private let subject = CurrentValueSubject<Bool, Never>(false)
    var hasActiveSubscription: Bool { subject.value }
    var subscriptionStatusPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }

    func configure() {}
    func login(userId: String) async throws {}
    func logout() async throws { subject.send(false) }

    func fetchOfferings() async throws -> [SubscriptionPackage] {
        [
            SubscriptionPackage(id: "weekly", title: "Weekly", price: "$4.99", duration: "Weekly", hasFreeTrial: true, freeTrialDuration: "3 Days"),
            SubscriptionPackage(id: "annual", title: "Annual", price: "$29.99", duration: "Annual", hasFreeTrial: true, freeTrialDuration: "7 Days")
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
