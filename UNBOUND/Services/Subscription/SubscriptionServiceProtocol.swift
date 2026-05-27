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
    func purchase(packageId: String) async throws -> Bool
    func restorePurchases() async throws -> Bool
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
}
