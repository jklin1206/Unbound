import SwiftUI

struct Step20_PriorAttempts: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What have you tried already?",
            subtitle: "No shade on any of these. Helps us not repeat what didn't land.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.priorAttempts.isEmpty,
            hudStep: .priorAttempts,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: PriorAttempt.allCases,
                selection: $flow.priorAttempts,
                title: { $0.displayName },
                icon: { $0.icon }
            )
            .padding(.top, 4)
        }
    }
}

#Preview {
    Step20_PriorAttempts(flow: OnboardingFlowViewModel(), progress: 0.66, onBack: {}, onContinue: {})
}
