import SwiftUI

struct Step14_Equipment: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What can you get your hands on?",
            subtitle: "We'll build around whatever you've got. Less is fine.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.equipment.isEmpty,
            hudStep: .equipment,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: Equipment.allCases,
                selection: $flow.equipment,
                title: { $0.displayName },
                icon: { $0.icon }
            )
            .padding(.top, 4)
        }
    }
}

#Preview {
    Step14_Equipment(flow: OnboardingFlowViewModel(), progress: 0.46, onBack: {}, onContinue: {})
}
