import SwiftUI

struct Step06_Age: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How old are you?",
            subtitle: "Recovery, volume, and pace all shift with age. We'll tune it right.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .age,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 8) {
                Spacer().frame(height: 12)
                HUDScrollPicker(
                    selection: $flow.age,
                    values: Array(15...80),
                    formatter: { "\($0) YRS" },
                    eyebrow: "AGE"
                )
                Spacer().frame(height: 12)
            }
        }
    }
}

#Preview {
    Step06_Age(flow: OnboardingFlowViewModel(), progress: 0.2, onBack: {}, onContinue: {})
}
