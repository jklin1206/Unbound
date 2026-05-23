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
                options: visibleEquipment,
                selection: $flow.equipment,
                title: { $0.displayName },
                icon: { $0.icon },
                umbrella: .fullGym,
                umbrellaSubtitle: "Whole arsenal — nothing off the table."
            )
            .padding(.top, 4)
        }
    }

    /// Hide the legacy `.homeWeights` case from onboarding (kept on the enum
    /// for backward compat with pre-redesign persisted profiles).
    private var visibleEquipment: [Equipment] {
        Equipment.allCases.filter { $0 != .homeWeights }
    }
}

#Preview {
    Step14_Equipment(flow: OnboardingFlowViewModel(), progress: 0.46, onBack: {}, onContinue: {})
}
