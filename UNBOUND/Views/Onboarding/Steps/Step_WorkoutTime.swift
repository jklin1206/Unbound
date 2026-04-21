import SwiftUI

struct Step_WorkoutTime: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "When do you work out?",
            subtitle: "We'll nudge you with reminders around this time. You can change it anytime.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.workoutTime != nil,
            hudStep: .workoutTime,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                ForEach(Array(WorkoutTime.allCases.enumerated()), id: \.element) { idx, t in
                    HUDSelectRow(
                        index: idx + 1,
                        title: t.displayName,
                        subtitle: t.subtitle,
                        isSelected: flow.workoutTime == t
                    ) {
                        flow.workoutTime = t
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
