import SwiftUI

struct Step19_Stress: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How much stress are you carrying?",
            subtitle: nil,
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .stress,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 24) {
                HUDSlider(
                    value: $flow.stressLevel,
                    steps: HUDSlider.fivePointStoredSteps,
                    descriptors: HUDSlider.stressDescriptors,
                    leftAnchor: "Calm",
                    rightAnchor: "Burned out"
                )

                HUDCallout(
                    iconSystemName: "sparkles",
                    eyebrow: "SYSTEM NOTE",
                    message: "Noted. Saved to your profile."
                )
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        }
    }
}

#if DEBUG
#Preview {
    Step19_Stress(flow: OnboardingFlowViewModel(), progress: 0.63, onBack: {}, onContinue: {})
}

#endif
