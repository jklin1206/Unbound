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
            subtitle: nil,
            progress: progress,
            primaryTitle: L10n.onboarding("common.continue", defaultValue: "Continue"),
            primaryEnabled: isValid,
            hudStep: .trainingDays,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            WeekCalendarSelector(
                requiredCount: requiredCount,
                selection: $flow.trainingDays
            )
            .padding(.top, 4)
        }
    }
}

private struct WeekCalendarSelector: View {
    let requiredCount: Int
    @Binding var selection: Set<Weekday>

    private let days = Weekday.allCases
    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 34, maximum: 56), spacing: 5),
        count: 7
    )

    private var isValid: Bool {
        selection.count == requiredCount
    }

    private var statusText: String {
        if isValid {
            return "LOCKED"
        }
        let remaining = max(0, requiredCount - selection.count)
        return remaining == 1 ? "PICK 1" : "PICK \(remaining)"
    }

    var body: some View {
        VStack(spacing: 14) {
            plannerBoard
        }
        .frame(maxWidth: .infinity)
    }

    private var plannerBoard: some View {
        VStack(spacing: 14) {
            calendarHeader

            VStack(spacing: 12) {
                weekTokenRow

                scheduleRail
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.32))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle.opacity(0.86), lineWidth: 1)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isValid ? Color.unbound.accent.opacity(0.48) : Color.unbound.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(isValid ? 0.13 : 0), radius: 18, y: 10)
    }

    private var weekTokenRow: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                CalendarDateToken(
                    day: day,
                    dateNumber: index + 1,
                    isSelected: selection.contains(day)
                ) {
                    toggle(day)
                }
            }
        }
    }

    private var scheduleRail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(days) { day in
                    PlannerSlotColumn(
                        day: day,
                        isSelected: selection.contains(day)
                    ) {
                        toggle(day)
                    }
                }
            }

            HStack(spacing: 5) {
                ForEach(days) { day in
                    Capsule()
                        .fill(selection.contains(day) ? Color.unbound.accent : Color.unbound.borderSubtle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 3)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selection)
                }
            }
        }
        .padding(.top, 2)
    }

    private var calendarHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("WEEK PLAN")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)

                Text(statusText)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(isValid ? Color.unbound.accent : Color.unbound.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(selection.count)/\(requiredCount)")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(isValid ? Color.unbound.accent : Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.92), lineWidth: 1)
        )
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

private struct CalendarDateToken: View {
    let day: Weekday
    let dateNumber: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                Text(day.short.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? Color.unbound.textPrimary.opacity(0.74) : Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.unbound.accent : Color.unbound.surfaceElevated.opacity(0.78))
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? Color.white.opacity(0.32) : Color.unbound.borderSubtle, lineWidth: 1)
                        )

                    Text("\(dateNumber)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }
                .frame(width: 38, height: 38)

                Capsule()
                    .fill(isSelected ? Color.unbound.accent : Color.unbound.borderSubtle)
                    .frame(width: isSelected ? 20 : 5, height: 4)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.short)
    }
}

private struct PlannerSlotColumn: View {
    let day: Weekday
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isSelected ? Color.unbound.accent.opacity(0.16) : Color.unbound.surfaceElevated.opacity(0.36))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .overlay {
                        if isSelected {
                            Text("TRAIN")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .tracking(0.3)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.56)
                        } else {
                            Capsule()
                                .fill(Color.unbound.borderSubtle)
                                .frame(width: 18, height: 3)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(isSelected ? Color.unbound.accent.opacity(0.38) : Color.unbound.borderSubtle.opacity(0.78), lineWidth: 1)
                    )

                Circle()
                    .fill(isSelected ? Color.unbound.accent : Color.unbound.border)
                    .frame(width: 5, height: 5)
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.short)
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
