import SwiftUI

struct Step19_Stress: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How much stress are you carrying?",
            subtitle: "High stress compounds fatigue. We factor it in.",
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
                .padding(.top, 32)

                if flow.stressLevel >= 7 {
                    HUDCallout(
                        iconSystemName: "sparkles",
                        eyebrow: "SYSTEM NOTE",
                        message: "Noted. We'll adjust intensity."
                    )
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .animation(.easeOut(duration: 0.3), value: flow.stressLevel >= 7)
        }
    }
}

#Preview {
    Step19_Stress(flow: OnboardingFlowViewModel(), progress: 0.63, onBack: {}, onContinue: {})
}
