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
            title: L10n.onboarding("trainingDays.title", defaultValue: "Which days will you train?"),
            subtitle: L10n.onboardingFormat("trainingDays.subtitle", defaultValue: "Pick %d days that work for you.", requiredCount),
            progress: progress,
            primaryTitle: L10n.onboarding("common.continue", defaultValue: "Continue"),
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
                    Text(L10n.onboardingFormat("trainingDays.selectedCount", defaultValue: "Selected %d of %d", flow.trainingDays.count, requiredCount))
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
