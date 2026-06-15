import SwiftUI

/// The saved-workouts list, rendered inline (no modal/NavigationStack chrome) for
/// the Loadouts tab. Flat calm rows on `bg` separated by hairline rules.
/// Data from SavedWorkoutStore; delete + Squad-share handled locally; start /
/// schedule bubble up to the parent (which applies them to the program).
struct SavedWorkoutsInlineList: View {
    @EnvironmentObject private var services: ServiceContainer
    @State private var workouts: [SavedWorkout]
    @State private var sharingWorkout: SavedWorkout?

    let refreshTrigger: Int
    let onStartWorkout: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void

    init(
        refreshTrigger: Int = 0,
        workouts: [SavedWorkout] = SavedWorkoutStore.shared.all(),
        onStartWorkout: @escaping (SavedWorkout) -> Void,
        onSchedule: @escaping (SavedWorkout) -> Void
    ) {
        _workouts = State(initialValue: workouts)
        self.refreshTrigger = refreshTrigger
        self.onStartWorkout = onStartWorkout
        self.onSchedule = onSchedule
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
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                    SavedWorkoutInlineRow(
                        workout: workout,
                        roleText: roleText(workout),
                        onStartWorkout: { onStartWorkout(workout) },
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

    private func roleText(_ workout: SavedWorkout) -> String {
        SessionRole.fromStorageValue(workout.sessionRole)?.displayName ?? "Custom"
    }
}

// MARK: - De-boxed row

private struct SavedWorkoutInlineRow: View {
    let workout: SavedWorkout
    let roleText: String
    let onStartWorkout: () -> Void
    let onSchedule: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { expanded.toggle() }
                UnboundHaptics.soft()
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    WorkoutReferenceImageView(
                        exerciseName: workout.effectiveReferenceExerciseName,
                        fallbackSystemName: "dumbbell.fill",
                        fallbackTint: Color.unbound.textSecondary,
                        size: .hero
                    )
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.title)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                        MetaLine(["\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")", "\(workout.estimatedMinutes)m", roleText.uppercased()])
                    }
                    .padding(.top, 3)

                    Spacer(minLength: 8)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(workout.title), \(workout.exerciseCount) exercises, tap to \(expanded ? "collapse" : "expand")")

            // Expanded area
            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    // Exercise lines
                    let prescriptions = workout.blocks.flatMap(\.prescriptions)
                    if !prescriptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(prescriptions) { prescription in
                                HStack(spacing: 8) {
                                    Text(prescription.exerciseName)
                                        .font(Font.unbound.bodyM)
                                        .foregroundStyle(Color.unbound.textPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: 8)
                                    Text("\(prescription.sets) × \(prescription.target.displayText)")
                                        .font(Font.unbound.monoS.weight(.medium))
                                        .foregroundStyle(Color.unbound.textSecondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .padding(.leading, 86)
                        .padding(.bottom, 14)
                    }

                    // Primary start action
                    Button {
                        UnboundHaptics.medium()
                        onStartWorkout()
                    } label: {
                        Text("Start Loadout")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.unbound.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start \(workout.title)")

                    // Secondary actions
                    HStack(spacing: 8) {
                        secondaryAction(
                            title: "Schedule",
                            icon: "calendar.badge.plus",
                            tint: Color.unbound.coachCyan,
                            action: onSchedule
                        )
                        .accessibilityIdentifier("myWorkouts.schedule")

                        secondaryAction(
                            title: "Drop",
                            icon: "paperplane.fill",
                            tint: Color.unbound.warnOrange,
                            action: onShare
                        )
                        .accessibilityIdentifier("myWorkouts.dropToSquad")

                        secondaryAction(
                            title: "Delete",
                            icon: "trash",
                            tint: Color.unbound.alert,
                            action: onDelete
                        )
                        .accessibilityIdentifier("myWorkouts.delete")
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func secondaryAction(
        title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UnboundHaptics.soft()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(workout.title)")
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
