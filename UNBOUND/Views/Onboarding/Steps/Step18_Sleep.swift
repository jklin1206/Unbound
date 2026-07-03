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
            VStack(spacing: 28) {
                HUDSlider(
                    value: $flow.sleepQuality,
                    steps: HUDSlider.fivePointStoredSteps,
                    descriptors: HUDSlider.sleepDescriptors,
                    leftAnchor: "Restless",
                    rightAnchor: "Restored"
                )

                Text(L10n.onboarding("sleep.note", defaultValue: "Rough sleep weeks get lighter progression targets."))
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
    Step18_Sleep(flow: OnboardingFlowViewModel(), progress: 0.6, onBack: {}, onContinue: {})
}

#endif
