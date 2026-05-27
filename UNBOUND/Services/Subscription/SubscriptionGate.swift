import SwiftUI

struct SubscriptionGate: ViewModifier {
    @ObservedObject private var entitlement = EntitlementService.shared
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    func body(content: Content) -> some View {
        if !onboardingCompleted {
            content
        } else if entitlement.isEntitled {
            content
        } else {
            LockedView()
        }
    }
}

extension View {
    func subscriptionGate() -> some View {
        modifier(SubscriptionGate())
    }
}
