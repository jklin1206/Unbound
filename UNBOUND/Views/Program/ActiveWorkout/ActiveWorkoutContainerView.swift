import SwiftUI

// MARK: - ActiveWorkoutContainerView
//
// Session orchestrator for the new grid-based logging surface.
// Owns the ActiveWorkoutSession, autosaves drafts, hosts WorkoutLogGridView
// + RestTimerPill overlay, and on COMPLETE assembles + saves unified
// PerformanceLog data before showing the post-workout reward sequence.

struct ActiveWorkoutContainerView: View {
    @StateObject private var session: ActiveWorkoutSession
    @State private var priorEntries: [ExerciseLogEntry] = []
    @State private var workingWeightKg: Double? = nil
    @State private var saving = false
    @State private var showCompleteConfirm = false
    @State private var saveError = false
    @State private var showExitConfirm = false

    // Swap sheet state
    @State private var swapExerciseIndex: Int? = nil
    @State private var swapAlternatives: [CatalogExercise] = []
    @State private var showingCustomBuilder = false

    // Notes editing state
    @State private var notesEditingIndex: Int? = nil
    @State private var notesEditingText: String = ""
    @State private var showNotesSheet = false

    // Reward state
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State private var isFinishingRewardSequence = false

    // Grid cell editor state
    @State private var editing: EditTarget? = nil

    // RPE picker state
    @State private var rpeTarget: RPETarget?
    private struct RPETarget: Identifiable { let id = UUID(); let ei: Int; let si: Int }

    // Rest timer
    @StateObject private var restTimer = RestTimerModel(notifier: RestNotifier.shared)
    private let restClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false

    private let services: ServiceContainer
    private let draftStore: WorkoutDraftStore
    private let onFinished: (() -> Void)?

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

    // MARK: - Init

    init(
        workout: Workout,
        programId: String,
        dayNumber: Int,
        services: ServiceContainer,
        resuming: ActiveWorkoutSession? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        self.services = services
        self.draftStore = WorkoutDraftStore()
        self.onFinished = onFinished
        _session = StateObject(
            wrappedValue: resuming
                ?? ActiveWorkoutSession(workout: workout, programId: programId, dayNumber: dayNumber)
        )
    }

    init(
        draft: TrainingSessionDraft,
        services: ServiceContainer,
        onFinished: (() -> Void)? = nil
    ) {
        self.services = services
        self.draftStore = WorkoutDraftStore()
        self.onFinished = onFinished
        _session = StateObject(wrappedValue: ActiveWorkoutSession(trainingDraft: draft))
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
                }
            )

            completionFooter
        }
        .overlay(alignment: .topLeading) {
            Button {
                showExitConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surfaceElevated))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.top, 8)
            .accessibilityLabel("Close workout")
        }
        .onReceive(restClock) { _ in restTimer.tick() }
        .task {
            await loadContext()
        }
        .task {
            await RestNotifier.shared.requestAuthIfNeeded()
        }
        .interactiveDismissDisabled(true)
        // Always-available escape hatch — the draft is autosaved on every
        // mutation, so leaving keeps the workout resumable. Without this the
        // user is trapped whenever saveLog fails.
        .confirmationDialog(
            "Leave this workout?",
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button("Save & finish") {
                showExitConfirm = false
                Task { await complete() }
            }
            Button("Leave (keeps progress)", role: .destructive) { dismiss() }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("Your logged sets are saved as a draft you can resume.")
        }
        // saveLog failed — never trap the user; let them retry or leave.
        .alert("Couldn't save workout", isPresented: $saveError) {
            Button("Retry") { Task { await complete() } }
            Button("Leave (keeps draft)", role: .cancel) { dismiss() }
        } message: {
            Text("Check your connection. Your progress is saved locally and will be here when you come back.")
        }
        // Complete confirmation dialog
        .confirmationDialog(
            "Finish with sets remaining?",
            isPresented: $showCompleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish workout", role: .destructive) {
                showCompleteConfirm = false
                Task { await complete() }
            }
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
        .fullScreenCover(item: $rewardSequence) { summary in
            WorkoutRewardSequenceView(summary: summary) {
                finishRewardSequence()
            }
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - Computed helpers

    private var totalLoggedWorkingSets: Int {
        session.exercises.filter { !$0.skipped }.reduce(0) {
            $0 + $1.sets.filter { !$0.isWarmup && $0.logged }.count
        }
    }

    private var completionFooter: some View {
        VStack(spacing: 10) {
            RestTimerPill(
                model: restTimer,
                onAddThirty: { restTimer.addThirty() },
                onDismiss: { restTimer.dismiss() }
            )

            Button(action: requestComplete) {
                HStack(spacing: 10) {
                    if saving {
                        ProgressView()
                            .tint(Color.unbound.bg)
                    }
                    Text(saving ? "SAVING SESSION" : "COMPLETE SESSION")
                        .font(Font.unbound.bodyLStrong)
                        .tracking(2)
                }
                .foregroundStyle(Color.unbound.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 18)
                    .fill(saving ? Color.unbound.textSecondary : Color.unbound.accent))
                .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(saving)
            .accessibilityIdentifier("workout.complete")
            .accessibilityLabel(saving ? "Saving session" : "Complete session")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color.unbound.bg.opacity(0), Color.unbound.bg.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 142)
            .allowsHitTesting(false),
            alignment: .bottom
        )
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
                    session.exercises[ei].sets[si].suggestedWeightKg = g.weightKg.map {
                        WeightPlatePolicy.snappedSuggestionKilograms(
                            $0,
                            unit: weightUnit,
                            microloadingEnabled: microloadingEnabled
                        )
                    }
                }
            }
        }
    }

    private func requestComplete() {
        if session.hasUnloggedWorkingSets {
            showCompleteConfirm = true
        } else {
            Task { await complete() }
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
            swapAlternatives = MovementCatalog.catalogAlternatives(to: session.exercises[ei].name)
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

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    // MARK: - Save + reward

    private func complete() async {
        guard !saving else { return }
        guard let uid = services.auth.currentUserId else {
            // No session — don't trap the user behind a disabled dismiss.
            dismiss()
            return
        }
        saving = true
        let performanceLog = session.assemblePerformanceLog(userId: uid)
        do {
            let completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let weeklyVowReceipt = services.trials.recordCompletedVowWork(
                performanceLog: performanceLog,
                completionResult: completionResult
            )
            let rankTrialResult = OverallRankTrialRunner.shared.recordCompletedAttempt(
                performanceLog: performanceLog,
                completionResult: completionResult
            )
            HapticManager.notification(.success)
            restTimer.stop()
            draftStore.clear()

            let summary = makeRewardSequenceSummary(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rankTrialResult: rankTrialResult,
                weeklyVowReceipt: weeklyVowReceipt
            )
            if totalLoggedWorkingSets > 0 || summary.progression?.hasContent == true || summary.weeklyVowCallout != nil {
                saving = false
                rewardSequence = summary
            } else {
                saving = false
                finishDismiss()
            }
        } catch {
            HapticManager.notification(.error)
            saving = false
            saveError = true   // surface it + offer Retry / Leave — never trap
        }
    }

    private func finishDismiss() {
        if let onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }

    private func finishRewardSequence() {
        guard !isFinishingRewardSequence else { return }
        isFinishingRewardSequence = true
        rewardSequence = nil
        finishDismiss()
    }

    private func makeRewardSequenceSummary(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult,
        rankTrialResult: OverallRankTrialRunResult?,
        weeklyVowReceipt: WeeklyVowCompletionReceipt?
    ) -> WorkoutRewardSequenceSummary {
        let loggedSets = session.exercises
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup && $0.logged }
        let workSets = loggedSets.count
        let rewardSummary: RewardSummary? = {
            guard let rankUp = rankTrialResult?.rankUp else { return nil }
            var summary = RewardSummary()
            summary.rankUp = rankUp
            summary.skillTitle = rankUp.skillTitle
            summary.progression = completionResult.progressionReceipt
            return summary
        }()

        return WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: rewardSummary,
            fallbackXP: workSets * 12,
            sourceName: weeklyVowReceipt == nil ? session.source.rawValue.capitalized : "Weekly Vow",
            weeklyVowCallout: weeklyVowReceipt?.callout
        )
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
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false

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
            let unit = WeightPlatePolicy.currentUnit
            let kilograms = session.exercises.indices.contains(ei)
                && session.exercises[ei].sets.indices.contains(si)
                ? (session.exercises[ei].sets[si].weightKg
                   ?? session.exercises[ei].sets[si].suggestedWeightKg)
                : nil
            initial = kilograms.map { WeightPlatePolicy.editingValue(fromKilograms: $0, unit: unit) } ?? 0
        } else {
            if session.exercises.indices.contains(ei),
               session.exercises[ei].sets.indices.contains(si) {
                let set = session.exercises[ei].sets[si]
                switch session.exercises[ei].metricKind {
                case .reps:
                    initial = Double(set.reps ?? set.suggestedReps ?? 0)
                case .holdSeconds:
                    initial = Double(set.holdSeconds ?? set.suggestedHoldSeconds ?? 0)
                case .durationSeconds:
                    initial = Double(set.durationSeconds ?? set.suggestedDurationSeconds ?? 0)
                case .distanceMeters:
                    initial = Double(set.distanceMeters ?? set.suggestedDistanceMeters ?? 0)
                case .calories:
                    initial = Double(set.calories ?? set.suggestedCalories ?? 0)
                }
            } else {
                initial = 0
            }
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
                        label: label,
                        value: $value,
                        step: isWeight ? weightStep : 1,
                        unit: unit,
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

    private var isHoldMetric: Bool {
        session.exercises.indices.contains(ei)
            && (session.exercises[ei].blockKind == .carry
                || session.exercises[ei].metricKind == .holdSeconds
                || session.exercises[ei].metricKind == .durationSeconds)
    }

    private var label: String {
        if isWeight { return isHoldMetric ? "Load" : "Weight" }
        guard session.exercises.indices.contains(ei) else { return "Value" }
        switch session.exercises[ei].metricKind {
        case .reps: return "Reps"
        case .holdSeconds: return "Hold"
        case .durationSeconds: return "Time"
        case .distanceMeters: return "Distance"
        case .calories: return "Calories"
        }
    }

    private var unit: String? {
        if isWeight { return weightUnit.shortLabel }
        guard session.exercises.indices.contains(ei) else { return nil }
        switch session.exercises[ei].metricKind {
        case .reps: return nil
        case .holdSeconds, .durationSeconds: return "sec"
        case .distanceMeters: return "m"
        case .calories: return "cal"
        }
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private var weightStep: Double {
        WeightPlatePolicy.loadIncrement(
            unit: weightUnit,
            microloadingEnabled: microloadingEnabled
        )
    }

    private func commit() {
        guard session.exercises.indices.contains(ei),
              session.exercises[ei].sets.indices.contains(si) else {
            dismiss()
            return
        }
        if isWeight {
            session.exercises[ei].sets[si].weightKg = value > 0
                ? WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: weightUnit)
                : nil
        } else {
            let intValue = Int(value)
            switch session.exercises[ei].metricKind {
            case .reps:
                session.exercises[ei].sets[si].reps = intValue > 0 ? intValue : nil
            case .holdSeconds:
                session.exercises[ei].sets[si].holdSeconds = intValue > 0 ? intValue : nil
            case .durationSeconds:
                session.exercises[ei].sets[si].durationSeconds = intValue > 0 ? intValue : nil
            case .distanceMeters:
                session.exercises[ei].sets[si].distanceMeters = intValue > 0 ? intValue : nil
            case .calories:
                session.exercises[ei].sets[si].calories = intValue > 0 ? intValue : nil
            }
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
