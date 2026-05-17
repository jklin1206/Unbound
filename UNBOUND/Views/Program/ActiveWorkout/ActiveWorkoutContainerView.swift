import SwiftUI

// MARK: - ActiveWorkoutContainerView
//
// Session orchestrator for the new set-by-set logging surface.
// Owns the ActiveWorkoutSession, autosaves drafts, routes between
// set entry and rest timer, and on COMPLETE assembles + saves the
// WorkoutLog via the unchanged saveLog path.

struct ActiveWorkoutContainerView: View {
    @StateObject private var session: ActiveWorkoutSession
    @State private var phase: Phase = .set
    @State private var elapsed = 0
    @State private var weight: Double = 0
    @State private var reps: Double = 0
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

    @Environment(\.dismiss) private var dismiss

    private let services: ServiceContainer
    private let draftStore: WorkoutDraftStore
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Phase { case set, rest }

    // MARK: - Identifiable wrappers (mirrors WorkoutLoggingView pattern)

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
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            switch phase {
            case .set:
                if let ex = session.currentExercise {
                    ActiveSetView(
                        exerciseName: ex.name,
                        setNumber: session.currentSetIndex + 1,
                        totalSets: ex.sets.count,
                        ghost: SetPrefill.ghost(
                            exerciseName: ex.name,
                            setIndex: session.currentSetIndex,
                            priorEntries: priorEntries,
                            workingWeightKg: workingWeightKg
                        ),
                        isWarmup: ex.sets.indices.contains(session.currentSetIndex)
                            ? ex.sets[session.currentSetIndex].isWarmup : false,
                        isFinalSet: session.isLastSetOfWorkout,
                        exerciseCount: session.exercises.count,
                        currentExerciseIndex: session.currentExerciseIndex,
                        completedExerciseIndices: completedIndices,
                        elapsedSeconds: elapsed,
                        weight: $weight,
                        reps: $reps,
                        onLogSet: logSet,
                        onPickEffort: { session.setEffort($0); afterLog() },
                        onJumpExercise: { session.jumpToExercise($0); syncInputs() },
                        onIntent: handle
                    )
                }

            case .rest:
                RestTimerView(
                    totalSeconds: session.currentExercise?.restSeconds ?? 90,
                    nextLabel: nextLabel,
                    onFinished: { withAnimation { phase = .set } },
                    onSkip: { withAnimation { phase = .set } }
                )
                .transition(.opacity)
            }
        }
        .onReceive(clock) { _ in
            elapsed = Int(Date().timeIntervalSince(session.startedAt))
        }
        .task {
            await loadContext()
            syncInputs()
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

    private var completedIndices: Set<Int> {
        Set(
            session.exercises.enumerated()
                .filter { $0.element.skipped || $0.element.sets.allSatisfy(\.logged) }
                .map(\.offset)
        )
    }

    private var nextLabel: String {
        guard let ex = session.currentExercise else { return "" }
        return "\(ex.name) · set \(session.currentSetIndex + 1)"
    }

    private var totalWorkingSets: Int {
        session.exercises.filter { !$0.skipped }.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count }
    }

    // MARK: - Core actions

    private func logSet() {
        session.logCurrentSet(
            weightKg: weight > 0 ? weight : nil,
            reps: Int(reps) > 0 ? Int(reps) : nil
        )
        try? draftStore.save(session)
    }

    private func afterLog() {
        let hasRemaining = session.exercises.contains {
            !$0.skipped && !$0.sets.allSatisfy(\.logged)
        }
        if session.isLastSetOfWorkout {
            if hasRemaining {
                showCompleteConfirm = true
            } else {
                Task { await complete() }
            }
        } else {
            session.advance()
            try? draftStore.save(session)
            syncInputs()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                phase = .rest
            }
        }
    }

    private func syncInputs() {
        let g = SetPrefill.ghost(
            exerciseName: session.currentExercise?.name ?? "",
            setIndex: session.currentSetIndex,
            priorEntries: priorEntries,
            workingWeightKg: workingWeightKg
        )
        weight = g?.weightKg ?? 0
        reps = Double(g?.reps ?? 0)
    }

    private func handle(_ intent: OverflowIntent) {
        switch intent {
        case .toggleWarmup:
            session.toggleCurrentWarmup()

        case .addSet:
            session.addSetToCurrentExercise()

        case .removeSet:
            session.removeLastSetFromCurrentExercise()

        case .skipExercise:
            session.skipCurrentExercise()
            syncInputs()

        case .editNotes:
            let idx = session.currentExerciseIndex
            notesEditingIndex = idx
            notesEditingText = session.exercises.indices.contains(idx)
                ? session.exercises[idx].notes : ""
            showNotesSheet = true
            return // draft save happens in the sheet's onSave closure

        case .swapExercise:
            let idx = session.currentExerciseIndex
            guard session.exercises.indices.contains(idx) else { return }
            swapAlternatives = ExerciseCatalog.alternatives(to: session.exercises[idx].name)
            swapExerciseIndex = idx
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
