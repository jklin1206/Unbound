import SwiftUI

/// Post-onboarding editor for the *real* training schedule: which weekdays you
/// train, how long each session runs, and what time of day you train. Saving
/// rewrites the profile and regenerates the current arc from today forward, so
/// the change is immediately visible on the Program tab.
///
/// This is the single home for schedule edits. Notification reminders (Settings)
/// only control pings; saving here keeps any enabled reminders in step so the two
/// never silently drift apart.
struct TrainingScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialTrainingDays: Set<Weekday>
    let initialSessionLength: SessionLength
    /// Minute-of-day (0–1439) the user trains at.
    let initialWorkoutMinuteOfDay: Int
    /// Persists + regenerates. Returns `nil` on success, or an error message to show.
    let onApply: (Set<Weekday>, SessionLength, Int) async -> String?

    @State private var trainingDays: Set<Weekday>
    @State private var sessionLength: SessionLength
    @State private var workoutMinuteOfDay: Int
    @State private var isApplying = false
    @State private var errorMessage: String?

    private static let minDays = 3
    private static let maxDays = 6

    init(
        initialTrainingDays: Set<Weekday>,
        initialSessionLength: SessionLength,
        initialWorkoutMinuteOfDay: Int,
        onApply: @escaping (Set<Weekday>, SessionLength, Int) async -> String?
    ) {
        self.initialTrainingDays = initialTrainingDays
        self.initialSessionLength = initialSessionLength
        self.initialWorkoutMinuteOfDay = initialWorkoutMinuteOfDay
        self.onApply = onApply
        _trainingDays = State(initialValue: initialTrainingDays)
        _sessionLength = State(initialValue: initialSessionLength)
        _workoutMinuteOfDay = State(initialValue: initialWorkoutMinuteOfDay)
    }

    private var dayCount: Int { trainingDays.count }
    private var isValid: Bool { (Self.minDays...Self.maxDays).contains(dayCount) }
    private var isDirty: Bool {
        trainingDays != initialTrainingDays
            || sessionLength != initialSessionLength
            || workoutMinuteOfDay != initialWorkoutMinuteOfDay
    }
    private var canApply: Bool { isValid && isDirty && !isApplying }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    daysSection
                    sessionLengthSection
                    timeSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TRAINING SCHEDULE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.accent)
                Text("Which days, how long, when.")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.6)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Training days

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DAYS YOU TRAIN", trailing: daysStatus)

            HStack(spacing: 6) {
                ForEach(Weekday.allCases) { day in
                    dayChip(day)
                }
            }
        }
    }

    private var daysStatus: String {
        isValid ? "\(dayCount) days a week" : "Pick \(Self.minDays)–\(Self.maxDays)"
    }

    private func dayChip(_ day: Weekday) -> some View {
        let isOn = trainingDays.contains(day)
        return Button {
            toggle(day)
        } label: {
            Text(day.short.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(isOn ? Color.unbound.bg : Color.unbound.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isOn ? Color.unbound.accent : Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isOn ? Color.clear : Color.unbound.borderSubtle, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ day: Weekday) {
        UnboundHaptics.soft()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if trainingDays.contains(day) {
                trainingDays.remove(day)
            } else if dayCount < Self.maxDays {
                trainingDays.insert(day)
            } else {
                UnboundHaptics.tick()
            }
        }
    }

    // MARK: - Session length

    private var sessionLengthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SESSION LENGTH", trailing: nil)

            HStack(spacing: 6) {
                ForEach(SessionLength.allCases) { length in
                    optionChip(
                        title: length == .ninetyPlus ? "90+" : "\(length.minutes)",
                        subtitle: "MIN",
                        isOn: sessionLength == length
                    ) {
                        UnboundHaptics.soft()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sessionLength = length
                        }
                    }
                }
            }
        }
    }

    // MARK: - Time of day

    private var timeSection: some View {
        let bucket = WorkoutTime.bucket(forMinuteOfDay: workoutMinuteOfDay)
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TIME OF DAY", trailing: nil)

            HStack(spacing: 12) {
                Image(systemName: bucket.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 26)
                Text(bucket.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                DatePicker(
                    "",
                    selection: timeBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.unbound.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }

    /// Bridges the stored minute-of-day to the native time picker's `Date`.
    private var timeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinuteOfDay: workoutMinuteOfDay) },
            set: { workoutMinuteOfDay = Self.minuteOfDay(from: $0) }
        )
    }

    private static func date(fromMinuteOfDay minute: Int) -> Date {
        let calendar = Calendar.current
        let clamped = min(max(minute, 0), 24 * 60 - 1)
        return calendar.date(
            bySettingHour: clamped / 60,
            minute: clamped % 60,
            second: 0,
            of: calendar.startOfDay(for: Date())
        ) ?? Date()
    }

    private static func minuteOfDay(from date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.alert)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }

            Button {
                Task { await apply() }
            } label: {
                HStack(spacing: 8) {
                    if isApplying {
                        ProgressView().controlSize(.small).tint(Color.unbound.bg)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(isApplying ? "REBUILDING…" : "SAVE SCHEDULE")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                }
                .foregroundStyle(Color.unbound.bg)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canApply)
            .opacity(canApply ? 1 : 0.45)

            Text("Reshapes your plan from today forward. Days you've already logged stay logged.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
    }

    // MARK: - Shared pieces

    private func sectionLabel(_ title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Font.unbound.captionS.weight(.bold))
                    .foregroundStyle(isValid ? Color.unbound.accent : Color.unbound.textTertiary)
            }
        }
    }

    private func optionChip(
        title: String,
        subtitle: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text(subtitle)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
            }
            .foregroundStyle(isOn ? Color.unbound.bg : Color.unbound.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? Color.unbound.accent : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isOn ? Color.clear : Color.unbound.borderSubtle, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func apply() async {
        guard canApply else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            isApplying = true
            errorMessage = nil
        }
        let result = await onApply(trainingDays, sessionLength, workoutMinuteOfDay)
        if let result {
            withAnimation(.easeInOut(duration: 0.15)) {
                errorMessage = result
                isApplying = false
            }
            UnboundHaptics.tick()
        } else {
            UnboundHaptics.success()
            dismiss()
        }
    }
}
