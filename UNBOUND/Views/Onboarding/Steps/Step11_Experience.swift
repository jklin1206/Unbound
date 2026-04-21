import SwiftUI

struct Step11_Experience: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What's your training experience?",
            subtitle: nil,
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.experience != nil,
            hudStep: .experience,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                ForEach(Array(Experience.allCases.enumerated()), id: \.element) { idx, e in
                    HUDSelectRow(
                        index: idx + 1,
                        title: e.displayName,
                        isSelected: flow.experience == e
                    ) {
                        flow.experience = e
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    Step11_Experience(flow: OnboardingFlowViewModel(), progress: 0.36, onBack: {}, onContinue: {})
}
