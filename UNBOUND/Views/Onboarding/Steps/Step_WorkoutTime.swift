import SwiftUI

struct Step_WorkoutTime: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "Workout window",
            subtitle: nil,
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.workoutTime != nil,
            hudStep: .workoutTime,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 22) {
                windowPresets

                WorkoutTimeWheel(
                    selection: $flow.workoutTime,
                    minuteOfDay: $flow.workoutMinuteOfDay
                )
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity, alignment: .center)
                .id(wheelSeed)

                Text(L10n.onboarding("workoutTime.note", defaultValue: "Session prep and reminders follow this window."))
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 430, alignment: .center)
        }
    }

    @State private var wheelSeed = UUID()

    // One-tap presets for the common windows; the wheel stays for precision.
    private var windowPresets: some View {
        HStack(spacing: 8) {
            presetChip(
                label: L10n.onboarding("workoutTime.preset.morning", defaultValue: "MORNING"),
                minute: 6 * 60 + 30
            )
            presetChip(
                label: L10n.onboarding("workoutTime.preset.lunch", defaultValue: "LUNCH"),
                minute: 12 * 60 + 15
            )
            presetChip(
                label: L10n.onboarding("workoutTime.preset.evening", defaultValue: "EVENING"),
                minute: 18 * 60 + 30
            )
        }
    }

    private func presetChip(label: String, minute: Int) -> some View {
        let isActive = flow.workoutMinuteOfDay == minute
        return Button {
            UnboundHaptics.medium()
            flow.workoutMinuteOfDay = minute
            wheelSeed = UUID()   // re-seed the wheel from the new minute
        } label: {
            Text(label)
                .font(Font.unbound.monoS)
                .tracking(1.2)
                .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isActive ? Color.unbound.accent.opacity(0.22) : Color.unbound.surface.opacity(0.7))
                )
                .overlay(
                    Capsule().strokeBorder(isActive ? Color.unbound.accent : Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// A real wheel picker — spin straight to the time you want instead of
/// tap-incrementing digits. Selection still folds into the coarse
/// `WorkoutTime` window the scheduler consumes.
private struct WorkoutTimeWheel: View {
    @Binding var selection: WorkoutTime?
    @Binding var minuteOfDay: Int?

    @State private var time = Date()

    private let defaultMinuteOfDay = 19 * 60

    var body: some View {
        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
            )
            .onAppear(perform: seed)
            .onChange(of: time) { _, _ in commit() }
    }

    private func seed() {
        let seedMinute = minuteOfDay ?? representativeMinute(for: selection) ?? defaultMinuteOfDay
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = seedMinute / 60
        components.minute = seedMinute % 60
        time = Calendar.current.date(from: components) ?? Date()
        commit()
    }

    private func commit() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let nextMinuteOfDay = (components.hour ?? 19) * 60 + (components.minute ?? 0)
        minuteOfDay = nextMinuteOfDay
        selection = workoutWindow(for: nextMinuteOfDay)
    }

    private func representativeMinute(for time: WorkoutTime?) -> Int? {
        switch time {
        case .earlyMorning: return 6 * 60
        case .morning: return 8 * 60 + 30
        case .lunch: return 12 * 60 + 30
        case .afternoon: return 15 * 60 + 30
        case .evening: return 19 * 60
        case .lateNight: return 22 * 60 + 30
        case .varies, nil: return nil
        }
    }

    private func workoutWindow(for minute: Int) -> WorkoutTime {
        switch ((minute % 1440) + 1440) % 1440 {
        case 300..<420: return .earlyMorning
        case 420..<660: return .morning
        case 660..<840: return .lunch
        case 840..<1020: return .afternoon
        case 1020..<1260: return .evening
        default: return .lateNight
        }
    }
}

#if DEBUG
#Preview {
    Step_WorkoutTime(
        flow: OnboardingFlowViewModel(),
        progress: 0.5,
        onBack: {},
        onContinue: {}
    )
}
#endif
