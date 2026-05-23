import SwiftUI

struct Step07_Gender: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What's your gender?",
            subtitle: "This helps set the path without pretending everyone starts from the same place.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .gender,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                ForEach(Array(Gender.allCases.enumerated()), id: \.element) { idx, option in
                    HUDSelectRow(
                        index: idx + 1,
                        title: option.displayName,
                        isSelected: flow.gender == option
                    ) {
                        flow.gender = option
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    Step07_Gender(flow: OnboardingFlowViewModel(), progress: 0.23, onBack: {}, onContinue: {})
}
