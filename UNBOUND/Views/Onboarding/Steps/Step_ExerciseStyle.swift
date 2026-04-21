import SwiftUI

struct Step_ExerciseStyle: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What do you actually enjoy?",
            subtitle: "Pick everything that sounds good. We lean the plan toward what you like so you'll keep showing up.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.exerciseStyles.isEmpty,
            hudStep: .exerciseStyle,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: ExerciseStyle.allCases,
                selection: $flow.exerciseStyles,
                title: { $0.displayName },
                subtitle: { $0.subtitle },
                icon: { $0.icon }
            )
            .padding(.top, 4)
        }
    }
}
