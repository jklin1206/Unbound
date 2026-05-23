import SwiftUI

// MARK: - Step_TrainingDays
//
// Inserted right after Step13_TargetFrequency. The user has picked a weekly
// training frequency (e.g. 4x/wk). This screen asks which specific weekdays
// they'll train — the generator schedules workouts onto these exact days
// instead of packing into consecutive days.
//
// Validation: selected count must equal `targetFrequency.numericCount`.
// A gentle hint shows selected-vs-required; Continue stays disabled until
// the count matches exactly.

struct Step_TrainingDays: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var requiredCount: Int {
        flow.targetFrequency?.numericCount ?? 3
    }

    private var isValid: Bool {
        flow.trainingDays.count == requiredCount
    }

    var body: some View {
        OnboardingScaffold(
            title: "Which days will you train?",
            subtitle: "Pick \(requiredCount) days that work for you.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: isValid,
            hudStep: .trainingDays,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 16) {
                HUDMultiSelectGroup(
                    options: Weekday.allCases,
                    selection: $flow.trainingDays,
                    title: { $0.short }
                )
                .padding(.top, 4)

                if !isValid {
                    Text("Selected \(flow.trainingDays.count) of \(requiredCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
}

#Preview {
    Step_TrainingDays(
        flow: OnboardingFlowViewModel(),
        progress: 0.5,
        onBack: {},
        onContinue: {}
    )
}
