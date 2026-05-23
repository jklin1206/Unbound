import SwiftUI

struct Step21_Commitment: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How seriously are we doing this?",
            subtitle: "No judgment on either end. Sets how hard we push.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .commitment,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 24) {
                HUDSlider(
                    value: $flow.commitment,
                    steps: HUDSlider.fivePointStoredSteps,
                    descriptors: HUDSlider.commitmentDescriptors,
                    leftAnchor: "Curious",
                    rightAnchor: "All in"
                )
                .padding(.top, 32)

                if flow.commitment >= 8 {
                    HUDCallout(
                        iconSystemName: "flame.fill",
                        eyebrow: "REGISTERED",
                        message: "The arc responds to conviction."
                    )
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .animation(.easeOut(duration: 0.3), value: flow.commitment >= 8)
        }
    }
}

#Preview {
    Step21_Commitment(flow: OnboardingFlowViewModel(), progress: 0.7, onBack: {}, onContinue: {})
}
