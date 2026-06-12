import SwiftUI

// MARK: - ActiveWorkoutContainerView
//
// Session orchestrator for the new grid-based logging surface.
// Owns the ActiveWorkoutSession, autosaves drafts, hosts WorkoutLogGridView
// + timer chrome, and on COMPLETE assembles + saves unified
// PerformanceLog data before showing the post-workout reward sequence.

struct ActiveWorkoutContainerView: View {
    @StateObject var session: ActiveWorkoutSession
    @State var priorEntries: [ExerciseLogEntry] = []
    @State var workingWeightKg: Double? = nil
    @State var saving = false
    @State var showCompleteConfirm = false
    @State var saveError = false
    @State var showExitConfirm = false
    @State var draftAutosaveFailed = false

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

    // Grid cell editor — shared bottom-docked keypad module (no modal). The model
    // owns the typed buffer + pristine state, so merely opening a cell never
    // commits the suggested value (the ✓ ring does that).
    @StateObject var keypad = NumberPadEditorModel<ActiveCell>()

    // Rest timer
    @ObservedObject var restTimer = RestTimerModel.shared
    @State var workoutElapsedSeconds = 0
    private let restClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) var microloadingEnabled = false

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

    private var draftAutosaveWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Autosave isn't working — finish your session to keep this workout.")
                .font(Font.unbound.captionS)
                .lineLimit(2)
        }
        .foregroundStyle(Color.unbound.alert)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .accessibilityIdentifier("workout.draftAutosaveWarning")
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

    func requestComplete() {
        if session.hasUnloggedWorkingSets {
            showCompleteConfirm = true
        } else {
            Task { await complete() }
        }
    }

    #if DEBUG
    func debugFillPlannedSets() {
        session.objectWillChange.send()
        for exerciseIndex in session.exercises.indices where !session.exercises[exerciseIndex].skipped {
            for setIndex in session.exercises[exerciseIndex].sets.indices {
                guard !session.exercises[exerciseIndex].sets[setIndex].isWarmup else { continue }
                var set = session.exercises[exerciseIndex].sets[setIndex]
                switch session.exercises[exerciseIndex].metricKind {
                case .reps:
                    set.reps = set.suggestedReps ?? RepRange.lowerBound(session.exercises[exerciseIndex].plannedReps) ?? 8
                    set.weightKg = set.suggestedWeightKg ?? debugWeightKg(exerciseIndex: exerciseIndex, setIndex: setIndex)
                case .holdSeconds:
                    set.holdSeconds = set.suggestedHoldSeconds ?? 30
                case .durationSeconds:
                    set.durationSeconds = set.suggestedDurationSeconds ?? 600
                case .distanceMeters:
                    set.distanceMeters = set.suggestedDistanceMeters ?? 400
                case .calories:
                    set.calories = set.suggestedCalories ?? 20
                }
                set.rpe = set.suggestedRPE ?? session.exercises[exerciseIndex].targetRPE ?? 8
                set.logged = true
                session.exercises[exerciseIndex].sets[setIndex] = set
            }
        }
        saveDraft()
        UnboundHaptics.success()
    }

    private func debugWeightKg(exerciseIndex: Int, setIndex: Int) -> Double {
        let base = 45 + (exerciseIndex * 15) + (setIndex * 2)
        return Double(base)
    }
    #endif

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
        if isRankTrial {
            switch intent {
            case .toggleWarmup, .editNotes:
                break
            case .addSet, .removeSet, .skipExercise, .swapExercise:
                return
            }
        }

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
        saveDraft()
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

        var summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: rewardSummary,
            fallbackXP: workSets * 12,
            sourceName: weeklyVowReceipt == nil ? session.source.rawValue.capitalized : "Binding Vow",
            weeklyVowCallout: weeklyVowReceipt?.callout
        )
        summary.rankTrialCallout = rankTrialResult.map(rankTrialCallout)
        return summary
    }

    private func rankTrialCallout(_ result: OverallRankTrialRunResult) -> RankTrialRewardCallout {
        let failed = result.evaluation.failedStation
        let clearedCount = result.evaluation.stationResults.filter { $0.status == .passed }.count
        let totalCount = result.evaluation.stationResults.count
        let detail = failed.map { station in
            station.failureReason.map { "\(station.title): \($0)" } ?? station.title
        } ?? "\(clearedCount)/\(totalCount) stations cleared"

        return RankTrialRewardCallout(
            id: result.attempt.id,
            title: result.definition.displayName,
            subtitle: result.attempt.passed ? "\(result.definition.targetRank.displayName) gate cleared" : "\(result.definition.targetRank.displayName) gate held",
            statusLine: result.attempt.passed ? "Official result saved" : "First failed station saved",
            detailLine: detail,
            receiptLine: "\(clearedCount)/\(totalCount) stations cleared",
            passed: result.attempt.passed
        )
    }
}
