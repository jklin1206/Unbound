import SwiftUI

/// The saved-workouts list, rendered inline (no modal/NavigationStack chrome) for
/// the Loadouts tab. Each loadout is a title-first `surface` card showing its
/// full exercise list (always expanded), an always-visible Start button, and a
/// top-right ⋯ menu for share / edit / delete.
/// Data from SavedWorkoutStore; delete + Squad-share handled locally; start /
/// edit bubble up to the parent (which starts the session or opens the editor).
struct SavedWorkoutsInlineList: View {
    @EnvironmentObject private var services: ServiceContainer
    @State private var workouts: [SavedWorkout]
    @State private var sharingWorkout: SavedWorkout?

    let refreshTrigger: Int
    let onStartWorkout: (SavedWorkout) -> Void
    let onEdit: (SavedWorkout) -> Void

    init(
        refreshTrigger: Int = 0,
        workouts: [SavedWorkout] = SavedWorkoutStore.shared.all(),
        onStartWorkout: @escaping (SavedWorkout) -> Void,
        onEdit: @escaping (SavedWorkout) -> Void
    ) {
        _workouts = State(initialValue: workouts)
        self.refreshTrigger = refreshTrigger
        self.onStartWorkout = onStartWorkout
        self.onEdit = onEdit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CalmSectionHeader(title: "LOADOUTS", trailing: workouts.isEmpty ? nil : "\(workouts.count)")
                .padding(.bottom, 8)

            if workouts.isEmpty {
                Text("No loadouts yet - create one or quick-log a quest.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(workouts) { workout in
                        let role = SessionRole.fromStorageValue(workout.sessionRole)
                        SavedWorkoutInlineRow(
                            workout: workout,
                            roleText: role?.displayName ?? "Custom",
                            roleAccent: role?.accentColor ?? Color.unbound.accent,
                            onStartWorkout: { onStartWorkout(workout) },
                            onEdit: { onEdit(workout) },
                            onShare: { sharingWorkout = workout },
                            onDelete: { delete(workout) }
                        )
                    }
                }
            }
        }
        .sheet(item: $sharingWorkout) { workout in
            SquadRoutineDropShareSheet(workout: workout) { _ in sharingWorkout = nil }
                .environmentObject(services)
        }
        .onAppear {
            reload()
        }
        .onChange(of: refreshTrigger) { _, _ in
            reload()
        }
    }

    private func delete(_ workout: SavedWorkout) {
        SavedWorkoutStore.shared.delete(id: workout.id)
        workouts.removeAll { $0.id == workout.id }
    }

    private func reload() {
        workouts = SavedWorkoutStore.shared.all()
    }
}

// MARK: - Loadout card row

private struct SavedWorkoutInlineRow: View {
    let workout: SavedWorkout
    let roleText: String
    let roleAccent: Color
    let onStartWorkout: () -> Void
    let onEdit: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title + the full exercise list — always expanded, nothing hidden.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(workout.title)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: 8) {
                        SessionRoleChip(text: roleText, accent: roleAccent)
                        MetaLine(["\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")"])
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 40)

                LoadoutExercisePreview(workout: workout, limit: nil)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Start is always one tap away — no expand needed.
            Button {
                UnboundHaptics.medium()
                onStartWorkout()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Start")
                        .font(Font.unbound.bodyMStrong)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(workout.title)")
            .accessibilityIdentifier("myWorkouts.start")
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(roleAccent.opacity(0.26), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            actionsMenu
                .padding(.top, 8)
                .padding(.trailing, 8)
        }
        .shadow(color: roleAccent.opacity(0.14), radius: 14, x: 0, y: 6)
    }

    /// Share / edit / delete live behind one top-right overflow menu.
    private var actionsMenu: some View {
        Menu {
            Button {
                onShare()
            } label: {
                Label("Share to Squad", systemImage: "paperplane")
            }

            Button {
                onEdit()
            } label: {
                Label("Edit Loadout", systemImage: "slider.horizontal.3")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Loadout actions for \(workout.title)")
        .accessibilityIdentifier("myWorkouts.actions")
    }
}

// MARK: - Squad share sheet

private struct SquadRoutineDropShareSheet: View {
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
            .navigationTitle("Share Loadout")
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
                Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s") - \(workout.estimatedMinutes)m")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(currentSquadState?.currentSquad?.name ?? "Join a squad before dropping loadouts.")
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
            errorMessage = "Join a squad before sharing loadouts."
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
                UnboundHaptics.success()
                onShared(drop)
                dismiss()
            }
        }
    }
}
