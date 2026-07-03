import SwiftUI

struct Step17_Diet: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How clean is your diet?",
            subtitle: "Honest, not perfect.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .diet,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 28) {
                HUDSlider(
                    value: $flow.dietQuality,
                    steps: HUDSlider.fivePointStoredSteps,
                    descriptors: HUDSlider.dietDescriptors,
                    leftAnchor: "Poor",
                    rightAnchor: "Excellent"
                )

                Text(L10n.onboarding("diet.note", defaultValue: "This tunes recovery pacing. No meal plans, no macro police."))
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        }
    }
}

#if DEBUG
#Preview {
    Step17_Diet(flow: OnboardingFlowViewModel(), progress: 0.56, onBack: {}, onContinue: {})
}

#endif
