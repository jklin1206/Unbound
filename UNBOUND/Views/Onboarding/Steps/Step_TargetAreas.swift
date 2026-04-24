import SwiftUI

struct Step_TargetAreas: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "Where do you want to focus?",
            subtitle: "Pick a few. We'll prioritize these in every session.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.targetAreas.isEmpty,
            hudStep: .targetAreas,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: TargetArea.allCases,
                selection: $flow.targetAreas,
                title: { $0.displayName },
                icon: { $0.icon },
                umbrella: .fullBody,
                umbrellaSubtitle: "Train every angle — the full arc."
            )
            .padding(.top, 4)
        }
    }
}
