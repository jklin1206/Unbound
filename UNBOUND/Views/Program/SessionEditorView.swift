import SwiftUI
import UniformTypeIdentifiers

struct SessionEditorView: View {
    enum Mode: Equatable {
        case startSession
        case planAhead

        var headerTitle: String {
            switch self {
            case .startSession: return "EDIT WORKOUT"
            case .planAhead: return "PLAN WORKOUT"
            }
        }

        var summaryEyebrow: String {
            switch self {
            case .startSession: return "WORKOUT"
            case .planAhead: return "PLAN"
            }
        }

        var footerLabel: String {
            switch self {
            case .startSession: return "TODAY ONLY"
            case .planAhead: return "SAVED WORKOUT"
            }
        }

        var primaryTitle: String {
            switch self {
            case .startSession: return "START"
            case .planAhead: return "SCHEDULE"
            }
        }

        var primaryIcon: String {
            switch self {
            case .startSession: return "play.fill"
            case .planAhead: return "calendar.badge.plus"
            }
        }

        var allowsTitleEditing: Bool { self == .planAhead }
        var showsPersistenceStrip: Bool { self == .startSession }
        var showsSaveWorkoutAction: Bool { self == .startSession }
    }

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
    @State private var showSaveWorkoutSheet = false
    @State private var showSkillBlockPicker = false
    @State private var savedWorkoutConfirmation: SavedWorkoutConfirmation?
    @State private var skillBlockConfirmation: SkillBlockConfirmation?

    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    private let originalDraft: TrainingSessionDraft
    private let mode: Mode
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
                        summaryCard
                        editorActionBar
                        if mode.showsPersistenceStrip {
                            compactPersistenceStrip
                        }
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
        .sheet(isPresented: $showSaveWorkoutSheet) {
            SaveWorkoutSheet(
                draft: draft,
                existingWorkouts: SavedWorkoutStore.shared.all()
            ) { savedWorkout in
                SavedWorkoutStore.shared.save(savedWorkout)
                savedWorkoutConfirmation = SavedWorkoutConfirmation(title: savedWorkout.title)
            }
        }
        .sheet(isPresented: $showSkillBlockPicker) {
            SkillBlockPickerSheet(
                programFocusIDs: Array(SkillProgressService.shared.programFocusIds),
                onPick: { node, kind in
                    draft = SkillBlockRouter.insert(
                        skillID: node.id,
                        title: node.title,
                        kind: kind,
                        into: draft
                    )
                    skillBlockConfirmation = SkillBlockConfirmation(title: node.title, kind: kind)
                    showSkillBlockPicker = false
                },
                onDismiss: {
                    showSkillBlockPicker = false
                }
            )
        }
        .alert("Add at least one exercise", isPresented: $showEmptyWorkoutWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A session needs at least one exercise before it can start.")
        }
        .alert(item: $savedWorkoutConfirmation) { confirmation in
            Alert(
                title: Text("Saved Workout"),
                message: Text("\(confirmation.title) is ready to reuse from this phone."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(item: $skillBlockConfirmation) { confirmation in
            Alert(
                title: Text("Skill Block Added"),
                message: Text("\(confirmation.title) was inserted as a \(confirmation.kind.displayName.lowercased()) block."),
                dismissButton: .default(Text("OK"))
            )
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

            Text(mode.headerTitle)
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
        let prescriptions = flattenedPrescriptions
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                sessionPrimaryVisual(prescriptions.first, size: 108)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(mode.summaryEyebrow)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.coachCyan)
                        Spacer(minLength: 0)
                        Text("\(exerciseCount)")
                            .font(Font.unbound.monoS.weight(.bold))
                            .foregroundStyle(Color.unbound.bg)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(Capsule().fill(Color.unbound.coachCyan))
                    }

                    if mode.allowsTitleEditing {
                        TextField("Workout name", text: $draft.title)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.unbound.bg.opacity(0.74))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                            )
                            .accessibilityIdentifier("sessionEditor.workoutName")
                    } else {
                        Text(draft.title)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Text(primaryExerciseLabel(from: prescriptions))
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                summaryPill("\(draft.blocks.count)", "BLOCKS")
                summaryPill("~\(draft.estimatedMinutes)M", "TIME")
                summaryPill(editCountLabel, "CHANGES")
            }

            if !prescriptions.isEmpty {
                sessionVisualRail(prescriptions)
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

    @ViewBuilder
    private func sessionPrimaryVisual(_ prescription: TrainingBlockPrescription?, size: CGFloat) -> some View {
        if let prescription {
            prescriptionVisual(prescription, size: size)
        } else {
            fallbackExerciseVisual(systemName: "plus", size: size, tint: Color.unbound.coachCyan)
        }
    }

    private func primaryExerciseLabel(from prescriptions: [TrainingBlockPrescription]) -> String {
        guard let first = prescriptions.first else {
            return "Add exercise"
        }
        return "\(first.exerciseName) · \(first.sets) x \(first.displayTargetText)"
    }

    private func sessionVisualRail(_ prescriptions: [TrainingBlockPrescription]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(prescriptions.prefix(6).enumerated()), id: \.element.id) { index, prescription in
                    sessionVisualToken(prescription, index: index)
                }

                if prescriptions.count > 6 {
                    Text("+\(prescriptions.count - 6)")
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.bg.opacity(0.74))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
            }
        }
    }

    private func sessionVisualToken(_ prescription: TrainingBlockPrescription, index: Int) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topLeading) {
                prescriptionVisual(prescription, size: 52)
                Text("\(index + 1)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.bg)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.unbound.coachCyan))
                    .offset(x: -3, y: -3)
            }

            Text(prescription.exerciseName)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 62)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1). \(prescription.exerciseName)")
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

    private var editorActionBar: some View {
        HStack(spacing: 10) {
            if mode.showsSaveWorkoutAction {
                editorActionButton("Save", systemName: "square.and.arrow.down", tint: Color.unbound.coachCyan) {
                    guard exerciseCount > 0 else {
                        showEmptyWorkoutWarning = true
                        return
                    }
                    UnboundHaptics.soft()
                    showSaveWorkoutSheet = true
                }
                .accessibilityIdentifier("sessionEditor.saveWorkout")
            }

            editorActionButton("Skill", systemName: "sparkles", tint: Color.unbound.accent) {
                UnboundHaptics.soft()
                showSkillBlockPicker = true
            }
            .accessibilityIdentifier("sessionEditor.addSkillBlock")
        }
    }

    private func editorActionButton(
        _ title: String,
        systemName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(Font.unbound.bodyS.weight(.heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
                blockVisualStrip(block)

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

    private func blockVisualStrip(_ block: TrainingBlock) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(block.prescriptions.prefix(4).enumerated()), id: \.element.id) { index, prescription in
                ZStack(alignment: .bottomTrailing) {
                    prescriptionVisual(prescription, size: 48)
                    Text("\(index + 1)")
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.unbound.bg.opacity(0.88)))
                        .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                        .offset(x: 3, y: 3)
                }
            }

            if block.prescriptions.count > 4 {
                Text("+\(block.prescriptions.count - 4)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.unbound.bg.opacity(0.74))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }

            Spacer(minLength: 0)

            Text("\(block.prescriptions.count) moves")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.prescriptions.count) exercises")
    }

    private func prescriptionMetaPill(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Font.unbound.captionS.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(Color.unbound.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(Capsule().fill(Color.unbound.bg.opacity(0.76)))
            .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    @ViewBuilder
    private func prescriptionVisual(_ prescription: TrainingBlockPrescription, size: CGFloat) -> some View {
        if let definition = movementDefinition(for: prescription) {
            ExerciseVisualView(definition: definition, size: size >= 96 ? .hero : .thumbnail)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            fallbackExerciseVisual(systemName: "dumbbell.fill", size: size, tint: Color.unbound.accent)
        }
    }

    private func fallbackExerciseVisual(systemName: String, size: CGFloat, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size >= 96 ? 18 : 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
            Image(systemName: systemName)
                .font(.system(size: size >= 96 ? 32 : 18, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size >= 96 ? 18 : 10, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
        .accessibilityHidden(true)
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
                        ZStack(alignment: .topLeading) {
                            prescriptionVisual(prescription, size: 58)
                            Text("\(prescriptionIndex + 1)")
                                .font(Font.unbound.monoS.weight(.bold))
                                .foregroundStyle(isFocused ? Color.unbound.bg : Color.unbound.textPrimary)
                                .frame(width: 21, height: 21)
                                .background(
                                    Circle().fill(isFocused ? Color.unbound.coachCyan : Color.unbound.bg.opacity(0.88))
                                )
                                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: isFocused ? 0 : 1))
                                .offset(x: -3, y: -3)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(prescription.exerciseName)
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                            HStack(spacing: 6) {
                                prescriptionMetaPill("\(prescription.sets) sets")
                                prescriptionMetaPill(prescription.displayTargetText)
                                prescriptionMetaPill("\(mmss(prescription.restSeconds)) rest")
                            }
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
                Text(mode.showsPersistenceStrip ? selectedPersistence.displayName.uppercased() : mode.footerLabel)
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
                if mode.showsPersistenceStrip {
                    await persistSelectedEditsIfNeeded()
                }
                onStart(draft)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPersistingEdits ? "arrow.triangle.2.circlepath" : mode.primaryIcon)
                    .font(.system(size: 13, weight: .bold))
                Text(isPersistingEdits ? "SAVING EDITS" : mode.primaryTitle)
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
        .accessibilityLabel(mode.primaryTitle.capitalized)
        .accessibilityIdentifier("sessionEditor.start")
    }

    private var allCatalogExercises: [CatalogExercise] {
        MovementCatalog.legacyExercises.compactMap(MovementCatalog.catalogExercise(for:))
    }

    private var flattenedPrescriptions: [TrainingBlockPrescription] {
        draft.blocks.flatMap(\.prescriptions)
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

    private func movementDefinition(for prescription: TrainingBlockPrescription) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
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

    private struct SavedWorkoutConfirmation: Identifiable {
        let id = UUID()
        let title: String
    }

    private struct SkillBlockConfirmation: Identifiable {
        let id = UUID()
        let title: String
        let kind: SkillBlockKind
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
