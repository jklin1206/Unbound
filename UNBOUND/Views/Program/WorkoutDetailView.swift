import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var services: ServiceContainer
    var programId: String = ""
    var dayNumber: Int = 0
    /// Optional viewmodel binding — when present, edit mode is enabled and
    /// mutations route through it so they persist back to the program doc.
    var programViewModel: ProgramViewModel? = nil

    @State private var activeWorkoutDraft: TrainingSessionDraft?
    @State private var isEditing = false
    @State private var swapTargetExerciseId: String?
    @State private var swapAlternatives: [CatalogExercise] = []
    @State private var swapPreferences: [ExercisePreference] = []
    @State private var swapTrainingStyle: TrainingStyle = .default
    @State private var swapEquipment: [Equipment] = [.bodyweight]

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
            Color.unbound.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    workoutHeader

                    if !workout.warmup.isEmpty {
                        exerciseSection(
                            title: "WARMUP",
                            exercises: workout.warmup,
                            editable: false,
                            showsTrainingDetails: false
                        )
                    }

                    exerciseSection(
                        title: "MAIN WORKOUT",
                        exercises: liveMainExercises,
                        editable: canEdit
                    )

                    if !workout.cooldown.isEmpty {
                        exerciseSection(
                            title: "COOLDOWN",
                            exercises: workout.cooldown,
                            editable: false,
                            showsTrainingDetails: false
                        )
                    }

                    if !isEditing {
                        logWorkoutButton
                            .padding(.top, 4)
                    }
                }
                .padding(20)
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
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(isEditing ? Color.unbound.accent : Color.unbound.textSecondary)
                    }
                }
            }
        }
        .fullScreenCover(item: $activeWorkoutDraft) { draft in
            ActiveWorkoutContainerView(draft: draft, services: services, onFinished: {
                UserDefaults.standard.set(0, forKey: "unbound.shortSessionDate")
                activeWorkoutDraft = nil
            })
            .environmentObject(services)
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
                },
                availableEquipment: swapEquipment
            )
        }
        .task {
            if canEdit, let userId = services.auth.currentUserId {
                swapPreferences = (try? await services.exercisePreference.fetchPreferences(userId: userId)) ?? []
                if let profile = try? await services.user.fetchProfile(userId: userId) {
                    let equipment: [Equipment]
                    if let profileEquipment = profile.equipment, !profileEquipment.isEmpty {
                        equipment = profileEquipment
                    } else {
                        equipment = programEquipmentFallback
                    }
                    swapEquipment = equipment
                    swapTrainingStyle = profile.trainingStyleOverride ?? inferredTrainingStyle(for: equipment)
                } else {
                    swapEquipment = programEquipmentFallback
                    swapTrainingStyle = inferredTrainingStyle(for: swapEquipment)
                }
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

    private var readyDraft: TrainingSessionDraft? {
        guard let userId = services.auth.currentUserId else { return nil }
        if let day = programViewModel?.program?.days.first(where: { $0.dayNumber == dayNumber }),
           let draft = DailyWorkoutResolver.programDraft(
                from: day,
                userId: userId,
                programId: programId.isEmpty ? nil : programId
           ) {
            return draft
        }
        return DailyWorkoutResolver.programDraft(
            from: liveWorkout,
            userId: userId,
            programId: programId.isEmpty ? nil : programId,
            dayNumber: dayNumber
        )
    }

    private struct SwapTarget: Identifiable {
        let id: String
    }

    private func presentSwap(for exerciseId: String) {
        let current = liveMainExercises.first(where: { $0.id == exerciseId })?.name ?? ""
        let prefsByKey = ExercisePreferenceLookup.index(swapPreferences)
        let excludedNames = Set(swapPreferences.filter { $0.status == .avoid }.flatMap { [$0.exerciseName, $0.displayName] })
        let alts = MovementCatalog.catalogAlternatives(
            to: current,
            style: swapTrainingStyle,
            userEquipment: swapEquipment,
            excludedNames: excludedNames
        )
        .filter { preferenceStatus(for: $0, prefsByKey: prefsByKey) != .avoid }
        .sorted { a, b in
            let aAvail = preferenceStatus(for: a, prefsByKey: prefsByKey) == .available
            let bAvail = preferenceStatus(for: b, prefsByKey: prefsByKey) == .available
            if aAvail != bAvail { return aAvail && !bAvail }
            return a.displayName < b.displayName
        }
        swapAlternatives = alts
        swapTargetExerciseId = exerciseId
        UnboundHaptics.medium()
    }

    private var programEquipmentFallback: [Equipment] {
        guard let requiredEquipment = programViewModel?.program?.requiredEquipment else {
            return [.bodyweight]
        }

        let equipment = requiredEquipment.compactMap { value in
            Equipment(rawValue: value)
                ?? Equipment.allCases.first { $0.displayName.caseInsensitiveCompare(value) == .orderedSame }
        }
        return equipment.isEmpty ? [.bodyweight] : equipment
    }

    private func inferredTrainingStyle(for equipment: [Equipment]) -> TrainingStyle {
        let bodyweightGear: Set<Equipment> = [.bodyweight, .pullupBar, .bands, .dipStation, .rings]
        if !equipment.isEmpty && Set(equipment).isSubset(of: bodyweightGear) {
            return .bodyweight
        }
        if equipment.contains(.machines), !equipment.contains(.fullGym) {
            return .machines
        }
        if equipment.contains(.barbell) || equipment.contains(.dumbbells) || equipment.contains(.homeWeights) {
            return equipment.contains(.machines) ? .hybrid : .freeWeights
        }
        return .hybrid
    }

    private func preferenceStatus(
        for exercise: CatalogExercise,
        prefsByKey: [String: ExercisePreference]
    ) -> ExercisePreferenceStatus? {
        ExercisePreferenceLookup.keys(for: exercise).compactMap { prefsByKey[$0]?.status }.first
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

    private var logWorkoutButton: some View {
        Button {
            activeWorkoutDraft = readyDraft
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("LOG WORKOUT")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.6)
            }
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

    // MARK: - Header

    private var workoutHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            statCell(value: "\(liveMainExercises.count)", label: "EXERCISES")
            statCell(value: "\(workout.estimatedMinutes)", label: "MINUTES")
            statCell(
                value: workout.targetMuscleGroups.prefix(2).map(\.displayName).joined(separator: "/"),
                label: "FOCUS"
            )
            Spacer(minLength: 0)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Font.unbound.monoL)
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Font.unbound.captionS.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private func exerciseSection(
        title: String,
        exercises: [Exercise],
        editable: Bool,
        showsTrainingDetails: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CalmSectionHeader(title: title)

            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
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
                        .padding(.vertical, 6)
                    } else {
                        ExerciseRow(exercise: exercise, showsTrainingDetails: showsTrainingDetails)
                        if index < exercises.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                                .overlay(Color.unbound.border.opacity(0.6))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Read-only Row

private struct ExerciseRow: View {
    let exercise: Exercise
    let showsTrainingDetails: Bool
    @State private var isExpanded = false

    private var visualDefinition: MovementDefinition? {
        let resolved = MovementResolver.resolve(exercise.name)
        return MovementCatalog.definition(for: resolved.movementId)
    }

    private var movementDefinition: MovementDefinition? {
        guard let visualDefinition, visualDefinition.role == .canonicalExercise else {
            return MovementCatalog.canonicalExercise(named: exercise.name)
        }
        return visualDefinition
    }

    private var displayName: String {
        exercise.name
    }

    private var equipmentLabel: String? {
        guard showsTrainingDetails, let visualDefinition else { return nil }
        let labels = ExerciseLibrary.equipmentLabels(for: visualDefinition)
        return labels.first(where: { $0 != "Bodyweight" }) ?? labels.first
    }

    private var targetText: String {
        if showsTrainingDetails {
            return "\(exercise.sets) × \(exercise.reps)"
        }
        if exercise.reps.localizedCaseInsensitiveContains("s") || exercise.reps.contains("/") {
            return exercise.reps
        }
        return "\(exercise.reps) reps"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    WorkoutExerciseVisualTile(definition: visualDefinition)
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        MetaLine([
                            showsTrainingDetails && exercise.restSeconds > 0 ? "rest \(exercise.restSeconds)s" : nil,
                            equipmentLabel
                        ])
                    }

                    Spacer(minLength: 8)

                    Text(targetText)
                        .font(Font.unbound.monoM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .padding(.leading, 64)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsTrainingDetails, let movementDefinition {
                movementMetadata(movementDefinition)
            }

            if showsTrainingDetails, let rpe = exercise.rpe {
                HStack(spacing: 6) {
                    Text("RPE")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("\(rpe)/10")
                        .font(Font.unbound.monoS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }

            if let notes = exercise.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Form Cues")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(notes)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let sub = exercise.substitution, !sub.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Substitution")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(sub)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.coachCyan)
                }
            }

            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                Text("Full Details →")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
        }
    }

    private func movementMetadata(_ definition: MovementDefinition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Movement")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
            Text([
                definition.movementSlot.displayName,
                definition.rankTemplate.displayName,
                definition.loggerMode.displayName,
                ExerciseLibrary.equipmentLabels(for: definition).joined(separator: " · ")
            ].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WorkoutExerciseVisualTile: View {
    let definition: MovementDefinition?

    var body: some View {
        if let definition {
            ExerciseVisualView(definition: definition, size: .thumbnail)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
    }
}

// MARK: - Editable Row
//
// Edit mode lifts each editable unit onto the elevated surface — the one
// emphasis treatment in the calm language. Sets adjust via stepper; reps
// edit inline via TextField; swap opens the existing ExerciseSwapSheet.

private struct EditableExerciseRow: View {
    let exercise: Exercise
    let onSetsChange: (Int) -> Void
    let onRepsChange: (String) -> Void
    let onSwapTapped: () -> Void

    @State private var setsValue: Int
    @State private var repsValue: String
    @FocusState private var repsFocused: Bool

    private var visualDefinition: MovementDefinition? {
        let resolved = MovementResolver.resolve(exercise.name)
        return MovementCatalog.definition(for: resolved.movementId)
    }

    private var movementDefinition: MovementDefinition? {
        guard let visualDefinition, visualDefinition.role == .canonicalExercise else {
            return MovementCatalog.canonicalExercise(named: exercise.name)
        }
        return visualDefinition
    }

    private var displayName: String {
        exercise.name
    }

    private var displayMuscleGroups: [MuscleGroup] {
        let groups = visualDefinition?.muscleGroups ?? movementDefinition?.muscleGroups ?? []
        return groups.isEmpty ? exercise.muscleGroups : groups
    }

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
                WorkoutExerciseVisualTile(definition: visualDefinition)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    MetaLine(displayMuscleGroups.prefix(2).map(\.displayName))
                }
                Spacer()
                Button {
                    UnboundHaptics.soft()
                    onSwapTapped()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("SWAP")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(0.8)
                    }
                    .foregroundStyle(Color.unbound.accent)
                    .frame(height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap \(displayName)")
            }

            HStack(spacing: 10) {
                setsControl
                repsControl
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
        .onChange(of: setsValue) { _, newValue in
            onSetsChange(newValue)
        }
    }

    private var setsControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SETS")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            HStack(spacing: 8) {
                stepperButton(systemName: "minus") {
                    if setsValue > 1 {
                        UnboundHaptics.soft()
                        setsValue -= 1
                    }
                }
                Text("\(setsValue)")
                    .font(Font.unbound.monoM.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
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
                    .fill(Color.unbound.bg.opacity(0.6))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var repsControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REPS")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            TextField("e.g. 8–12", text: $repsValue)
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
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
                        .fill(Color.unbound.bg.opacity(0.6))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.surface))
        }
        .buttonStyle(.plain)
    }
}
