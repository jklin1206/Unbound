import SwiftUI

struct SessionEditorView: View {
    enum Mode: Equatable {
        case startSession
        case planAhead
        case saveWorkout
        /// Same save-to-library behavior as `saveWorkout`, but the chrome says
        /// "edit" — used when the draft is an existing loadout being reworked.
        case editWorkout

        var headerTitle: String {
            switch self {
            case .startSession: return "EDIT WORKOUT"
            case .planAhead: return "PLAN WORKOUT"
            case .saveWorkout: return "CREATE WORKOUT"
            case .editWorkout: return "EDIT LOADOUT"
            }
        }

        var summaryEyebrow: String {
            switch self {
            case .startSession: return "WORKOUT"
            case .planAhead: return "PLAN"
            case .saveWorkout, .editWorkout: return "WORKOUT"
            }
        }

        var footerLabel: String {
            switch self {
            case .startSession: return "TODAY"
            case .planAhead: return "PLAN"
            case .saveWorkout, .editWorkout: return "LIBRARY"
            }
        }

        var primaryTitle: String {
            switch self {
            case .startSession: return "BEGIN SESSION"
            case .planAhead: return "DONE"
            case .saveWorkout: return "CREATE WORKOUT"
            case .editWorkout: return "SAVE CHANGES"
            }
        }

        var primaryIcon: String {
            switch self {
            case .startSession: return "play.fill"
            case .planAhead: return "checkmark"
            case .saveWorkout: return "square.and.arrow.down"
            case .editWorkout: return "checkmark"
            }
        }

        var emptyWorkoutWarningMessage: String {
            switch self {
            case .startSession:
                return "A session needs at least one exercise before it can start."
            case .planAhead:
                return "A planned workout needs at least one exercise before it can be saved."
            case .saveWorkout, .editWorkout:
                return "A saved workout needs at least one exercise."
            }
        }
    }

    @State var draft: TrainingSessionDraft
    @State var pickerRoute: PickerRoute?
    @State var customRoute: CustomRoute?
    @State var showEmptyWorkoutWarning = false
    @State var recentExerciseNames: Set<String> = []
    @State var preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    @State var availableEquipment: [Equipment]?

    // Grid cell editor — shared bottom-docked keypad module (mirrors the in-workout
    // logging grid; no system keyboard). The model owns the typed buffer + pristine
    // state, so merely opening a cell never overwrites the existing value.
    @StateObject var keypad = NumberPadEditorModel<CellEditTarget>()

    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) var dismiss
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    let originalDraft: TrainingSessionDraft
    let mode: Mode
    let onStart: (TrainingSessionDraft) -> Void

    init(draft: TrainingSessionDraft, mode: Mode = .startSession, onStart: @escaping (TrainingSessionDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.originalDraft = draft
        self.mode = mode
        self.onStart = onStart
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        builderHeader
                        blocksList
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 104)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // The keypad takes the bottom space while editing — hide the
                    // ADD EXERCISE / DONE bar so they don't stack.
                    if !keypad.isActive { bottomStartBar }
                }
            }
        }
        .sheet(item: $pickerRoute) { route in
            switch route {
            case .add(let blockId):
                ExerciseSwapSheet(
                    mode: .add,
                    currentExerciseName: "Session",
                    alternatives: allCatalogExercises,
                    onSelect: { exercise in
                        addExercise(exercise, toBlockId: blockId)
                        pickerRoute = nil
                    },
                    recentExerciseNames: recentExerciseNames,
                    preferenceStatusesByKey: preferenceStatusesByKey,
                    availableEquipment: availableEquipment,
                    onCreateCustom: {
                        openCustomBuilder(.add(blockId: blockId))
                    }
                )
            case .swap(let target):
                ExerciseSwapSheet(
                    currentExerciseName: prescription(at: target)?.exerciseName ?? "",
                    alternatives: alternatives(for: target),
                    onSelect: { replacement in
                        replacePrescription(at: target, with: replacement)
                        pickerRoute = nil
                    },
                    recentExerciseNames: recentExerciseNames,
                    preferenceStatusesByKey: preferenceStatusesByKey,
                    availableEquipment: availableEquipment,
                    onCreateCustom: {
                        openCustomBuilder(.swap(target))
                    }
                )
            }
        }
        .fullScreenCover(item: $customRoute) { route in
            CustomExerciseBuilderView { exercise in
                applyCustomExercise(exercise, route: route)
                customRoute = nil
            }
            .environmentObject(services)
        }
        .alert("Add at least one exercise", isPresented: $showEmptyWorkoutWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mode.emptyWorkoutWarningMessage)
        }
        .task {
            await loadPickerContext()
        }
        .numberPadDock(model: keypad)
    }

    var allCatalogExercises: [CatalogExercise] {
        MovementCatalog.legacyExercises.compactMap(MovementCatalog.catalogExercise(for:))
    }

    var exerciseCount: Int {
        draft.blocks.reduce(0) { $0 + $1.prescriptions.count }
    }

    func prescriptionBinding(for target: PrescriptionTarget) -> Binding<TrainingBlockPrescription> {
        Binding(
            get: {
                draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
            },
            set: { updated in
                guard draft.blocks.indices.contains(target.blockIndex),
                      draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
                else { return }
                draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex] = updated
            }
        )
    }

    func openAddExercise(blockId: String? = nil) {
        let targetBlockId = blockId ?? primaryEditableBlockId() ?? createDefaultBlock()
        pickerRoute = .add(blockId: targetBlockId)
    }

    func primaryEditableBlockId() -> String? {
        draft.blocks.first(where: { block in
            switch block.kind {
            case .strength, .bodyweight, .custom, .carry:
                return true
            case .skill, .cardio, .routine:
                return false
            }
        })?.id ?? draft.blocks.first?.id
    }

    func createDefaultBlock() -> String {
        let block = TrainingBlock(
            kind: .custom,
            title: "Workout",
            subtitle: "Custom",
            prescriptions: []
        )
        draft.blocks.append(block)
        refreshDraftEstimate()
        return block.id
    }

    func refreshDraftEstimate() {
        draft.normalizeReferenceExerciseName()
        draft.estimatedMinutes = Self.estimatedMinutes(for: draft.blocks)
    }

    static func estimatedMinutes(for blocks: [TrainingBlock]) -> Int {
        guard !blocks.isEmpty else { return 0 }
        return max(10, blocks.reduce(0) { total, block in
            let blockSeconds = block.prescriptions.reduce(0) { subtotal, prescription in
                let setSeconds = prescription.effectiveSetPlans.reduce(0) { setTotal, plan in
                    let workSeconds: Int
                    switch plan.target {
                    case .holdSeconds(let seconds), .timedSeconds(let seconds):
                        workSeconds = seconds
                    default:
                        workSeconds = 45
                    }
                    return setTotal + workSeconds + plan.restSeconds
                }
                return subtotal + setSeconds
            }
            return total + max(5, Int(ceil(Double(blockSeconds) / 60.0)))
        })
    }

    static func target(from text: String) -> TrainingTarget {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if lowered.isEmpty || lowered.contains("amrap") { return .amrap }
        if lowered.contains(":") {
            let parts = lowered.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                return .timedSeconds((parts[0] * 60) + parts[1])
            }
        }
        if lowered.contains("-") || lowered.contains("–") {
            let parts = lowered
                .replacingOccurrences(of: "–", with: "-")
                .split(separator: "-")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if parts.count >= 2 { return .repsRange(parts[0], parts[1]) }
        }
        if lowered.contains("cal"), let calories = RepRange.lowerBound(lowered) { return .calories(calories) }
        if lowered.contains("s"), let seconds = RepRange.lowerBound(lowered) { return .holdSeconds(seconds) }
        if lowered.contains("m"), let meters = RepRange.lowerBound(lowered) { return .distanceMeters(meters) }
        if let reps = RepRange.lowerBound(lowered) { return .reps(reps) }
        return .amrap
    }

    static func targetEditText(_ target: TrainingTarget) -> String {
        switch target {
        case .reps(let count):
            return "\(count)"
        case .repsRange(let low, _):
            return "\(low)"
        case .amrap:
            return "AMRAP"
        case .holdSeconds(let seconds):
            return "\(seconds)s"
        case .distanceMeters(let meters):
            return "\(meters)m"
        case .calories(let calories):
            return "\(calories) cal"
        case .timedSeconds(let seconds):
            let minutes = seconds / 60
            let remainder = seconds % 60
            return "\(minutes):" + String(format: "%02d", remainder)
        }
    }

    func loadPickerContext() async {
        recentExerciseNames = recentExerciseKeys(from: TrainingSessionDraftStore().loadRecent())

        guard let userId = services.auth.currentUserId else { return }

        if let profile = try? await services.user.fetchProfile(userId: userId),
           let equipment = profile.equipment,
           !equipment.isEmpty {
            availableEquipment = equipment
        }

        guard let preferences = try? await services.exercisePreference.fetchPreferences(userId: userId) else { return }

        var indexed: [String: ExercisePreferenceStatus] = [:]
        for preference in preferences {
            for key in ExercisePreferenceLookup.keys(for: preference) {
                indexed[key] = preference.status
            }
        }
        preferenceStatusesByKey = indexed
    }

    func recentExerciseKeys(from drafts: [TrainingSessionDraft]) -> Set<String> {
        var keys: Set<String> = []
        for draft in drafts.prefix(5) {
            for block in draft.blocks {
                for prescription in block.prescriptions {
                    addExerciseKeys(prescription.exerciseName, to: &keys)
                }
            }
        }
        return keys
    }

    func addExerciseKeys(_ exerciseName: String, to keys: inout Set<String>) {
        let normalized = ExercisePreferenceLookup.normalizedKey(exerciseName)
        if !normalized.isEmpty {
            keys.insert(normalized)
        }
        if let definition = MovementCatalog.canonicalExercise(named: exerciseName) {
            ExercisePreferenceLookup.keys(for: definition).forEach { keys.insert($0) }
        }
        if let catalogExercise = MovementCatalog.catalogExercise(named: exerciseName) {
            ExercisePreferenceLookup.keys(for: catalogExercise).forEach { keys.insert($0) }
        }
    }

    func prescription(at target: PrescriptionTarget) -> TrainingBlockPrescription? {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return nil }
        return draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
    }

    func alternatives(for target: PrescriptionTarget) -> [CatalogExercise] {
        guard let prescription = prescription(at: target) else { return [] }
        return MovementCatalog.catalogAlternatives(to: prescription.exerciseName)
    }

    func movementDefinition(for prescription: TrainingBlockPrescription) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
    }

    func replacePrescription(at target: PrescriptionTarget, with exercise: CatalogExercise) {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return }

        let current = draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
        draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex] = prescription(
            from: exercise,
            inheriting: current
        )
        refreshDraftEstimate()
    }

    func addExercise(_ exercise: CatalogExercise, toBlockId blockId: String) {
        guard let blockIndex = draft.blocks.firstIndex(where: { $0.id == blockId }) else { return }
        draft.blocks[blockIndex].prescriptions.append(prescription(from: exercise, inheriting: nil))
        refreshDraftEstimate()
    }

    func removePrescription(at target: PrescriptionTarget) {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return }
        draft.blocks[target.blockIndex].prescriptions.remove(at: target.prescriptionIndex)
        refreshDraftEstimate()
    }

    func movePrescription(at target: PrescriptionTarget, delta: Int) {
        guard draft.blocks.indices.contains(target.blockIndex) else { return }
        let nextIndex = target.prescriptionIndex + delta
        guard draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(nextIndex)
        else { return }
        draft.blocks[target.blockIndex].prescriptions.swapAt(target.prescriptionIndex, nextIndex)
    }

    func openCustomBuilder(_ route: CustomRoute) {
        pickerRoute = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            customRoute = route
        }
    }

    func applyCustomExercise(_ exercise: CustomExercise, route: CustomRoute) {
        switch route {
        case .add(let blockId):
            guard let blockIndex = draft.blocks.firstIndex(where: { $0.id == blockId }) else { return }
            draft.blocks[blockIndex].prescriptions.append(
                prescription(from: exercise, inheriting: nil)
            )
            refreshDraftEstimate()
        case .swap(let target):
            guard draft.blocks.indices.contains(target.blockIndex),
                  draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
            else { return }

            let current = draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
            draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex] = prescription(
                from: exercise,
                inheriting: current
            )
            refreshDraftEstimate()
        }
    }

    func prescription(
        from exercise: CatalogExercise,
        inheriting current: TrainingBlockPrescription?
    ) -> TrainingBlockPrescription {
        let definition = MovementCatalog.canonicalExercise(named: exercise.name)
        return TrainingBlockPrescription(
            exerciseName: exercise.displayName,
            movementId: definition?.id,
            rankStandardMovementId: definition?.rankStandardMovementId,
            sets: current?.sets ?? defaultSets(for: definition),
            target: current?.target ?? defaultTarget(for: definition),
            restSeconds: current?.restSeconds ?? defaultRest(for: definition),
            muscleGroups: definition?.muscleGroups ?? exercise.muscleGroups,
            rpe: current?.rpe ?? 8,
            notes: current == nil ? "Added in Session Editor." : "Swapped from \(current?.exerciseName ?? "previous exercise")."
        )
    }

    func prescription(
        from exercise: CustomExercise,
        inheriting current: TrainingBlockPrescription?
    ) -> TrainingBlockPrescription {
        TrainingBlockPrescription(
            exerciseName: exercise.displayName,
            movementId: nil,
            rankStandardMovementId: nil,
            sets: current?.sets ?? 3,
            target: current?.target ?? exercise.defaultTarget,
            restSeconds: current?.restSeconds ?? defaultRest(for: exercise.classification),
            muscleGroups: muscleGroups(for: exercise.pattern),
            rpe: current?.rpe ?? 8,
            notes: current == nil
                ? "Custom exercise added in Session Editor. Rank credit requires later movement mapping."
                : "Custom swap from \(current?.exerciseName ?? "previous exercise"). Rank credit requires later movement mapping."
        )
    }

    func defaultSets(for definition: MovementDefinition?) -> Int {
        switch definition?.defaultMetric {
        case .holdSeconds, .durationSeconds, .distanceMeters, .calories:
            return 3
        case .reps, .none:
            return 3
        }
    }

    func defaultTarget(for definition: MovementDefinition?) -> TrainingTarget {
        switch definition?.defaultMetric {
        case .holdSeconds:
            return .holdSeconds(30)
        case .durationSeconds:
            return .timedSeconds(300)
        case .distanceMeters:
            return .distanceMeters(400)
        case .calories:
            return .calories(30)
        case .reps, .none:
            return .repsRange(8, 12)
        }
    }

    func defaultRest(for definition: MovementDefinition?) -> Int {
        switch definition?.blockKind {
        case .cardio:
            return 90
        case .skill, .carry:
            return 120
        case .routine:
            return 30
        case .strength, .bodyweight, .custom, .none:
            return 90
        }
    }

    func defaultRest(for classification: ExerciseClassification) -> Int {
        switch classification {
        case .upperCompound, .lowerCompound:
            return 120
        case .accessory:
            return 75
        case .bodyweightSkill:
            return 90
        }
    }

    func muscleGroups(for pattern: MovementPattern) -> [MuscleGroup] {
        switch pattern {
        case .legsQuad, .legsPosterior, .calves:
            return [.legs, .glutes]
        case .pushHorizontal, .pushVertical, .arms:
            return [.chest, .shoulders, .arms]
        case .pullHorizontal, .pullVertical:
            return [.back, .arms]
        case .core:
            return [.core]
        }
    }

    func icon(for kind: TrainingBlockKind) -> String {
        switch kind {
        case .strength: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "sparkles"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "list.bullet.rectangle"
        case .custom: return "slider.horizontal.3"
        }
    }

}
