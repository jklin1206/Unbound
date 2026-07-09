import SwiftUI

struct Step14_Equipment: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What can you get your hands on?",
            subtitle: "Nothing selected = just you.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .equipment,
            onBack: onBack,
            onPrimary: {
                // No explicit "Bodyweight only" card — an empty pick IS
                // bodyweight-only, recorded so downstream gen sees it as before.
                if flow.equipment.isEmpty {
                    flow.equipment = [.bodyweight]
                }
                onContinue()
            }
        ) {
            HUDMultiSelectGroup(
                options: visibleEquipment,
                selection: $flow.equipment,
                title: { $0.displayName },
                umbrella: .fullGym,
                umbrellaSubtitle: "Nothing off the table."
            )
            .padding(.top, 4)
        }
    }

    /// Hidden cases: legacy `.homeWeights` (pre-redesign profiles) and
    /// `.bodyweight` (implicit — empty selection means bodyweight-only).
    private var visibleEquipment: [Equipment] {
        Equipment.allCases.filter { $0 != .homeWeights && $0 != .bodyweight }
    }
}

#if DEBUG
#Preview {
    Step14_Equipment(flow: OnboardingFlowViewModel(), progress: 0.46, onBack: {}, onContinue: {})
}

#endif
