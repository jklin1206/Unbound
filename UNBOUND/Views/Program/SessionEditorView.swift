import SwiftUI
import UniformTypeIdentifiers

struct SessionEditorView: View {
    @State private var draft: TrainingSessionDraft
    @State private var pickerRoute: PickerRoute?
    @State private var customRoute: CustomRoute?
    @State private var selectedPersistence: TrainingSessionEditPersistence = .todayOnly
    @State private var showEmptyWorkoutWarning = false
    @State private var recentExerciseNames: Set<String> = []
    @State private var preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    @State private var availableEquipment: [Equipment]?
    @State private var isPersistingEdits = false
    @State private var focusedTarget: PrescriptionTarget?
    @State private var draggingTarget: PrescriptionTarget?

    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    private let originalDraft: TrainingSessionDraft
    let onStart: (TrainingSessionDraft) -> Void

    init(draft: TrainingSessionDraft, onStart: @escaping (TrainingSessionDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.originalDraft = draft
        self.onStart = onStart
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryCard
                        compactPersistenceStrip
                        blocksList
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 104)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomStartBar
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
            Text("A session needs at least one exercise before it can start.")
        }
        .task {
            await loadPickerContext()
        }
    }

    private var header: some View {
        HStack {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Text("Close")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("SESSION EDITOR")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)

            Spacer()

            Button {
                UnboundHaptics.soft()
                draft = originalDraft
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset session edits")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S PLAN")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.coachCyan)
                    Text(draft.title)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(exerciseCount)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.bg)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(Color.unbound.coachCyan))
            }

            HStack(spacing: 8) {
                summaryPill("\(draft.blocks.count)", "BLOCKS")
                summaryPill("~\(draft.estimatedMinutes)M", "TIME")
                summaryPill(editCountLabel, "CHANGES")
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
                LinearGradient(
                    colors: [
                        Color.unbound.coachCyan.opacity(0.15),
                        Color.unbound.accent.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.24), lineWidth: 1)
        )
    }

    private func summaryPill(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.74))
        )
    }

    private var compactPersistenceStrip: some View {
        let summary = TrainingSessionEditSummary.compare(original: originalDraft, edited: draft)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: summary.isChanged ? "pencil.line" : "checkmark.seal")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(summary.isChanged ? Color.unbound.warnOrange : Color.unbound.success)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill((summary.isChanged ? Color.unbound.warnOrange : Color.unbound.success).opacity(0.13)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.headline.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(summary.details.isEmpty ? "Drag exercises to reorder. Tap one to swap. Use the menu to remove." : summary.details.joined(separator: " · "))
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TrainingSessionEditPersistence.allCases, id: \.self) { mode in
                        persistenceChip(mode)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func persistenceChip(_ mode: TrainingSessionEditPersistence) -> some View {
        let isSelected = selectedPersistence == mode
        return Button {
            UnboundHaptics.soft()
            if mode.isImplemented {
                selectedPersistence = mode
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode.isImplemented ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(mode.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(isSelected ? Color.unbound.accent.opacity(0.22) : Color.unbound.bg.opacity(0.72))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.unbound.accent.opacity(0.55) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
            .opacity(mode.isImplemented ? 1.0 : 0.48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.isImplemented ? mode.displayName : "\(mode.displayName) coming soon")
    }

    private var blocksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKOUT ORDER")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.7)
                .foregroundStyle(Color.unbound.textTertiary)

            ForEach(Array(draft.blocks.enumerated()), id: \.element.id) { blockIndex, block in
                blockCard(block: block, blockIndex: blockIndex)
            }
        }
    }

    private func blockCard(block: TrainingBlock, blockIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: block.kind))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.unbound.accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(block.kind.rawValue.uppercased())
                        .font(Font.unbound.captionS)
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer()
                Button {
                    focusedTarget = nil
                    pickerRoute = .add(blockId: block.id)
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(Font.unbound.captionS.weight(.bold))
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.unbound.bg.opacity(0.82)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add exercise to \(block.title)")
            }

            if block.prescriptions.isEmpty {
                emptyBlockRow(blockId: block.id)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(block.prescriptions.enumerated()), id: \.element.id) { prescriptionIndex, prescription in
                        prescriptionRow(
                            prescription,
                            blockIndex: blockIndex,
                            prescriptionIndex: prescriptionIndex
                        )
                        if prescriptionIndex < block.prescriptions.count - 1 {
                            Divider().overlay(Color.unbound.borderSubtle)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func emptyBlockRow(blockId: String) -> some View {
        Button {
            pickerRoute = .add(blockId: blockId)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.unbound.accent)
                Text("Add exercise")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func prescriptionRow(
        _ prescription: TrainingBlockPrescription,
        blockIndex: Int,
        prescriptionIndex: Int
    ) -> some View {
        let target = PrescriptionTarget(blockIndex: blockIndex, prescriptionIndex: prescriptionIndex)
        let isFocused = focusedTarget == target
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    UnboundHaptics.soft()
                    pickerRoute = .swap(target)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(width: 18)
                        Text("\(prescriptionIndex + 1)")
                            .font(Font.unbound.monoS.weight(.bold))
                            .foregroundStyle(isFocused ? Color.unbound.bg : Color.unbound.textTertiary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(isFocused ? Color.unbound.coachCyan : Color.unbound.bg.opacity(0.82)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(prescription.exerciseName)
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                            Text("\(prescription.sets) x \(prescription.target.displayText) · \(mmss(prescription.restSeconds)) rest")
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sessionEditor.exercise.\(blockIndex).\(prescriptionIndex).swap")
                .accessibilityLabel("Swap \(prescription.exerciseName)")

                Button {
                    UnboundHaptics.soft()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        focusedTarget = isFocused ? nil : target
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.unbound.bg.opacity(0.82)))
                        .rotationEffect(.degrees(90))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sessionEditor.exercise.\(blockIndex).\(prescriptionIndex).menu")
                .accessibilityLabel("More actions for \(prescription.exerciseName)")
            }

            if isFocused {
                HStack(spacing: 10) {
                    actionChip("Remove", "minus", tint: Color.unbound.alert) {
                        removePrescription(at: target)
                        focusedTarget = nil
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .opacity(draggingTarget == target ? 0.45 : 1.0)
        .onDrag {
            draggingTarget = target
            return NSItemProvider(object: target.id as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: PrescriptionDropDelegate(
                destination: target,
                draggingTarget: $draggingTarget,
                move: movePrescription(from:to:)
            )
        )
    }

    private func actionChip(_ title: String, _ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(Font.unbound.captionS.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Capsule().fill(tint.opacity(0.10)))
                .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var bottomStartBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(selectedPersistence.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(exerciseCount) exercises")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            startSessionButton(height: 52)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(Color.unbound.bg.opacity(0.94))
                .overlay(Rectangle().fill(Color.unbound.borderSubtle).frame(height: 1), alignment: .top)
        )
    }

    private func startSessionButton(height: CGFloat) -> some View {
        Button {
            guard exerciseCount > 0 else {
                showEmptyWorkoutWarning = true
                return
            }
            UnboundHaptics.heavy()
            Task {
                await persistSelectedEditsIfNeeded()
                onStart(draft)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPersistingEdits ? "arrow.triangle.2.circlepath" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(isPersistingEdits ? "SAVING EDITS" : "START EDITED SESSION")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.5)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.accent)
            )
            .shadow(color: Color.unbound.accent.opacity(0.35), radius: 14, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isPersistingEdits)
        .accessibilityLabel("Start edited session")
        .accessibilityIdentifier("sessionEditor.start")
    }

    private var allCatalogExercises: [CatalogExercise] {
        MovementCatalog.legacyExercises.compactMap(MovementCatalog.catalogExercise(for:))
    }

    private var exerciseCount: Int {
        draft.blocks.reduce(0) { $0 + $1.prescriptions.count }
    }

    private var editCountLabel: String {
        let count = TrainingSessionEditSummary.compare(original: originalDraft, edited: draft).editedExerciseCount
        return count == 0 ? "0" : "\(count)"
    }

    private func loadPickerContext() async {
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

    private func recentExerciseKeys(from drafts: [TrainingSessionDraft]) -> Set<String> {
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

    private func addExerciseKeys(_ exerciseName: String, to keys: inout Set<String>) {
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

    private func persistSelectedEditsIfNeeded() async {
        guard selectedPersistence != .todayOnly,
              selectedPersistence.isImplemented,
              let userId = services.auth.currentUserId
        else { return }

        let swaps = TrainingSessionEditPreferenceBuilder.swapEdits(original: originalDraft, edited: draft)
        guard !swaps.isEmpty else { return }

        isPersistingEdits = true
        defer { isPersistingEdits = false }

        let preferences = TrainingSessionEditPreferenceBuilder.preferences(
            for: swaps,
            mode: selectedPersistence,
            userId: userId
        )
        for preference in preferences {
            try? await services.exercisePreference.setPreference(preference)
        }

        await loadPickerContext()
    }

    private func prescription(at target: PrescriptionTarget) -> TrainingBlockPrescription? {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return nil }
        return draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
    }

    private func alternatives(for target: PrescriptionTarget) -> [CatalogExercise] {
        guard let prescription = prescription(at: target) else { return [] }
        return MovementCatalog.catalogAlternatives(to: prescription.exerciseName)
    }

    private func replacePrescription(at target: PrescriptionTarget, with exercise: CatalogExercise) {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return }

        let current = draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
        draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex] = prescription(
            from: exercise,
            inheriting: current
        )
    }

    private func addExercise(_ exercise: CatalogExercise, toBlockId blockId: String) {
        guard let blockIndex = draft.blocks.firstIndex(where: { $0.id == blockId }) else { return }
        draft.blocks[blockIndex].prescriptions.append(prescription(from: exercise, inheriting: nil))
    }

    private func removePrescription(at target: PrescriptionTarget) {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return }
        draft.blocks[target.blockIndex].prescriptions.remove(at: target.prescriptionIndex)
    }

    private func movePrescription(at target: PrescriptionTarget, delta: Int) {
        guard draft.blocks.indices.contains(target.blockIndex) else { return }
        let nextIndex = target.prescriptionIndex + delta
        guard draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(nextIndex)
        else { return }
        draft.blocks[target.blockIndex].prescriptions.swapAt(target.prescriptionIndex, nextIndex)
    }

    private func movePrescription(from source: PrescriptionTarget, to destination: PrescriptionTarget) {
        guard source != destination,
              draft.blocks.indices.contains(source.blockIndex),
              draft.blocks.indices.contains(destination.blockIndex),
              draft.blocks[source.blockIndex].prescriptions.indices.contains(source.prescriptionIndex)
        else { return }

        let moved = draft.blocks[source.blockIndex].prescriptions.remove(at: source.prescriptionIndex)
        var insertionIndex = destination.prescriptionIndex
        if source.blockIndex == destination.blockIndex,
           source.prescriptionIndex < destination.prescriptionIndex {
            insertionIndex -= 1
        }
        insertionIndex = max(0, min(insertionIndex, draft.blocks[destination.blockIndex].prescriptions.count))
        draft.blocks[destination.blockIndex].prescriptions.insert(moved, at: insertionIndex)
        draggingTarget = PrescriptionTarget(blockIndex: destination.blockIndex, prescriptionIndex: insertionIndex)
        focusedTarget = nil
    }

    private func openCustomBuilder(_ route: CustomRoute) {
        pickerRoute = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            customRoute = route
        }
    }

    private func applyCustomExercise(_ exercise: CustomExercise, route: CustomRoute) {
        switch route {
        case .add(let blockId):
            guard let blockIndex = draft.blocks.firstIndex(where: { $0.id == blockId }) else { return }
            draft.blocks[blockIndex].prescriptions.append(
                prescription(from: exercise, inheriting: nil)
            )
        case .swap(let target):
            guard draft.blocks.indices.contains(target.blockIndex),
                  draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
            else { return }

            let current = draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
            draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex] = prescription(
                from: exercise,
                inheriting: current
            )
        }
    }

    private func prescription(
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

    private func prescription(
        from exercise: CustomExercise,
        inheriting current: TrainingBlockPrescription?
    ) -> TrainingBlockPrescription {
        TrainingBlockPrescription(
            exerciseName: exercise.displayName,
            movementId: nil,
            rankStandardMovementId: nil,
            sets: current?.sets ?? 3,
            target: current?.target ?? .repsRange(exercise.defaultRepMin, exercise.defaultRepMax),
            restSeconds: current?.restSeconds ?? defaultRest(for: exercise.classification),
            muscleGroups: muscleGroups(for: exercise.pattern),
            rpe: current?.rpe ?? 8,
            notes: current == nil
                ? "Custom exercise added in Session Editor. Rank credit requires later movement mapping."
                : "Custom swap from \(current?.exerciseName ?? "previous exercise"). Rank credit requires later movement mapping."
        )
    }

    private func defaultSets(for definition: MovementDefinition?) -> Int {
        switch definition?.defaultMetric {
        case .holdSeconds, .durationSeconds, .distanceMeters, .calories:
            return 3
        case .reps, .none:
            return 3
        }
    }

    private func defaultTarget(for definition: MovementDefinition?) -> TrainingTarget {
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

    private func defaultRest(for definition: MovementDefinition?) -> Int {
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

    private func defaultRest(for classification: ExerciseClassification) -> Int {
        switch classification {
        case .upperCompound, .lowerCompound:
            return 120
        case .accessory:
            return 75
        case .bodyweightSkill:
            return 90
        }
    }

    private func muscleGroups(for pattern: MovementPattern) -> [MuscleGroup] {
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

    private func icon(for kind: TrainingBlockKind) -> String {
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

    private func mmss(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    private struct PrescriptionTarget: Identifiable, Hashable {
        let blockIndex: Int
        let prescriptionIndex: Int
        var id: String { "\(blockIndex)-\(prescriptionIndex)" }
    }

    private enum PickerRoute: Identifiable, Hashable {
        case add(blockId: String)
        case swap(PrescriptionTarget)

        var id: String {
            switch self {
            case .add(let blockId):
                return "add-\(blockId)"
            case .swap(let target):
                return "swap-\(target.id)"
            }
        }
    }

    private enum CustomRoute: Identifiable, Hashable {
        case add(blockId: String)
        case swap(PrescriptionTarget)

        var id: String {
            switch self {
            case .add(let blockId):
                return "custom-add-\(blockId)"
            case .swap(let target):
                return "custom-swap-\(target.id)"
            }
        }
    }

    private struct PrescriptionDropDelegate: DropDelegate {
        let destination: PrescriptionTarget
        @Binding var draggingTarget: PrescriptionTarget?
        let move: (PrescriptionTarget, PrescriptionTarget) -> Void

        func dropEntered(info: DropInfo) {
            guard let source = draggingTarget, source != destination else { return }
            UnboundHaptics.soft()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                move(source, destination)
            }
        }

        func performDrop(info: DropInfo) -> Bool {
            draggingTarget = nil
            return true
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func dropExited(info: DropInfo) {}
    }
}
