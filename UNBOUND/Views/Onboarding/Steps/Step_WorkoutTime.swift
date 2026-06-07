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
            VStack {
                WorkoutTimeDigitalClock(
                    selection: $flow.workoutTime,
                    minuteOfDay: $flow.workoutMinuteOfDay
                )
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 92)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct WorkoutTimeDigitalClock: View {
    @Binding var selection: WorkoutTime?
    @Binding var minuteOfDay: Int?

    @State private var hour = 7
    @State private var minute = 0
    @State private var period: ClockPeriod = .pm
    @State private var activeSegment: ClockSegment = .hour

    private let defaultMinuteOfDay = 19 * 60

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ClockNumberSegment(
                text: String(format: "%02d", hour),
                label: "HOUR",
                isActive: activeSegment == .hour
            ) {
                activeSegment = .hour
                adjustHour(by: 1)
            }

            BlinkingColon()

            ClockNumberSegment(
                text: String(format: "%02d", minute),
                label: "MIN",
                isActive: activeSegment == .minute
            ) {
                activeSegment = .minute
                adjustMinute(by: 5)
            }

            ClockPeriodSegment(
                period: period,
                isActive: activeSegment == .period
            ) {
                activeSegment = .period
                togglePeriod()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 18)
        }
        .onAppear {
            seedClock()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: hour)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: minute)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: period)
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: activeSegment)
    }

    private func seedClock() {
        let seedMinute = minuteOfDay ?? representativeMinute(for: selection) ?? defaultMinuteOfDay
        let parts = clockParts(for: seedMinute)
        hour = parts.hour
        minute = parts.minute
        period = parts.period
        commit()
    }

    private func adjustHour(by delta: Int) {
        UnboundHaptics.soft()
        hour = wrappedHour(hour + delta)
        commit()
    }

    private func adjustMinute(by delta: Int) {
        UnboundHaptics.soft()
        let currentMinute = period.minuteOfDay(hour: hour, minute: minute)
        let parts = clockParts(for: currentMinute + delta)
        hour = parts.hour
        minute = parts.minute
        period = parts.period
        commit()
    }

    private func togglePeriod() {
        UnboundHaptics.soft()
        period = period == .am ? .pm : .am
        commit()
    }

    private func commit() {
        let nextMinuteOfDay = period.minuteOfDay(hour: hour, minute: minute)
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
        switch normalized(minute) {
        case 300..<420: return .earlyMorning
        case 420..<660: return .morning
        case 660..<840: return .lunch
        case 840..<1020: return .afternoon
        case 1020..<1260: return .evening
        default: return .lateNight
        }
    }

    private func clockParts(for minuteOfDay: Int) -> (hour: Int, minute: Int, period: ClockPeriod) {
        let normalizedMinute = normalized(minuteOfDay)
        let hour24 = normalizedMinute / 60
        let displayHour = hour24 % 12 == 0 ? 12 : hour24 % 12
        return (displayHour, normalizedMinute % 60, ClockPeriod(minuteOfDay: normalizedMinute))
    }

    private func normalized(_ minute: Int) -> Int {
        let day = 24 * 60
        return ((minute % day) + day) % day
    }

    private func wrappedHour(_ value: Int) -> Int {
        ((value - 1) % 12 + 12) % 12 + 1
    }
}

private struct ClockNumberSegment: View {
    let text: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(isActive ? Color.unbound.accent : Color.unbound.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.unbound.accent.opacity(0.16) : Color.unbound.bg.opacity(0.38))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isActive ? Color.unbound.accent.opacity(0.62) : Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ClockPeriodSegment: View {
    let period: ClockPeriod
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(period.rawValue)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.accent)
                .frame(width: 48, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isActive ? Color.unbound.accent.opacity(0.18) : Color.unbound.surfaceElevated.opacity(0.86))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isActive ? Color.unbound.accent.opacity(0.62) : Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BlinkingColon: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let second = Calendar.current.component(.second, from: context.date)
            Text(":")
                .font(.system(size: 44, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.accent)
                .opacity(second.isMultiple(of: 2) ? 1 : 0.35)
        }
        .frame(width: 18)
    }
}

private enum ClockSegment: Hashable {
    case hour
    case minute
    case period
}

private enum ClockPeriod: String, CaseIterable {
    case am = "AM"
    case pm = "PM"

    init(minuteOfDay: Int) {
        self = minuteOfDay < 12 * 60 ? .am : .pm
    }

    func minuteOfDay(hour: Int, minute: Int) -> Int {
        let normalizedHour = hour == 12 ? 0 : min(max(hour, 1), 12)
        let clampedMinute = min(max(minute, 0), 59)
        let twelveHourMinute = normalizedHour * 60 + clampedMinute

        switch self {
        case .am: return twelveHourMinute
        case .pm: return twelveHourMinute + 12 * 60
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
