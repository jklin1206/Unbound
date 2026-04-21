import Foundation
import Combine

// Single source of truth for whether the user has unlocked the app.
// `isEntitled` = real subscription active OR dev override flag on.
//
// Views gate on this (NOT on SubscriptionService.hasActiveSubscription
// directly) so the dev override works uniformly across the app.

@MainActor
protocol EntitlementServiceProtocol: AnyObject {
    var isEntitled: Bool { get }
    var isEntitledPublisher: AnyPublisher<Bool, Never> { get }
}

@MainActor
final class EntitlementService: ObservableObject, EntitlementServiceProtocol {
    static let shared = EntitlementService()

    @Published private(set) var isEntitled: Bool = false

    private let subscription: SubscriptionServiceProtocol
    private let devFlags = DevFlags.shared
    private var cancellables = Set<AnyCancellable>()

    var isEntitledPublisher: AnyPublisher<Bool, Never> {
        $isEntitled.eraseToAnyPublisher()
    }

    init(subscription: SubscriptionServiceProtocol = SubscriptionService.shared) {
        self.subscription = subscription
        self.isEntitled = computeEntitled()

        subscription.subscriptionStatusPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)

        devFlags.unlockAllFeaturesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
    }

    private func recompute() {
        let next = computeEntitled()
        if next != isEntitled { isEntitled = next }
    }

    private func computeEntitled() -> Bool {
        subscription.hasActiveSubscription || devFlags.unlockAllFeatures
    }
}
