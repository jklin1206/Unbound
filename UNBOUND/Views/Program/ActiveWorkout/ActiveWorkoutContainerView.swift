import SwiftUI

// MARK: - ActiveWorkoutContainerView
//
// Session orchestrator for the new grid-based logging surface.
// Owns the ActiveWorkoutSession, autosaves drafts, hosts WorkoutLogGridView
// + timer chrome, and on COMPLETE assembles + saves unified
// PerformanceLog data before showing the post-workout reward sequence.

struct ActiveWorkoutContainerView: View {
    @StateObject var session: ActiveWorkoutSession
    @State private var priorEntries: [ExerciseLogEntry] = []
    @State private var workingWeightKg: Double? = nil
    @State private var saving = false
    @State private var showCompleteConfirm = false
    @State private var saveError = false
    @State var showExitConfirm = false
    @State private var draftAutosaveFailed = false

    // Swap sheet state
    @State var swapExerciseIndex: Int? = nil
    @State var swapAlternatives: [CatalogExercise] = []
    @State private var showingCustomBuilder = false

    // Notes editing state
    @State var notesEditingIndex: Int? = nil
    @State var notesEditingText: String = ""
    @State var showNotesSheet = false

    // Reward state
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State private var isFinishingRewardSequence = false

    // Grid cell editor — shared bottom-docked keypad module (no modal). The model
    // owns the typed buffer + pristine state, so merely opening a cell never
    // commits the suggested value (the ✓ ring does that).
    @StateObject var keypad = NumberPadEditorModel<ActiveCell>()

    // Rest timer
    @ObservedObject private var restTimer = RestTimerModel.shared
    @State var workoutElapsedSeconds = 0
    private let restClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false

    private let services: ServiceContainer
    private let draftStore: WorkoutDraftStore
    private let onFinished: (() -> Void)?

    // MARK: - Private types

    /// One editable cell in the logging grid: a weight cell, a metric cell, or the
    /// RPE quick-pick. Drives the shared NumberPadEditorModel.
    struct ActiveCell: Equatable, Identifiable {
        enum Field: Equatable { case weight, metric, rpe }
        let ei: Int
        let si: Int
        let field: Field
        var id: String { "\(ei)-\(si)-\(field)" }
        var isWeight: Bool { field == .weight }
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

            VStack(spacing: 0) {
                workoutTopBar

                if draftAutosaveFailed {
                    draftAutosaveWarning
                }

                WorkoutLogGridView(
                    session: session,
                    rankTrialDefinition: rankTrialDefinition,
                    onIntent: { ei, intent in handleIntent(ei, intent) },
                    onEditWeight: { ei, si in beginEdit(ei: ei, si: si, field: .weight) },
                    onEditReps:   { ei, si in beginEdit(ei: ei, si: si, field: .metric) },
                    onPickRPE: { ei, si in beginEdit(ei: ei, si: si, field: .rpe) },
                    onConfirmAsPlanned: { ei, si in
                        let shouldUseDeckFlow = isDeckTrial
                        session.confirmAsPlanned(exerciseIndex: ei, setIndex: si)
                        saveDraft()
                        if shouldUseDeckFlow && !session.hasUnloggedWorkingSets {
                            restTimer.stop()
                            Task { await complete() }
                        } else {
                            transition(ei: ei, si: si)
                        }
                    },
                    onToggleQualityFlag: { ei, si, flag in
                        session.toggleQualityFlag(flag, exerciseIndex: ei, setIndex: si)
                        saveDraft()
                    },
                    onAddSet: { ei in
                        session.addSet(toExerciseIndex: ei)
                        saveDraft()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Hide the bottom footer while the keypad owns that space (matches the
            // pre-module behaviour where the dock floated over the footer).
            if !keypad.isActive {
                if isDeckTrial {
                    deckRestFooter
                } else {
                    completionFooter
                }
            }
        }
        .numberPadDock(model: keypad)
        .onReceive(restClock) { now in
            restTimer.tick(now: now)
            workoutElapsedSeconds = Self.elapsedSeconds(since: session.startedAt, now: now)
        }
        .task {
            workoutElapsedSeconds = Self.elapsedSeconds(since: session.startedAt)
            await loadContext()
        }
        .task {
            await RestNotifier.shared.requestAuthIfNeeded()
        }
        .task {
            // Broadcast squad presence while this workout is open so squadmates
            // see "live now". The server row auto-expires after 3h; complete()
            // clears it on finish.
            guard let uid = services.auth.currentUserId,
                  let squadId = services.squads.state(userId: uid).currentSquad?.id else { return }
            await services.squadPresence.markInWorkout(userId: uid, squadId: squadId)
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
        // Grid cell editing + RPE now use the shared bottom-docked keypad module
        // (.numberPadDock(model: keypad)), not modal sheets.
        // Swap sheet — uses the existing ExerciseSwapSheet with real init
        .sheet(item: Binding(
            get: { swapExerciseIndex.map(SwapContext.init(index:)) },
            set: { swapExerciseIndex = $0?.index }
        )) { ctx in
            ExerciseSwapSheet(
                currentExerciseName: session.exercises[ctx.index].name,
                alternatives: swapAlternatives,
                onSelect: { alt in
                    session.replaceExercise(at: ctx.index, with: alt)
                    swapExerciseIndex = nil
                    saveDraft()
                },
                onCreateCustom: {
                    swapExerciseIndex = nil
                    showingCustomBuilder = true
                }
            )
        }
        // Custom exercise builder
        .sheet(isPresented: $showingCustomBuilder) {
            CustomExerciseBuilderView { exercise in
                session.appendCustomExercise(exercise)
                saveDraft()
            }
                .environmentObject(services)
        }
        // Notes editing sheet — simple inline text entry
        .sheet(isPresented: $showNotesSheet) {
            NotesEditSheet(
                text: $notesEditingText,
                onSave: {
                    if let idx = notesEditingIndex {
                        session.setNotes(notesEditingText, forExerciseAt: idx)
                        saveDraft()
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

    // MARK: - Draft autosave

    /// Single funnel for draft autosave. A failure here means kill/crash
    /// recovery is broken, so it's logged once and surfaced as a calm warning
    /// row instead of failing silently.
    func saveDraft() {
        do {
            try draftStore.save(session)
            draftAutosaveFailed = false
        } catch {
            if !draftAutosaveFailed {
                LoggingService.shared.log(
                    "Workout draft autosave failed: \(error)",
                    level: .error
                )
            }
            draftAutosaveFailed = true
        }
    }

    private var deckRestFooter: some View {
        RestTimerPill(
            model: restTimer,
            onAddThirty: { restTimer.addThirty() },
            onDismiss: { restTimer.dismiss() }
        )
        .padding(.bottom, 16)
        .allowsHitTesting(restTimer.isVisible)
    }

    private var completionFooter: some View {
        let progress = session.progressSummary
        return VStack(spacing: 10) {
            RestTimerPill(
                model: restTimer,
                onAddThirty: { restTimer.addThirty() },
                onDismiss: { restTimer.dismiss() }
            )

            HStack(spacing: 8) {
                Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(progress.isComplete ? Color.unbound.accent : Color.unbound.textTertiary)
                Text(progress.footerText.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer()
            }
            .padding(.horizontal, 4)

            #if DEBUG
            Button(action: debugFillPlannedSets) {
                Label("Fill Planned Sets", systemImage: "wand.and.stars")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.debug.fillPlannedSets")
            #endif

            Button(action: requestComplete) {
                HStack(spacing: 10) {
                    if saving {
                        ProgressView()
                            .tint(Color.unbound.bg)
                    }
                    Text(saving ? "SAVING SESSION" : completionButtonTitle(progress: progress))
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
            .accessibilityLabel(saving ? "Saving session" : (isRankTrial ? "Complete trial" : "Complete session"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(Color.unbound.bg.opacity(0.96))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.unbound.bg.opacity(0), Color.unbound.bg.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 42)
            .offset(y: -42)
            .allowsHitTesting(false)
        }
    }

    private func completionButtonTitle(progress: ActiveWorkoutSession.ProgressSummary) -> String {
        if isRankTrial {
            return progress.isComplete ? "FINISH TRIAL" : "COMPLETE TRIAL"
        }
        return progress.isComplete ? "FINISH SESSION" : "COMPLETE SESSION"
    }

    // MARK: - Rest timer

    private func startRest(ei: Int, si: Int) {
        guard session.exercises.indices.contains(ei) else { return }
        let setRest = session.exercises[ei].sets.indices.contains(si)
            ? session.exercises[ei].sets[si].suggestedRestSeconds
            : nil
        let secs = setRest ?? session.exercises[ei].restSeconds
        let next = session.exercises[ei].name
        restTimer.onElapsed = { UnboundHaptics.success() }
        restTimer.start(seconds: secs, nextLabel: next)
    }

    /// Fired exactly once per set on the SUGGESTED→LOGGED edge.
    private func transition(ei: Int, si: Int) {
        UnboundHaptics.success()
        startRest(ei: ei, si: si)
    }

    /// After loadContext resolves history/working-weight, fill each set's
    /// dim suggested weight via the existing SetPrefill ghost.
    private func applySuggestedWeights() {
        for ei in session.exercises.indices {
            for si in session.exercises[ei].sets.indices
            where session.exercises[ei].sets[si].suggestedWeightKg == nil {
                let fallbackWeight = ei == session.currentExerciseIndex ? workingWeightKg : nil
                if let g = SetPrefill.ghost(
                    exerciseName: session.exercises[ei].name,
                    setIndex: si,
                    priorEntries: priorEntries,
                    workingWeightKg: fallbackWeight) {
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
        // Use the normalized name (lowercased, spaces→"_") for the working-weight key.
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
        #if DEBUG
        let performanceLog = session.assemblePerformanceLog(userId: uid, completedAt: DevProgramClock.now)
        #else
        let performanceLog = session.assemblePerformanceLog(userId: uid)
        #endif
        do {
            var completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let weeklyVowReceipt = services.trials.recordCompletedVowWork(
                performanceLog: performanceLog,
                completionResult: completionResult
            )
            if let weeklyVowReceipt {
                completionResult = await applyWeeklyVowBonus(
                    weeklyVowReceipt,
                    to: completionResult
                )
            }
            let rankTrialResult = OverallRankTrialRunner.shared.recordCompletedAttempt(
                performanceLog: performanceLog,
                completionResult: completionResult,
                bodyweightKg: (try? await services.user.fetchProfile(userId: uid))?.weightKg
            )
            HapticManager.notification(.success)
            restTimer.stop()
            draftStore.clear()
            // Finished training — drop squad presence so squadmates stop seeing
            // us as live (best-effort; the row also auto-expires after 3h).
            Task { await services.squadPresence.clearPresence(userId: uid) }

            let summary = makeRewardSequenceSummary(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rankTrialResult: rankTrialResult,
                weeklyVowReceipt: weeklyVowReceipt
            )
            if totalLoggedWorkingSets > 0
                || summary.progression?.hasContent == true
                || summary.weeklyVowCallout != nil
                || summary.rankTrialCallout != nil {
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

    private func applyWeeklyVowBonus(
        _ receipt: WeeklyVowCompletionReceipt,
        to completionResult: TrainingCompletionResult
    ) async -> TrainingCompletionResult {
        var updated = completionResult
        do {
            let reward = try await OverallLevelService.shared.grantFlatXPStrict(
                amount: receipt.completionBonus.overallLevelXP,
                sourceId: "weekly-vow-bonus:\(receipt.performanceLogId)",
                userId: receipt.vow.userId,
                at: receipt.completedAt,
                database: services.database
            )
            updated.appendOverallLevelReward(reward)
        } catch {
            LoggingService.shared.log(
                "Weekly Vow bonus XP persistence failed: \(error)",
                level: .warning,
                context: [
                    "vowId": receipt.vow.id,
                    "performanceLogId": receipt.performanceLogId
                ]
            )
        }
        return updated
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
}

extension ActiveWorkoutContainerView {
    var editWeightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }
}
