import SwiftUI

/// Sheet-presentation token: the day the user is swapping a loadout onto.
struct DayLoadoutPickerRequest: Identifiable {
    let id = UUID()
    let date: Date
}

/// Loadout picker presented from the selected day's action row: "make this
/// day one of MY workouts." Date → pick a loadout; selecting one places it on
/// the day as a schedule occurrence, replacing the generated session.
struct DayLoadoutPickerSheet: View {
    let date: Date
    let workouts: [SavedWorkout]
    let onSelect: (SavedWorkout) -> Void
    let onCreateNew: () -> Void
    let onDismiss: () -> Void

    private var dayLabel: String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                if workouts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(workouts) { workout in
                                loadoutRow(workout)
                            }
                            createNewRow
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Use a Loadout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }

    private func loadoutRow(_ workout: SavedWorkout) -> some View {
        let role = SessionRole.fromStorageValue(workout.sessionRole)
        let roleAccent = role?.accentColor ?? Color.unbound.accent

        return Button {
            UnboundHaptics.medium()
            onSelect(workout)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.title)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        HStack(spacing: 8) {
                            SessionRoleChip(text: role?.displayName ?? "Custom", accent: roleAccent)
                            MetaLine(["\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")"])
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .accessibilityHidden(true)
                }
                LoadoutExercisePreview(workout: workout, limit: 3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(roleAccent.opacity(0.22), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dayLoadoutPicker.workout")
    }

    private var createNewRow: some View {
        Button {
            UnboundHaptics.soft()
            onCreateNew()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("Build a new loadout")
                    .font(Font.unbound.bodyMStrong)
            }
            .foregroundStyle(Color.unbound.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.surfaceElevated, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dayLoadoutPicker.createNew")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No loadouts yet")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Build a workout once and it becomes a loadout you can drop onto any day — like \(dayLabel).")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                UnboundHaptics.medium()
                onCreateNew()
            } label: {
                Text("BUILD A LOADOUT")
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
        }
        .padding(28)
    }
}
