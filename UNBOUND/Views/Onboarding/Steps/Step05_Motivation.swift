import SwiftUI

struct Step05_Motivation: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What's pushing you?",
            subtitle: "The real reason, not the polished one. Pick whatever lands.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.motivations.isEmpty,
            hudStep: .motivation,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: Motivation.allCases,
                selection: $flow.motivations,
                title: { $0.displayName },
                icon: { $0.icon }
            )
            .padding(.top, 4)
        }
    }
}

#Preview {
    Step05_Motivation(
        flow: OnboardingFlowViewModel(),
        progress: 0.18,
        onBack: {},
        onContinue: {}
    )
}
