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
    @State private var showingAddExercise = false

    // Notes editing state
    @State var notesEditingIndex: Int? = nil
    @State var notesEditingText: String = ""
    @State var showNotesSheet = false

    // Reward state
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State private var isFinishingRewardSequence = false

    // A passed rank gate: The Crossing overrides the standard reward sequence as the
    // rank-up moment, then chains into it so XP/badges still play.
    @State private var pendingGateCrossing: GateCrossing? = nil
    @State private var pendingGateDefiningNumber: String? = nil
    @State private var stashedGateRewardSummary: WorkoutRewardSequenceSummary? = nil

    /// Station-clear beat (spec §6.5): the world floods full-bleed when a rank-trial
    /// station's first working set is logged, then recedes (`GateBeatOverlay`).
    @State private var beatStationTitle: String? = nil

    /// Fail verdict (spec §6.7): "THE GATE HOLDS" → ENTER AGAIN on a failed gate.
    @State private var pendingGateVerdict: GateVerdictContext? = nil

    private struct GateVerdictContext: Identifiable {
        let id = UUID()
        let evaluation: OverallRankTrialEvaluation
        let world: GateWorld
    }

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

                if isCustomSession && visibleExerciseCount == 0 {
                    emptyQuickLogState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WorkoutLogGridView(
                        session: session,
                        rankTrialDefinition: rankTrialDefinition,
                        onIntent: { ei, intent in handleIntent(ei, intent) },
                        onEditWeight: { ei, si in beginEdit(ei: ei, si: si, field: .weight) },
                        onEditReps:   { ei, si in beginEdit(ei: ei, si: si, field: .metric) },
                        onPickRPE: { ei, si in beginEdit(ei: ei, si: si, field: .rpe) },
                        onConfirmAsPlanned: { ei, si in
                            session.confirmAsPlanned(exerciseIndex: ei, setIndex: si)
                            saveDraft()
                            // Rank trials auto-finish into the verdict / Crossing once every
                            // station is logged — no manual "Complete Trial" tap.
                            if isRankTrial && !session.hasUnloggedWorkingSets {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Hide the bottom footer while the keypad owns that space (matches the
            // pre-module behaviour where the dock floated over the footer).
            if !keypad.isActive {
                if isRankTrial {
                    trialRestFooter
                } else if isCustomSession && visibleExerciseCount == 0 {
                    // Empty Quick Log: the body shows the Add Exercise CTA, so the
                    // finish footer is hidden — there's nothing to finish yet.
                    EmptyView()
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
        .onChange(of: rankTrialClearedStations) { previous, current in
            // A station just cleared — flood its world beat. Deck has its own flow.
            guard isRankTrial, !isDeckTrial, current > previous else { return }
            beatStationTitle = session.exercises.last { !$0.skipped && $0.hasLoggedRankTrialWorkingSet }?.name
        }
        .overlay {
            if let beatStationTitle, let gateWorld {
                GateBeatOverlay(world: gateWorld, stationTitle: beatStationTitle) {
                    self.beatStationTitle = nil
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
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
        // Live "Add Exercise" picker for free/Quick-Log sessions — reuses the
        // same catalog picker the session editor uses.
        .sheet(isPresented: $showingAddExercise) {
            ExerciseSwapSheet(
                mode: .add,
                currentExerciseName: "Quick Log",
                alternatives: addExerciseCatalog,
                onSelect: { exercise in
                    session.appendCatalogExercise(exercise)
                    showingAddExercise = false
                    saveDraft()
                },
                onCreateCustom: {
                    showingAddExercise = false
                    showingCustomBuilder = true
                }
            )
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
            WorkoutRewardSequenceView(
                summary: summary,
                onAddWorkoutPhoto: { image in
                    Task { await saveWorkoutPhoto(image, context: summary.workoutPhotoContext, services: services) }
                }
            ) {
                finishRewardSequence()
            }
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $pendingGateCrossing) { crossing in
            TheCrossingView(
                crossing: crossing,
                definingNumber: pendingGateDefiningNumber,
                onShare: {},
                onReplay: {},
                onDismiss: {
                    pendingGateCrossing = nil
                    if let stashed = stashedGateRewardSummary {
                        stashedGateRewardSummary = nil
                        rewardSequence = stashed   // chain into XP / badges
                    } else {
                        finishDismiss()
                    }
                }
            )
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $pendingGateVerdict) { context in
            GateVerdictView(
                evaluation: context.evaluation,
                world: context.world,
                onRematch: {
                    pendingGateVerdict = nil
                    finishDismiss()
                }
            )
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

    private var trialRestFooter: some View {
        RestTimerPill(
            model: restTimer,
            onAddThirty: { restTimer.addThirty() },
            onDismiss: { restTimer.dismiss() }
        )
        .padding(.bottom, 16)
        .allowsHitTesting(restTimer.isVisible)
    }

    /// Free / Quick-Log session — the only mode that supports adding exercises
    /// live. Program days and rank trials have a fixed prescription.
    var isCustomSession: Bool {
        session.source == .custom && !isRankTrial
    }

    var visibleExerciseCount: Int {
        session.exercises.filter { !$0.skipped }.count
    }

    /// Same catalog the session editor's ADD EXERCISE picker draws from.
    private var addExerciseCatalog: [CatalogExercise] {
        MovementCatalog.legacyExercises.compactMap(MovementCatalog.catalogExercise(for:))
    }

    private var emptyQuickLogState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            VStack(spacing: 6) {
                Text("No exercises yet")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Add what you just trained.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                UnboundHaptics.soft()
                showingAddExercise = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("ADD EXERCISE")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.4)
                }
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.addExercise.empty")
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
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

            if isCustomSession {
                Button {
                    UnboundHaptics.soft()
                    showingAddExercise = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("ADD EXERCISE")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.4)
                    }
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
                .accessibilityIdentifier("workout.addExercise")
            }

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
        // Flatten exerciseEntries from the most-recent logs so SetPrefill can
        // find last-session values per exercise (most-recent last = .last(where:) picks latest).
        let recentLogs: [WorkoutLog] = (try? await services.workoutLog.fetchRecentLogs(userId: uid, limit: 40)) ?? []
        priorEntries = recentLogs
            .sorted { $0.startedAt < $1.startedAt } // oldest first → SetPrefill.last picks newest
            .flatMap { $0.exerciseEntries }

        // Last-performance: most-recent prior WorkoutLogs → per-set reference + prefill source.
        let lookup = LastPerformanceLookup(logs: recentLogs, excludingLogId: nil)  // live session has no persisted WorkoutLog yet
        for ei in session.exercises.indices {
            let mid = session.exercises[ei].movementId
            let name = session.exercises[ei].name
            var workingIndex = 0
            for si in session.exercises[ei].sets.indices {
                guard !session.exercises[ei].sets[si].isWarmup else { continue }
                session.exercises[ei].sets[si].lastPerformance =
                    lookup.lastWorkingSet(movementId: mid, exerciseName: name, workingIndex: workingIndex)
                workingIndex += 1
            }
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
            let completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
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

            var summary = makeRewardSequenceSummary(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rankTrialResult: rankTrialResult
            )
            // Tag the final beat so it can offer an opt-in post-workout photo
            // linked to this session. Travels with the summary into the gate tail too.
            summary.workoutPhotoContext = WorkoutPhotoSummary(performanceLog: performanceLog)
            let hasReward = totalLoggedWorkingSets > 0
                || summary.progression?.hasContent == true
                || summary.weeklyVowCallout != nil
                || summary.rankTrialCallout != nil
            saving = false
            if let rt = rankTrialResult, rt.didAdvanceRank {
                // The Crossing IS the gate's reward moment and rank-up announcement;
                // chain the remaining spoils afterward, minus the redundant verdict beat.
                pendingGateDefiningNumber = gateDefiningNumber(rt.evaluation)
                stashedGateRewardSummary = gateRewardTail(from: summary)
                pendingGateCrossing = GateCrossingCatalog.crossing(for: rt.definition.format)
            } else if let rt = rankTrialResult, !rt.evaluation.passed {
                // Failed gate — "THE GATE HOLDS" verdict + ENTER AGAIN. XP is banked.
                pendingGateVerdict = GateVerdictContext(
                    evaluation: rt.evaluation,
                    world: GateWorldCatalog.world(for: rt.definition.format))
            } else if hasReward {
                rewardSequence = summary
            } else {
                finishDismiss()
            }
        } catch {
            HapticManager.notification(.error)
            saving = false
            saveError = true   // surface it + offer Retry / Leave — never trap
        }
    }

    private var gateWorld: GateWorld? {
        rankTrialDefinition.map { GateWorldCatalog.world(for: $0.format) }
    }

    /// How many rank-trial stations have a logged working set — drives the beat.
    private var rankTrialClearedStations: Int {
        session.rankTrialLoggedStationCount { $0.hasLoggedRankTrialWorkingSet }
    }

    /// "passed / scored" stations, e.g. "4/4", for the minted gate card.
    private func gateDefiningNumber(_ evaluation: OverallRankTrialEvaluation) -> String {
        let scored = evaluation.stationResults.filter(\.isScored)
        let passed = scored.filter { $0.status == .passed }.count
        return "\(passed)/\(scored.count)"
    }

    /// The Crossing IS the rank-up announcement, so the chained reward tail drops
    /// the redundant rank-trial receipt beat and keeps only the rest of the spoils.
    private func gateRewardTail(from summary: WorkoutRewardSequenceSummary) -> WorkoutRewardSequenceSummary? {
        var tail = summary
        tail.rankTrialCallout = nil
        let hasTailReward = totalLoggedWorkingSets > 0
            || tail.progression?.hasContent == true
            || tail.weeklyVowCallout != nil
            || !tail.badges.isEmpty
            || tail.xp.total > 0
        return hasTailReward ? tail : nil
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
