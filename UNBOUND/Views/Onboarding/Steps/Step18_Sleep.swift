import SwiftUI

struct Step18_Sleep: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How well do you sleep?",
            subtitle: "Recovery is where growth happens.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .sleep,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 24) {
                LifestyleSignalAsset(kind: LifestyleSignalAsset.Kind.sleep, value: flow.sleepQuality)
                    .padding(.top, 10)

                HUDSlider(
                    value: $flow.sleepQuality,
                    steps: HUDSlider.fivePointStoredSteps,
                    descriptors: HUDSlider.sleepDescriptors,
                    leftAnchor: "Restless",
                    rightAnchor: "Restored"
                )
            }
        }
    }
}

#Preview {
    Step18_Sleep(flow: OnboardingFlowViewModel(), progress: 0.6, onBack: {}, onContinue: {})
}
