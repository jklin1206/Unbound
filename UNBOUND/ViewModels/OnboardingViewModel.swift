import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep = 0
    let totalSteps = 3

    private let analytics: any AnalyticsServiceProtocol

    init(analytics: any AnalyticsServiceProtocol) {
        self.analytics = analytics
        analytics.track(.onboardingStarted)
    }

    func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
            analytics.track(.onboardingStepViewed(step: currentStep, screenName: stepName))
        }
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        analytics.track(.onboardingCompleted)
    }

    func skip() {
        analytics.track(.onboardingSkipped(atStep: currentStep))
        complete()
    }

    private var stepName: String {
        switch currentStep {
        case 0: return "welcome"
        case 1: return "how_it_works"
        case 2: return "archetype_preview"
        default: return "unknown"
        }
    }
}
