import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var services: ServiceContainer
    var programId: String = ""
    var dayNumber: Int = 0
    /// Optional viewmodel binding — when present, edit mode is enabled and
    /// mutations route through it so they persist back to the program doc.
    var programViewModel: ProgramViewModel? = nil

    @State private var showLogging = false
    @State private var isEditing = false
    @State private var swapTargetExerciseId: String?
    @State private var swapAlternatives: [CatalogExercise] = []
    @State private var swapPreferences: [ExercisePreference] = []

    /// Live exercises — read from the viewModel when present so swaps and
    /// sets/reps edits show up immediately. Falls back to the static
    /// passed-in workout when there's no viewModel (legacy callsites).
    private var liveMainExercises: [Exercise] {
        if let vm = programViewModel,
           let day = vm.program?.days.first(where: { $0.dayNumber == dayNumber }),
           let live = day.workout?.mainExercises {
            return live
        }
        return workout.mainExercises
    }

    private var canEdit: Bool {
        programViewModel != nil
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    workoutHeader

                    if !workout.warmup.isEmpty {
                        exerciseSection(
                            title: "Warmup",
                            icon: "figure.run",
                            exercises: workout.warmup,
                            editable: false
                        )
                    }

                    exerciseSection(
                        title: "Main Workout",
                        icon: "dumbbell.fill",
                        exercises: liveMainExercises,
                        editable: canEdit
                    )

                    if !workout.cooldown.isEmpty {
                        exerciseSection(
                            title: "Cooldown",
                            icon: "figure.cooldown",
                            exercises: workout.cooldown,
                            editable: false
                        )
                    }

                    if !isEditing {
                        GradientButton(title: "Log Workout", action: {
                            showLogging = true
                        })
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UnboundHaptics.soft()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            isEditing.toggle()
                        }
                        if !isEditing {
                            // Just exited edit mode — persist.
                            Task { await programViewModel?.saveProgram() }
                        }
                    } label: {
                        Text(isEditing ? "Done" : "Edit")
                            .font(.bodyMedium(15))
                            .foregroundColor(isEditing ? .theme.primary : .theme.textSecondary)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showLogging) {
            ActiveWorkoutContainerView(
                workout: liveWorkout,
                programId: programId,
                dayNumber: dayNumber,
                services: services
            )
        }
        .sheet(item: Binding(
            get: { swapTargetExerciseId.map(SwapTarget.init(id:)) },
            set: { swapTargetExerciseId = $0?.id }
        )) { target in
            ExerciseSwapSheet(
                currentExerciseName: liveMainExercises.first(where: { $0.id == target.id })?.name ?? "",
                alternatives: swapAlternatives,
                onSelect: { alt in
                    Task { await applySwap(exerciseId: target.id, replacement: alt) }
                }
            )
        }
        .task {
            if canEdit, let userId = services.auth.currentUserId {
                swapPreferences = (try? await services.exercisePreference.fetchPreferences(userId: userId)) ?? []
            }
        }
    }

    /// Compose a workout that reflects in-memory edits when launching the
    /// logging flow. Without this, edits made on this screen wouldn't show
    /// up until next program load.
    private var liveWorkout: Workout {
        var copy = workout
        copy.mainExercises = liveMainExercises
        return copy
    }

    private struct SwapTarget: Identifiable {
        let id: String
    }

    private func presentSwap(for exerciseId: String) {
        let current = liveMainExercises.first(where: { $0.id == exerciseId })?.name ?? ""
        let prefsByKey = Dictionary(uniqueKeysWithValues: swapPreferences.map { ($0.exerciseName.lowercased(), $0) })
        let alts = ExerciseCatalog.alternatives(to: current).filter { alt in
            prefsByKey[alt.name.lowercased()]?.status != .avoid
        }
        .sorted { a, b in
            let aAvail = prefsByKey[a.name.lowercased()]?.status == .available
            let bAvail = prefsByKey[b.name.lowercased()]?.status == .available
            if aAvail != bAvail { return aAvail && !bAvail }
            return a.displayName < b.displayName
        }
        swapAlternatives = alts
        swapTargetExerciseId = exerciseId
        UnboundHaptics.medium()
    }

    private func applySwap(exerciseId: String, replacement: CatalogExercise) async {
        programViewModel?.swapExercise(
            dayNumber: dayNumber,
            exerciseId: exerciseId,
            replacement: replacement
        )
        await programViewModel?.saveProgram()
        UnboundHaptics.success()
    }

    // MARK: - Header

    private var workoutHeader: some View {
        HStack(spacing: 0) {
            statCell(value: "\(liveMainExercises.count)", label: "Exercises")
            Divider().frame(height: 40).background(Color.theme.surfaceLight)
            statCell(value: "\(workout.estimatedMinutes)", label: "Minutes")
            Divider().frame(height: 40).background(Color.theme.surfaceLight)
            statCell(
                value: workout.targetMuscleGroups.prefix(2).map(\.displayName).joined(separator: "/"),
                label: "Focus"
            )
        }
        .padding(.vertical, 16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.bodyMedium(16))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption(12))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseSection(
        title: String,
        icon: String,
        exercises: [Exercise],
        editable: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            VStack(spacing: 8) {
                ForEach(exercises) { exercise in
                    if editable && isEditing {
                        EditableExerciseRow(
                            exercise: exercise,
                            onSetsChange: { newSets in
                                programViewModel?.updateSetsReps(
                                    dayNumber: dayNumber,
                                    exerciseId: exercise.id,
                                    sets: newSets
                                )
                            },
                            onRepsChange: { newReps in
                                programViewModel?.updateSetsReps(
                                    dayNumber: dayNumber,
                                    exerciseId: exercise.id,
                                    reps: newReps
                                )
                            },
                            onSwapTapped: {
                                presentSwap(for: exercise.id)
                            }
                        )
                    } else {
                        ExerciseRow(exercise: exercise)
                    }
                }
            }
        }
    }
}

// MARK: - Read-only Row

private struct ExerciseRow: View {
    let exercise: Exercise
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.bodyMedium(15))
                            .foregroundColor(.theme.textPrimary)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Text("\(exercise.sets) × \(exercise.reps)")
                                .font(.caption(13))
                                .foregroundColor(.theme.textSecondary)

                            if exercise.restSeconds > 0 {
                                Text("Rest \(exercise.restSeconds)s")
                                    .font(.caption(13))
                                    .foregroundColor(.theme.textMuted)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(exercise.muscleGroups.prefix(2), id: \.self) { group in
                            Text(group.displayName)
                                .font(.caption(11))
                                .foregroundColor(.theme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.theme.primary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().background(Color.theme.surfaceLight)

            if let rpe = exercise.rpe {
                HStack(spacing: 6) {
                    Text("RPE:")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                    Text("\(rpe)/10")
                        .font(.bodyMedium(13))
                        .foregroundColor(.theme.textSecondary)
                }
            }

            if let notes = exercise.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Form Cues")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                    Text(notes)
                        .font(.bodyText(13))
                        .foregroundColor(.theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let sub = exercise.substitution, !sub.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Substitution")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                    Text(sub)
                        .font(.bodyText(13))
                        .foregroundColor(.theme.secondary)
                }
            }

            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                Text("Full Details →")
                    .font(.caption(13))
                    .foregroundColor(.theme.primary)
            }
        }
    }
}

// MARK: - Editable Row
//
// Premium, full-width charcoal card. Sets adjust via stepper; reps edit
// inline via TextField; swap opens the existing ExerciseSwapSheet.
// Onlyused in edit mode — read state goes through ExerciseRow above.

private struct EditableExerciseRow: View {
    let exercise: Exercise
    let onSetsChange: (Int) -> Void
    let onRepsChange: (String) -> Void
    let onSwapTapped: () -> Void

    @State private var setsValue: Int
    @State private var repsValue: String
    @FocusState private var repsFocused: Bool

    init(
        exercise: Exercise,
        onSetsChange: @escaping (Int) -> Void,
        onRepsChange: @escaping (String) -> Void,
        onSwapTapped: @escaping () -> Void
    ) {
        self.exercise = exercise
        self.onSetsChange = onSetsChange
        self.onRepsChange = onRepsChange
        self.onSwapTapped = onSwapTapped
        _setsValue = State(initialValue: exercise.sets)
        _repsValue = State(initialValue: exercise.reps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.bodyMedium(15))
                        .foregroundColor(.theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(exercise.muscleGroups.prefix(2).map(\.displayName).joined(separator: " · "))
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                }
                Spacer()
                Button {
                    UnboundHaptics.soft()
                    onSwapTapped()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("Swap")
                            .font(.caption(12).weight(.semibold))
                    }
                    .foregroundColor(.theme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.theme.primary.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.theme.primary.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                setsControl
                repsControl
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.theme.primary.opacity(0.25), lineWidth: 1)
        )
        .onChange(of: setsValue) { _, newValue in
            onSetsChange(newValue)
        }
    }

    private var setsControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SETS")
                .font(.caption(10).weight(.bold))
                .tracking(1.2)
                .foregroundColor(.theme.textMuted)
            HStack(spacing: 8) {
                stepperButton(systemName: "minus") {
                    if setsValue > 1 {
                        UnboundHaptics.soft()
                        setsValue -= 1
                    }
                }
                Text("\(setsValue)")
                    .font(.bodyMedium(18))
                    .foregroundColor(.theme.textPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 24)
                stepperButton(systemName: "plus") {
                    if setsValue < 12 {
                        UnboundHaptics.soft()
                        setsValue += 1
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.theme.background.opacity(0.6))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var repsControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REPS")
                .font(.caption(10).weight(.bold))
                .tracking(1.2)
                .foregroundColor(.theme.textMuted)
            TextField("e.g. 8–12", text: $repsValue)
                .font(.bodyMedium(16))
                .foregroundColor(.theme.textPrimary)
                .focused($repsFocused)
                .submitLabel(.done)
                .onSubmit {
                    onRepsChange(repsValue)
                }
                .onChange(of: repsFocused) { _, focused in
                    if !focused { onRepsChange(repsValue) }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.theme.background.opacity(0.6))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.theme.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.theme.primary.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}
