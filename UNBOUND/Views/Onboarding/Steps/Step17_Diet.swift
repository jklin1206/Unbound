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
            HUDSlider(
                value: $flow.dietQuality,
                descriptors: HUDSlider.dietDescriptors,
                leftAnchor: "Poor",
                rightAnchor: "Excellent"
            )
            .padding(.top, 32)
        }
    }
}

#Preview {
    Step17_Diet(flow: OnboardingFlowViewModel(), progress: 0.56, onBack: {}, onContinue: {})
}
