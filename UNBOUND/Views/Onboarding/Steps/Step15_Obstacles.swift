import SwiftUI

struct Step15_Obstacles: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What's been in the way?",
            subtitle: "Be honest.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.obstacles.isEmpty,
            hudStep: .obstacles,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: Obstacle.allCases,
                selection: $flow.obstacles,
                title: { $0.displayName }
            )
            .padding(.top, 4)
        }
    }
}

#if DEBUG
#Preview {
    Step15_Obstacles(flow: OnboardingFlowViewModel(), progress: 0.5, onBack: {}, onContinue: {})
}

#endif
