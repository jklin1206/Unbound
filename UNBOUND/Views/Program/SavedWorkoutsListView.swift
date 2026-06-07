import SwiftUI

struct SavedWorkoutsListView: View {
    @EnvironmentObject private var services: ServiceContainer
    @State private var workouts: [SavedWorkout]
    @State private var sharingWorkout: SavedWorkout?
    @State private var selectedRole: String?

    let onCreateNew: () -> Void
    let onReplaceToday: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void
    let onDismiss: () -> Void

    init(
        workouts: [SavedWorkout] = SavedWorkoutStore.shared.all(),
        onCreateNew: @escaping () -> Void,
        onReplaceToday: @escaping (SavedWorkout) -> Void,
        onSchedule: @escaping (SavedWorkout) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _workouts = State(initialValue: workouts)
        self.onCreateNew = onCreateNew
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
                        VStack(alignment: .leading, spacing: 12) {
                            libraryHeader
                            roleRail
                            LazyVStack(spacing: 8) {
                                ForEach(filteredWorkouts) { workout in
                                    SavedWorkoutLibraryRow(
                                        workout: workout,
                                        roleText: roleText(workout),
                                        onUseToday: { onReplaceToday(workout) },
                                        onSchedule: { onSchedule(workout) },
                                        onShare: { sharingWorkout = workout },
                                        onDelete: { delete(workout) }
                                    )
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Saved Workouts")
            .sheet(item: $sharingWorkout) { workout in
                SquadRoutineDropShareSheet(workout: workout) { _ in
                    sharingWorkout = nil
                }
                .environmentObject(services)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }

    private var filteredWorkouts: [SavedWorkout] {
        guard let selectedRole else { return workouts }
        return workouts.filter { roleKey($0) == selectedRole }
    }

    private var roleFilters: [SavedWorkoutRoleFilter] {
        let roles = Dictionary(grouping: workouts, by: roleKey)
        return roles
            .map { key, workouts in
                SavedWorkoutRoleFilter(
                    id: key,
                    title: roleTitle(for: key, sample: workouts.first),
                    count: workouts.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LIBRARY")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("\(workouts.count) saved")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
            }

            Spacer(minLength: 10)

            Button {
                onCreateNew()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("savedWorkouts.plan.inline")
        }
    }

    private var roleRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                roleFilterChip(
                    title: "All",
                    count: workouts.count,
                    isSelected: selectedRole == nil,
                    action: { selectedRole = nil }
                )
                ForEach(roleFilters) { filter in
                    roleFilterChip(
                        title: filter.title,
                        count: filter.count,
                        isSelected: selectedRole == filter.id,
                        action: { selectedRole = filter.id }
                    )
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func roleFilterChip(
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                action()
            }
        } label: {
            HStack(spacing: 7) {
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.8)
                Text("\(count)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Capsule().fill(isSelected ? Color.unbound.accent.opacity(0.22) : Color.unbound.surface))
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.unbound.accent.opacity(0.54) : Color.unbound.borderSubtle,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No Saved Workouts")
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            Button {
                onCreateNew()
            } label: {
                Label("Build", systemImage: "plus.square.on.square")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(
                        Capsule().fill(Color.unbound.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityIdentifier("savedWorkouts.empty.plan")
        }
    }

    private func roleText(_ workout: SavedWorkout) -> String {
        SessionRole.fromStorageValue(workout.sessionRole)?.displayName ?? "Custom"
    }

    private func roleKey(_ workout: SavedWorkout) -> String {
        SavedWorkout.normalizedSessionRole(workout.sessionRole) ?? "custom"
    }

    private func roleTitle(for key: String, sample: SavedWorkout?) -> String {
        if let sample {
            return roleText(sample)
        }
        return key
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func delete(_ workout: SavedWorkout) {
        SavedWorkoutStore.shared.delete(id: workout.id)
        workouts = SavedWorkoutStore.shared.all()
        if let selectedRole, !workouts.contains(where: { roleKey($0) == selectedRole }) {
            self.selectedRole = nil
        }
    }
}

private struct SavedWorkoutRoleFilter: Identifiable {
    let id: String
    let title: String
    let count: Int

    var sortIndex: Int {
        let order = [
            "push",
            "pull",
            "legs",
            "upper",
            "lower",
            "full-body",
            "full_body",
            "skill-only",
            "skill_only",
            "cardio",
            "custom"
        ]
        return order.firstIndex(of: id) ?? 999
    }
}

private struct SavedWorkoutLibraryRow: View {
    let workout: SavedWorkout
    let roleText: String
    let onUseToday: () -> Void
    let onSchedule: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            roleBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(workout.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    metric("\(workout.exerciseCount)", icon: "list.bullet")
                    metric("\(workout.estimatedMinutes)m", icon: "timer")
                    Text(roleText.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer(minLength: 8)

            Button(action: onUseToday) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.bg)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.coachCyan))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Use \(workout.title) today")

            Menu {
                Button {
                    onSchedule()
                } label: {
                    Label("Schedule", systemImage: "calendar.badge.plus")
                }

                Button {
                    onShare()
                } label: {
                    Label("Drop to Squad", systemImage: "paperplane.fill")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 38)
            }
            .menuStyle(.button)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var roleBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(roleTint.opacity(0.16))
            Image(systemName: roleIcon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(roleTint)
        }
        .frame(width: 44, height: 44)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(roleTint.opacity(0.28), lineWidth: 1)
        )
    }

    private func metric(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text.uppercased())
                .font(Font.unbound.monoS.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(Color.unbound.textSecondary)
        .lineLimit(1)
    }

    private var role: SessionRole {
        SessionRole.fromStorageValue(workout.sessionRole) ?? .custom("custom")
    }

    private var roleIcon: String {
        switch role {
        case .push, .pushVertical, .pushHorizontal, .broChest, .broShoulders:
            return "arrow.up.right"
        case .pull, .pullFocus, .broBack:
            return "arrow.down.left"
        case .legs, .lower, .squatFocus:
            return "figure.strengthtraining.functional"
        case .upper, .fullBody:
            return "figure.strengthtraining.traditional"
        case .cardio:
            return "bolt.heart.fill"
        case .skillOnly:
            return "scope"
        case .rest:
            return "moon.zzz.fill"
        case .broArms:
            return "dumbbell.fill"
        case .custom:
            return "square.grid.2x2"
        }
    }

    private var roleTint: Color {
        switch role {
        case .push, .pushVertical, .pushHorizontal, .broChest, .broShoulders:
            return Color.unbound.accent
        case .pull, .pullFocus, .broBack:
            return Color.unbound.coachCyan
        case .legs, .lower, .squatFocus:
            return Color.unbound.success
        case .upper, .fullBody:
            return Color.unbound.warnOrange
        case .cardio:
            return Color.unbound.alert
        case .skillOnly:
            return Color.unbound.coachCyan
        case .rest:
            return Color.unbound.textSecondary
        case .broArms, .custom:
            return Color.unbound.textPrimary.opacity(0.72)
        }
    }
}

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
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.warnOrange)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.unbound.warnOrange.opacity(0.14)))

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
