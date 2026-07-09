import SwiftUI

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
            title: L10n.onboarding("trainingDays.title", defaultValue: "Training calendar"),
            subtitle: L10n.onboardingFormat("trainingDays.subtitle", defaultValue: "Pick your %d days.", requiredCount),
            progress: progress,
            primaryTitle: L10n.onboarding("common.continue", defaultValue: "Continue"),
            primaryEnabled: isValid,
            hudStep: .trainingDays,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            WeekFlameSelector(
                requiredCount: requiredCount,
                selection: $flow.trainingDays
            )
            .padding(.top, 12)
        }
    }
}

// De-boxed week picker: seven flame tokens (the same day-flame language as
// the Home streak strip) and one status line underneath. Selected days
// ignite; the rest stay unlit. No planner board, no nested cards.
private struct WeekFlameSelector: View {
    let requiredCount: Int
    @Binding var selection: Set<Weekday>

    private let days = Weekday.allCases

    private var isValid: Bool {
        selection.count == requiredCount
    }

    private var statusText: String {
        if isValid {
            let picked = days.filter(selection.contains)
                .map { $0.short.uppercased() }
                .joined(separator: " · ")
            return L10n.onboardingFormat("trainingDays.locked", defaultValue: "YOUR WEEK · %@", picked)
        }
        let remaining = max(0, requiredCount - selection.count)
        return L10n.onboardingFormat("trainingDays.remaining", defaultValue: "PICK %d MORE", remaining)
    }

    var body: some View {
        VStack(spacing: 26) {
            HStack(spacing: 6) {
                ForEach(days) { day in
                    FlameDayToken(
                        day: day,
                        isSelected: selection.contains(day)
                    ) {
                        toggle(day)
                    }
                }
            }

            Text(statusText)
                .font(Font.unbound.monoS)
                .tracking(1.4)
                .foregroundStyle(isValid ? Color.unbound.accent : Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .animation(.easeInOut(duration: 0.2), value: statusText)

            if !isValid {
                Text(L10n.onboarding("trainingDays.hint", defaultValue: "Rest days are part of the plan. The system builds around them."))
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isValid)
    }

    private func toggle(_ day: Weekday) {
        UnboundHaptics.medium()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            if selection.contains(day) {
                selection.remove(day)
                return
            }

            if selection.count >= requiredCount, let firstSelected = days.first(where: selection.contains) {
                selection.remove(firstSelected)
            }
            selection.insert(day)
        }
    }
}

private struct FlameDayToken: View {
    let day: Weekday
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Text(day.short.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.unbound.accent.opacity(0.18) : Color.unbound.surface.opacity(0.6))
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.unbound.accent : Color.unbound.borderSubtle,
                            lineWidth: isSelected ? 1.5 : 1
                        )

                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textTertiary.opacity(0.55))
                        .scaleEffect(isSelected ? 1 : 0.86)
                }
                .frame(width: 46, height: 46)
                .shadow(color: isSelected ? Color.unbound.accent.opacity(0.4) : .clear, radius: 10)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .accessibilityLabel(day.short)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview {
    Step_TrainingDays(
        flow: OnboardingFlowViewModel(),
        progress: 0.5,
        onBack: {},
        onContinue: {}
    )
}
#endif
