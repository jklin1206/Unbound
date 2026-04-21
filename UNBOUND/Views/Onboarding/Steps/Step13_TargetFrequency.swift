import SwiftUI

struct Step13_TargetFrequency: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How many days can you actually commit?",
            subtitle: "Realistic beats ambitious. We'd rather you show up 4 days than ghost on 6.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.targetFrequency != nil,
            hudStep: .targetFrequency,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                ForEach(Array(TargetFrequency.allCases.enumerated()), id: \.element) { idx, f in
                    HUDSelectRow(
                        index: idx + 1,
                        title: f.displayName,
                        subtitle: f.subtitle,
                        isSelected: flow.targetFrequency == f
                    ) {
                        flow.targetFrequency = f
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    Step13_TargetFrequency(flow: OnboardingFlowViewModel(), progress: 0.43, onBack: {}, onContinue: {})
}
