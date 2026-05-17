import SwiftUI

// MARK: - ActiveWorkoutContainerView
//
// Session orchestrator for the new grid-based logging surface.
// Owns the ActiveWorkoutSession, autosaves drafts, hosts WorkoutLogGridView
// + RestTimerPill overlay, and on COMPLETE assembles + saves the WorkoutLog
// via the unchanged saveLog path.

struct ActiveWorkoutContainerView: View {
    @StateObject private var session: ActiveWorkoutSession
    @State private var priorEntries: [ExerciseLogEntry] = []
    @State private var workingWeightKg: Double? = nil
    @State private var saving = false
    @State private var showCompleteConfirm = false

    // Swap sheet state
    @State private var swapExerciseIndex: Int? = nil
    @State private var swapAlternatives: [CatalogExercise] = []
    @State private var showingCustomBuilder = false

    // Notes editing state
    @State private var notesEditingIndex: Int? = nil
    @State private var notesEditingText: String = ""
    @State private var showNotesSheet = false

    // Reward state — mirrors WorkoutLoggingView's exact pattern
    @State private var rewardSummary: RewardSummary? = nil

    // Grid cell editor state
    @State private var editing: EditTarget? = nil

    // RPE picker state
    @State private var rpeTarget: RPETarget?
    private struct RPETarget: Identifiable { let id = UUID(); let ei: Int; let si: Int }

    // Rest timer
    @StateObject private var restTimer = RestTimerModel(notifier: RestNotifier.shared)
    private let restClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.dismiss) private var dismiss

    private let services: ServiceContainer
    private let draftStore: WorkoutDraftStore

    // MARK: - Private types

    struct EditTarget: Identifiable {
        let id = UUID()
        let ei: Int
        let si: Int
        let isWeight: Bool
    }

    private struct SwapContext: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private struct WorkoutRewardPresentation: Identifiable {
        let id = UUID()
        let summary: RewardSummary
    }

    // MARK: - Init

    init(
        workout: Workout,
        programId: String,
        dayNumber: Int,
        services: ServiceContainer,
        resuming: ActiveWorkoutSession? = nil
    ) {
        self.services = services
        self.draftStore = WorkoutDraftStore()
        _session = StateObject(
            wrappedValue: resuming
                ?? ActiveWorkoutSession(workout: workout, programId: programId, dayNumber: dayNumber)
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.unbound.bg.ignoresSafeArea()

            WorkoutLogGridView(
                session: session,
                onIntent: { ei, intent in handleIntent(ei, intent) },
                onEditWeight: { ei, si in editing = EditTarget(ei: ei, si: si, isWeight: true) },
                onEditReps:   { ei, si in editing = EditTarget(ei: ei, si: si, isWeight: false) },
                onPickRPE: { ei, si in rpeTarget = RPETarget(ei: ei, si: si) },
                onConfirmAsPlanned: { ei, si in
                    session.confirmAsPlanned(exerciseIndex: ei, setIndex: si)
                    try? draftStore.save(session)
                    transition(ei: ei)
                },
                onAddSet: { ei in
                    session.addSet(toExerciseIndex: ei)
                    try? draftStore.save(session)
                },
                onComplete: { showCompleteConfirm = true }
            )

            RestTimerPill(
                model: restTimer,
                onAddThirty: { restTimer.addThirty() },
                onDismiss: { restTimer.dismiss() }
            )
            .padding(.bottom, 16)
        }
        .onReceive(restClock) { _ in restTimer.tick() }
        .task {
            await loadContext()
        }
        .task {
            await RestNotifier.shared.requestAuthIfNeeded()
        }
        .interactiveDismissDisabled(true)
        // Complete confirmation dialog
        .confirmationDialog(
            "Finish with sets remaining?",
            isPresented: $showCompleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish workout", role: .destructive) { Task { await complete() } }
            Button("Keep training", role: .cancel) {}
        }
        // Grid cell editor sheet
        .sheet(item: $editing) { t in
            EditorSheet(
                session: session,
                ei: t.ei,
                si: t.si,
                isWeight: t.isWeight,
                onCommitted: {
                    let didLog = session.recomputeLogged(exerciseIndex: t.ei, setIndex: t.si)
                    try? draftStore.save(session)
                    if didLog { transition(ei: t.ei) }
                }
            )
        }
        // RPE picker sheet
        .sheet(item: $rpeTarget) { t in
            RPEPickerSheet(
                current: (session.exercises.indices.contains(t.ei)
                          && session.exercises[t.ei].sets.indices.contains(t.si))
                    ? (session.exercises[t.ei].sets[t.si].rpe
                       ?? session.exercises[t.ei].sets[t.si].suggestedRPE)
                    : nil,
                onPick: { v in
                    session.setRPE(exerciseIndex: t.ei, setIndex: t.si, v)
                    try? draftStore.save(session)
                }
            )
            .presentationDetents([.height(420)])
        }
        // Swap sheet — uses the existing ExerciseSwapSheet with real init
        .sheet(item: Binding(
            get: { swapExerciseIndex.map(SwapContext.init(index:)) },
            set: { swapExerciseIndex = $0?.index }
        )) { ctx in
            ExerciseSwapSheet(
                currentExerciseName: session.exercises[ctx.index].name,
                alternatives: swapAlternatives,
                onSelect: { alt in
                    // Mutate the exercise name in the session directly
                    if session.exercises.indices.contains(ctx.index) {
                        session.exercises[ctx.index].name = alt.displayName
                    }
                    swapExerciseIndex = nil
                    try? draftStore.save(session)
                },
                onCreateCustom: {
                    swapExerciseIndex = nil
                    showingCustomBuilder = true
                }
            )
        }
        // Custom exercise builder (same as WorkoutLoggingView)
        .sheet(isPresented: $showingCustomBuilder) {
            CustomExerciseBuilderView()
                .environmentObject(services)
        }
        // Notes editing sheet — simple inline text entry
        .sheet(isPresented: $showNotesSheet) {
            NotesEditSheet(
                text: $notesEditingText,
                onSave: {
                    if let idx = notesEditingIndex {
                        session.setNotes(notesEditingText, forExerciseAt: idx)
                        try? draftStore.save(session)
                    }
                    showNotesSheet = false
                },
                onCancel: {
                    showNotesSheet = false
                }
            )
        }
        // Reward sheet — reproduces WorkoutLoggingView's exact pattern:
        // RewardCelebrationView(summary:) with .presentationDetents([.medium,.large])
        .sheet(item: Binding(
            get: { rewardSummary.map(WorkoutRewardPresentation.init(summary:)) },
            set: { rewardSummary = $0?.summary }
        )) { item in
            RewardCelebrationView(summary: item.summary) {
                rewardSummary = nil
                dismiss()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Computed helpers

    private var totalWorkingSets: Int {
        session.exercises.filter { !$0.skipped }.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count }
    }

    // MARK: - Rest timer

    private func startRest(ei: Int) {
        guard session.exercises.indices.contains(ei) else { return }
        let secs = session.exercises[ei].restSeconds
        let next = session.exercises[ei].name
        restTimer.onElapsed = { UnboundHaptics.success() }
        restTimer.start(seconds: secs, nextLabel: next)
    }

    /// Fired exactly once per set on the SUGGESTED→LOGGED edge.
    private func transition(ei: Int) {
        UnboundHaptics.success()
        startRest(ei: ei)
    }

    /// After loadContext resolves history/working-weight, fill each set's
    /// dim suggested weight via the existing SetPrefill ghost.
    private func applySuggestedWeights() {
        for ei in session.exercises.indices {
            for si in session.exercises[ei].sets.indices
            where session.exercises[ei].sets[si].suggestedWeightKg == nil {
                if let g = SetPrefill.ghost(
                    exerciseName: session.exercises[ei].name,
                    setIndex: si,
                    priorEntries: priorEntries,
                    workingWeightKg: workingWeightKg) {
                    session.exercises[ei].sets[si].suggestedWeightKg = g.weightKg
                }
            }
        }
    }

    // MARK: - Ghost prefill

    private func ghost(ei: Int, si: Int) -> SetPrefill.Ghost? {
        guard session.exercises.indices.contains(ei) else { return nil }
        return SetPrefill.ghost(
            exerciseName: session.exercises[ei].name,
            setIndex: si,
            priorEntries: priorEntries,
            workingWeightKg: workingWeightKg
        )
    }

    // MARK: - Intent handler

    private func handleIntent(_ ei: Int, _ intent: OverflowIntent) {
        switch intent {
        case .toggleWarmup:
            if session.exercises.indices.contains(ei),
               let s0 = session.exercises[ei].sets.indices.first {
                session.exercises[ei].sets[s0].isWarmup.toggle()
            }

        case .addSet:
            session.addSet(toExerciseIndex: ei)

        case .removeSet:
            session.removeLastSet(fromExerciseIndex: ei)

        case .skipExercise:
            if session.exercises.indices.contains(ei) {
                session.exercises[ei].skipped = true
            }

        case .editNotes:
            notesEditingIndex = ei
            notesEditingText = session.exercises.indices.contains(ei)
                ? session.exercises[ei].notes : ""
            showNotesSheet = true
            return // draft save happens in the sheet's onSave closure

        case .swapExercise:
            guard session.exercises.indices.contains(ei) else { return }
            swapAlternatives = ExerciseCatalog.alternatives(to: session.exercises[ei].name)
            swapExerciseIndex = ei
            return // draft save happens in swap onSelect closure
        }
        try? draftStore.save(session)
    }

    // MARK: - Load context (wired to real APIs)

    private func loadContext() async {
        guard let uid = services.auth.currentUserId else { return }

        // Wire point 1: fetchRecentLogs(userId:limit:) exists on WorkoutLogServiceProtocol.
        // Flatten exerciseEntries from the 10 most-recent logs so SetPrefill can
        // find last-session values per exercise (most-recent last = .last(where:) picks latest).
        if let recentLogs = try? await services.workoutLog.fetchRecentLogs(userId: uid, limit: 10) {
            priorEntries = recentLogs
                .sorted { $0.startedAt < $1.startedAt } // oldest first → SetPrefill.last picks newest
                .flatMap { $0.exerciseEntries }
        }

        // Wire point 2: fetchWeight(userId:exerciseName:) returns WorkingWeight? with .weightKg:Double.
        // Use the normalized name (lowercased, spaces→"_") exactly like WorkoutLoggingViewModel.
        if let ex = session.currentExercise {
            let normalized = ex.name.lowercased().replacingOccurrences(of: " ", with: "_")
            if let ww = try? await services.workingWeight.fetchWeight(userId: uid, exerciseName: normalized) {
                workingWeightKg = ww.weightKg
            }
        }
        applySuggestedWeights()
    }

    // MARK: - Save + reward

    private func complete() async {
        guard let uid = services.auth.currentUserId, !saving else { return }
        saving = true
        let log = session.assembleWorkoutLog(userId: uid)
        do {
            try await services.workoutLog.saveLog(log)
            HapticManager.notification(.success)
            draftStore.clear()

            // Wire point 3: reproduce WorkoutLoggingView's exact post-save reward trigger.
            // WorkoutLoggingView: var summary = RewardSummary(); summary.skillTitle = workout.name;
            // summary.xpGained = max(10, totalSets * 5); rewardSummary = summary
            // If summary.hasContent → sheet; else → dismiss() immediately.
            var summary = RewardSummary()
            summary.skillTitle = session.plannedWorkoutName
            summary.xpGained = max(10, totalWorkingSets * 5)
            rewardSummary = summary
            if !summary.hasContent {
                dismiss()
            }
            // If summary.hasContent, the reward sheet will call dismiss() in its completion closure.
        } catch {
            HapticManager.notification(.error)
            saving = false
        }
    }
}

// MARK: - EditorSheet

/// Inline stepper sheet for editing a single weight or reps cell.
/// Writes back to session on Done; keeps `logged` state unchanged.
private struct EditorSheet: View {
    @ObservedObject var session: ActiveWorkoutSession
    let ei: Int
    let si: Int
    let isWeight: Bool
    let onCommitted: () -> Void

    @State private var value: Double
    @Environment(\.dismiss) private var dismiss

    init(session: ActiveWorkoutSession,
         ei: Int,
         si: Int,
         isWeight: Bool,
         onCommitted: @escaping () -> Void) {
        self.session = session
        self.ei = ei
        self.si = si
        self.isWeight = isWeight
        self.onCommitted = onCommitted

        let initial: Double
        if isWeight {
            initial = session.exercises.indices.contains(ei)
                && session.exercises[ei].sets.indices.contains(si)
                ? (session.exercises[ei].sets[si].weightKg
                   ?? session.exercises[ei].sets[si].suggestedWeightKg ?? 0)
                : 0
        } else {
            initial = session.exercises.indices.contains(ei)
                && session.exercises[ei].sets.indices.contains(si)
                ? Double(session.exercises[ei].sets[si].reps
                         ?? session.exercises[ei].sets[si].suggestedReps ?? 0)
                : 0
        }
        _value = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()
                    StepperControl(
                        label: isWeight ? "Weight" : "Reps",
                        value: $value,
                        step: isWeight ? 2.5 : 1,
                        unit: isWeight ? "kg" : nil,
                        allowsDecimal: isWeight
                    )
                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commit() }
                        .foregroundStyle(Color.unbound.accent)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    private func commit() {
        guard session.exercises.indices.contains(ei),
              session.exercises[ei].sets.indices.contains(si) else {
            dismiss()
            return
        }
        if isWeight {
            session.exercises[ei].sets[si].weightKg = value > 0 ? value : nil
        } else {
            session.exercises[ei].sets[si].reps = Int(value) > 0 ? Int(value) : nil
        }
        // Keep .logged unchanged — do not clear it.
        onCommitted()
        dismiss()
    }
}

// MARK: - NotesEditSheet

/// Lightweight inline notes editor — simple text entry that writes back via
/// session.setNotes(_:forExerciseAt:). No heavy dependencies.
private struct NotesEditSheet: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("EXERCISE NOTES")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)

                    TextField("How did this feel? Cues, tips…", text: $text, axis: .vertical)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .tint(Color.unbound.accent)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                        .lineLimit(4...10)

                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .foregroundStyle(Color.unbound.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }
}
