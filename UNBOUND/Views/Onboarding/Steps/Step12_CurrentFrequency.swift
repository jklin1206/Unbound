import SwiftUI

struct Step12_CurrentFrequency: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How often do you train now?",
            subtitle: nil,
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.currentFrequency != nil,
            hudStep: .currentFrequency,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                ForEach(Array(Frequency.allCases.enumerated()), id: \.element) { idx, f in
                    HUDSelectRow(
                        index: idx + 1,
                        title: f.displayName,
                        subtitle: f.subtitle,
                        isSelected: flow.currentFrequency == f
                    ) {
                        flow.currentFrequency = f
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    Step12_CurrentFrequency(flow: OnboardingFlowViewModel(), progress: 0.4, onBack: {}, onContinue: {})
}
