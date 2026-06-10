import SwiftUI

/// Date picker presented when the user taps Schedule on a saved workout.
/// Picks an explicit calendar day; the parent places the workout there and
/// jumps to it on the PROGRAM tab.
struct ScheduleWorkoutDateSheet: View {
    let workout: SavedWorkout
    let today: Date
    let onSchedule: (Date) -> Void
    let onDismiss: () -> Void

    @State private var selectedDate: Date

    init(
        workout: SavedWorkout,
        today: Date,
        onSchedule: @escaping (Date) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.workout = workout
        self.today = today
        self.onSchedule = onSchedule
        self.onDismiss = onDismiss
        _selectedDate = State(initialValue: today)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.title)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        MetaLine(["\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")", "\(workout.estimatedMinutes) min"])
                    }

                    DatePicker(
                        "Schedule date",
                        selection: $selectedDate,
                        in: today...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color.unbound.accent)
                    .labelsHidden()

                    Spacer(minLength: 0)

                    Button {
                        UnboundHaptics.medium()
                        onSchedule(selectedDate)
                    } label: {
                        Text("SCHEDULE")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.unbound.accent)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("scheduleWorkout.confirm")
                }
                .padding(20)
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }
}
