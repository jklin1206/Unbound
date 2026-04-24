import SwiftUI

struct Step_Goals: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What are you building?",
            subtitle: "Pick what actually matters to you right now. You can change it later.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.goals.isEmpty,
            hudStep: .goals,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: visibleGoals,
                selection: $flow.goals,
                title: { $0.displayName },
                subtitle: { $0.subtitle },
                icon: { $0.icon }
            )
            .padding(.top, 4)
        }
    }

    /// Narrowed from `Goal.allCases` — 4 goals that carry real signal for
    /// protocol selection. `.getDefined` overlaps with build+cut so we let
    /// users express it as two picks; `.feelBetter` is too abstract for a
    /// body-transformation app's onboarding. Both still exist on the enum
    /// for any persisted user data.
    private var visibleGoals: [Goal] {
        [.buildMuscle, .loseFat, .getStronger, .athletic]
    }
}

#Preview {
    Step_Goals(flow: OnboardingFlowViewModel(), progress: 0.18, onBack: {}, onContinue: {})
}
