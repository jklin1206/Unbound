import SwiftUI

struct SavedWorkoutsListView: View {
    @State private var workouts: [SavedWorkout]

    let onReplaceToday: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void
    let onDismiss: () -> Void

    init(
        workouts: [SavedWorkout] = SavedWorkoutStore.shared.all(),
        onReplaceToday: @escaping (SavedWorkout) -> Void,
        onSchedule: @escaping (SavedWorkout) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _workouts = State(initialValue: workouts)
        self.onReplaceToday = onReplaceToday
        self.onSchedule = onSchedule
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                if workouts.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(workouts) { workout in
                                savedWorkoutRow(workout)
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Saved Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No Saved Workouts")
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Save an edited session first. Saved Workouts live on this phone in v1.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func savedWorkoutRow(_ workout: SavedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                    Text("\(workout.exerciseCount) exercises · \(workout.estimatedMinutes)m · \(roleText(workout))")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Button(role: .destructive) {
                    SavedWorkoutStore.shared.delete(id: workout.id)
                    workouts = SavedWorkoutStore.shared.all()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.alert)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.unbound.alert.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(workout.title)")
            }

            HStack(spacing: 10) {
                Button {
                    onReplaceToday(workout)
                } label: {
                    Label("Today", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SavedWorkoutActionButtonStyle(tint: Color.unbound.coachCyan))

                Button {
                    onSchedule(workout)
                } label: {
                    Label("Schedule", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SavedWorkoutActionButtonStyle(tint: Color.unbound.accent))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func roleText(_ workout: SavedWorkout) -> String {
        SessionRole.fromStorageValue(workout.sessionRole)?.displayName ?? "Custom"
    }
}

private struct SavedWorkoutActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.unbound.captionS.weight(.heavy))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(height: 38)
            .background(
                Capsule().fill(tint.opacity(configuration.isPressed ? 0.18 : 0.10))
            )
            .overlay(Capsule().strokeBorder(tint.opacity(0.26), lineWidth: 1))
    }
}
