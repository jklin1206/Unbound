import SwiftUI

/// The saved-workouts list, rendered inline (no modal/NavigationStack chrome) for
/// the My Workouts tab. Flat calm rows on `bg` separated by hairline rules.
/// Data from SavedWorkoutStore; delete + Squad-share handled locally; use-today /
/// schedule bubble up to the parent (which applies them to the program).
struct SavedWorkoutsInlineList: View {
    @EnvironmentObject private var services: ServiceContainer
    @State private var workouts: [SavedWorkout]
    @State private var sharingWorkout: SavedWorkout?

    let onUseToday: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void

    init(
        workouts: [SavedWorkout] = SavedWorkoutStore.shared.all(),
        onUseToday: @escaping (SavedWorkout) -> Void,
        onSchedule: @escaping (SavedWorkout) -> Void
    ) {
        _workouts = State(initialValue: workouts)
        self.onUseToday = onUseToday
        self.onSchedule = onSchedule
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CalmSectionHeader(title: "SAVED", trailing: workouts.isEmpty ? nil : "\(workouts.count)")
                .padding(.bottom, 8)

            if workouts.isEmpty {
                Text("No saved workouts yet — build one or quick-log a session.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                    SavedWorkoutInlineRow(
                        workout: workout,
                        roleText: roleText(workout),
                        onUseToday: { onUseToday(workout) },
                        onSchedule: { onSchedule(workout) },
                        onShare: { sharingWorkout = workout },
                        onDelete: { delete(workout) }
                    )
                    if index < workouts.count - 1 {
                        Divider().overlay(Color.unbound.border)
                    }
                }
            }
        }
        .sheet(item: $sharingWorkout) { workout in
            InlineSquadRoutineDropShareSheet(workout: workout) { _ in sharingWorkout = nil }
                .environmentObject(services)
        }
    }

    private func delete(_ workout: SavedWorkout) {
        SavedWorkoutStore.shared.delete(id: workout.id)
        workouts.removeAll { $0.id == workout.id }
    }

    private func roleText(_ workout: SavedWorkout) -> String {
        SessionRole.fromStorageValue(workout.sessionRole)?.displayName ?? "Custom"
    }
}

// MARK: - De-boxed row

private struct SavedWorkoutInlineRow: View {
    let workout: SavedWorkout
    let roleText: String
    let onUseToday: () -> Void
    let onSchedule: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: { UnboundHaptics.soft(); onUseToday() }) {
            HStack(spacing: 12) {
                WorkoutReferenceImageView(
                    exerciseName: workout.effectiveReferenceExerciseName,
                    fallbackSystemName: "dumbbell.fill",
                    fallbackTint: Color.unbound.textSecondary
                )
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    MetaLine(["\(workout.exerciseCount) exercises", "\(workout.estimatedMinutes)m", roleText.uppercased()])
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.coachCyan)
                    .accessibilityHidden(true)

                Menu {
                    Button { onSchedule() } label: { Label("Schedule", systemImage: "calendar.badge.plus") }
                    Button { onShare() } label: { Label("Drop to Squad", systemImage: "paperplane.fill") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 30, height: 38)
                }
                .menuStyle(.button)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Use \(workout.title) today")
    }
}

// MARK: - Squad share sheet (moved here from SavedWorkoutsListView so it compiles
//         when used by this inline list; SavedWorkoutsListView retains its own
//         private copy for its own usage).

struct InlineSquadRoutineDropShareSheet: View {
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    let workout: SavedWorkout
    let onShared: (SquadRoutineDrop) -> Void

    @State private var note = ""
    @State private var isSharing = false
    @State private var errorMessage: String?

    private var currentSquadState: SquadState? {
        guard let userId = services.auth.currentUserId else { return nil }
        return services.squads.state(userId: userId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    workoutSummary

                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.3)
                            .foregroundStyle(Color.unbound.textTertiary)

                        TextEditor(text: $note)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 96, maxHeight: 118)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.unbound.surfaceElevated.opacity(0.88))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                            )
                            .onChange(of: note) { _, newValue in
                                if newValue.count > 180 {
                                    note = String(newValue.prefix(180))
                                }
                            }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.alert)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        share()
                    } label: {
                        HStack(spacing: 10) {
                            if isSharing {
                                ProgressView()
                                    .tint(Color.unbound.bg)
                            }
                            Text(isSharing ? "DROPPING" : "DROP TO SQUAD")
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.1)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.unbound.bg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(canShare ? Color.unbound.accent : Color.unbound.surfaceElevated)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canShare || isSharing)
                }
                .padding(20)
            }
            .navigationTitle("Share Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }

    private var workoutSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            WorkoutReferenceImageView(
                exerciseName: workout.effectiveReferenceExerciseName,
                fallbackSystemName: "square.and.arrow.up.fill",
                fallbackTint: Color.unbound.warnOrange
            )
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(workout.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                Text("\(workout.exerciseCount) exercises - \(workout.estimatedMinutes)m")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(currentSquadState?.currentSquad?.name ?? "Join a squad before dropping routines.")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(currentSquadState?.currentSquad == nil ? Color.unbound.alert : Color.unbound.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var canShare: Bool {
        guard let userId = services.auth.currentUserId,
              SquadUserIdentity.uuid(from: userId) != nil,
              currentSquadState?.currentSquad != nil
        else { return false }
        return true
    }

    private func share() {
        guard let userId = services.auth.currentUserId,
              let authorId = SquadUserIdentity.uuid(from: userId),
              let state = currentSquadState,
              let squad = state.currentSquad
        else {
            errorMessage = "Join a squad before sharing routines."
            return
        }

        isSharing = true
        errorMessage = nil

        Task {
            let authorName = state.roster.first(where: { $0.userId == authorId })?.displayName ?? "You"
            let drop = await SquadRoutineDropService.shared.share(
                workout: workout,
                note: note,
                squad: squad,
                authorUserId: authorId,
                authorDisplayName: authorName
            )

            await MainActor.run {
                isSharing = false
                onShared(drop)
                dismiss()
            }
        }
    }
}
