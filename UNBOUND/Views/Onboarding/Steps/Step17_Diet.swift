import SwiftUI

struct Step17_Diet: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How clean is your diet?",
            subtitle: "Not perfect — honest. We calibrate from here.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .diet,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 24) {
                LifestyleSignalAsset(kind: LifestyleSignalAsset.Kind.diet, value: flow.dietQuality)
                    .padding(.top, 10)

                HUDSlider(
                    value: $flow.dietQuality,
                    steps: HUDSlider.fivePointStoredSteps,
                    descriptors: HUDSlider.dietDescriptors,
                    leftAnchor: "Poor",
                    rightAnchor: "Excellent"
                )
            }
        }
    }
}

#Preview {
    Step17_Diet(flow: OnboardingFlowViewModel(), progress: 0.56, onBack: {}, onContinue: {})
}
